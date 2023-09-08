// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U88, U80} from "contracts/libraries/PRBMathHelper.sol";
import {Constants} from "contracts/libraries/Constants.sol";
import {ForkHelper} from "test/fork/ForkHelper.sol";
import {Vault} from "contracts/libraries/Constants.sol";
import {MTypes, STypes, SR} from "contracts/libraries/DataTypes.sol";
import {Errors} from "contracts/libraries/Errors.sol";

// import {console} from "contracts/libraries/console.sol";

contract EndToEndForkTest is ForkHelper {
    using U256 for uint256;
    using U88 for uint88;
    using U80 for uint80;

    //current price at block 15_333_111 above using chainlink
    uint256 public currentEthPriceUSD = 1992.70190598 ether;
    uint16[] public shortHints = new uint16[](1);
    uint256 public receiverPostCollateral;
    uint256 public receiverEthEscrowed;
    uint80 public currentPrice;

    function setUp() public virtual override {
        super.setUp();

        assertApproxEqAbs(
            diamond.getOraclePriceT(_cusd), currentEthPriceUSD.inv(), MAX_DELTA_SMALL
        );
        deal(sender, 1000 ether);
        deal(receiver, 1000 ether);
    }

    function testFork_EndToEnd() public {
        uint16 cusdInitialMargin = diamond.getAssetStruct(_cusd).initialMargin;
        //sender
        //Workflow: Bridge - DepositEth
        vm.startPrank(sender);
        assertEq(reth.balanceOf(_bridgeReth), 0);
        diamond.depositEth{value: 500 ether}(_bridgeReth);
        assertEq(reth.balanceOf(_bridgeReth), reth.getRethValue(500 ether));
        assertEq(sender.balance, 1000 ether - 500 ether);
        uint256 senderEthEscrowed =
            diamond.getVaultUserStruct(Vault.CARBON, sender).ethEscrowed;
        assertApproxEqAbs(senderEthEscrowed, 500 ether, MAX_DELTA_SMALL);
        assertApproxEqAbs(
            diamond.getVaultStruct(Vault.CARBON).zethTotal, 500 ether, MAX_DELTA_SMALL
        );
        vm.stopPrank();

        //receiver
        vm.startPrank(receiver);
        assertEq(steth.balanceOf(_bridgeSteth), 0);
        diamond.depositEth{value: 500 ether}(_bridgeSteth);
        assertApproxEqAbs(steth.balanceOf(_bridgeSteth), 500 ether, MAX_DELTA_SMALL);
        assertEq(receiver.balance, 1000 ether - 500 ether);
        receiverEthEscrowed =
            diamond.getVaultUserStruct(Vault.CARBON, receiver).ethEscrowed;
        assertApproxEqAbs(receiverEthEscrowed, 500 ether, MAX_DELTA_SMALL);
        assertApproxEqAbs(
            diamond.getVaultStruct(Vault.CARBON).zethTotal, 1000 ether, MAX_DELTA_SMALL
        );

        //Workflow: MARKET - LimitShort
        MTypes.OrderHint[] memory orderHints = new MTypes.OrderHint[](1);
        currentPrice = diamond.getOraclePriceT(_cusd);
        assertApproxEqAbs(
            currentPrice.mul(100_000 ether),
            (uint256(100_000 ether)).div(currentEthPriceUSD),
            0.00000001 ether
        );

        diamond.createLimitShort(
            _cusd, currentPrice, 100_000 ether, orderHints, shortHints, cusdInitialMargin
        );
        receiverPostCollateral = diamond.getAssetNormalizedStruct(asset).initialMargin.mul(
            currentPrice.mul(100_000 ether)
        );
        receiverEthEscrowed -= receiverPostCollateral;
        assertApproxEqAbs(
            diamond.getVaultUserStruct(Vault.CARBON, receiver).ethEscrowed,
            receiverEthEscrowed,
            MAX_DELTA_SMALL
        );
        vm.stopPrank();

        //Workflow: MARKET - LimitBid
        //sender
        vm.startPrank(sender);
        shortHints[0] = diamond.getShortIdAtOracle(_cusd);
        diamond.createBid(
            _cusd, currentPrice, 50_000 ether, false, orderHints, shortHints
        );
        senderEthEscrowed -= currentPrice.mul(50_000 ether);
        assertApproxEqAbs(
            diamond.getVaultUserStruct(Vault.CARBON, sender).ethEscrowed,
            senderEthEscrowed,
            MAX_DELTA_SMALL
        );
        assertApproxEqAbs(
            diamond.getAssetUserStruct(_cusd, sender).ercEscrowed,
            50_000 ether,
            MAX_DELTA_SMALL
        );
        diamond.createBid(
            _cusd, currentPrice, 50_000 ether, false, orderHints, shortHints
        );
        senderEthEscrowed -= currentPrice.mul(50_000 ether);
        assertApproxEqAbs(
            diamond.getVaultUserStruct(Vault.CARBON, sender).ethEscrowed,
            senderEthEscrowed,
            MAX_DELTA_SMALL
        );
        assertApproxEqAbs(
            diamond.getAssetUserStruct(_cusd, sender).ercEscrowed,
            100_000 ether,
            MAX_DELTA_SMALL
        );
        assertEq(diamond.getShorts(_cusd).length, 0);

        STypes.ShortRecord memory receiverShort =
            diamond.getShortRecords(_cusd, receiver)[0];
        assertEq(receiverShort.ercDebt, 100_000 ether);
        assertEq(
            receiverShort.collateral,
            receiverPostCollateral + currentPrice.mul(100_000 ether)
        );
        assertSR(SR.FullyFilled, receiverShort.status);

        //Workflow: Vault - Withdraw Zeth
        assertEq(zeth.balanceOf(sender), 0);
        diamond.withdrawZETH(_zeth, 100 ether);
        senderEthEscrowed -= 100 ether;
        assertApproxEqAbs(
            diamond.getVaultUserStruct(Vault.CARBON, sender).ethEscrowed,
            senderEthEscrowed,
            MAX_DELTA_SMALL
        );
        assertEq(zeth.balanceOf(sender), 100 ether);

        //Workflow: Vault - Withdraw CUSD
        assertEq(cusd.balanceOf(sender), 0);
        diamond.withdrawAsset(_cusd, 100000 ether);
        assertEq(diamond.getAssetUserStruct(_cusd, sender).ercEscrowed, 0);
        assertEq(cusd.balanceOf(sender), 100_000 ether);

        assertEq(diamond.getAssetStruct(_cusd).ercDebt, 100_000 ether);
        assertApproxEqAbs(
            diamond.getVaultStruct(Vault.CARBON).zethTotal, 1000 ether, MAX_DELTA_SMALL
        );
        vm.stopPrank();

        //receiver
        //Workflow: ShortRecord - Decrease Collateral
        vm.prank(receiver);
        diamond.decreaseCollateral(_cusd, 2, 40 ether);
        receiverEthEscrowed += 40 ether;
        receiverShort.collateral -= 40 ether;
        assertApproxEqAbs(
            diamond.getVaultUserStruct(Vault.CARBON, receiver).ethEscrowed,
            receiverEthEscrowed,
            MAX_DELTA_SMALL
        );
        assertEq(
            receiverShort.collateral,
            diamond.getShortRecords(_cusd, receiver)[0].collateral
        );
        vm.prank(sender);
        vm.expectRevert(Errors.SufficientCollateral.selector);
        diamond.liquidate(_cusd, receiver, 2, shortHints);

        //Move fork to liquidation block
        vm.selectFork(liquidationFork);
        diamond.setOracleTimeAndPrice(
            _cusd, uint256(ethAggregator.latestAnswer() * ORACLE_DECIMALS).inv()
        );
        assertLt(
            diamond.getCollateralRatio(_cusd, diamond.getShortRecord(_cusd, receiver, 2)),
            diamond.getAssetNormalizedStruct(asset).initialMargin
        );

        //Workflow: Yield
        //receiver
        vm.startPrank(receiver);
        STypes.Vault memory oldVault = diamond.getVaultStruct(Vault.CARBON);
        assertEq(diamond.getVaultUserStruct(Vault.CARBON, receiver).dittoReward, 0);

        diamond.updateYield(Vault.CARBON);
        address[] memory assetArr = new address[](1);
        assetArr[0] = _cusd;
        diamond.distributeYield(assetArr);

        STypes.Vault memory newVault = diamond.getVaultStruct(Vault.CARBON);
        assertLt(oldVault.zethYieldRate, newVault.zethYieldRate);
        assertLt(oldVault.zethTotal, newVault.zethTotal);
        assertLt(oldVault.zethCollateralReward, newVault.zethCollateralReward);
        assertGt(
            diamond.getVaultUserStruct(Vault.CARBON, receiver).ethEscrowed,
            receiverEthEscrowed
        );
        receiverEthEscrowed =
            diamond.getVaultUserStruct(Vault.CARBON, receiver).ethEscrowed;

        assertGt(diamond.getVaultUserStruct(Vault.CARBON, receiver).dittoReward, 1);
        assertEq(ditto.balanceOf(receiver), 0);
        diamond.withdrawDittoReward(Vault.CARBON);
        assertEq(diamond.getVaultUserStruct(Vault.CARBON, receiver).dittoReward, 1);
        assertGt(ditto.balanceOf(receiver), 0);

        uint256 tappEscrow =
            diamond.getVaultUserStruct(Vault.CARBON, _diamond).ethEscrowed;
        assertGt(tappEscrow, 0);

        //Workflow: ShortRecord - Increase Collateral
        diamond.increaseCollateral(_cusd, 2, 5 ether);
        receiverEthEscrowed -= 5 ether;
        receiverShort.collateral += 5 ether;
        assertApproxEqAbs(
            diamond.getVaultUserStruct(Vault.CARBON, receiver).ethEscrowed,
            receiverEthEscrowed,
            MAX_DELTA_SMALL
        );
        assertEq(
            receiverShort.collateral,
            diamond.getShortRecords(_cusd, receiver)[0].collateral
        );
        vm.stopPrank();

        //sender
        //Workflow: Vault - Deposit CUSD
        vm.startPrank(sender);

        assertEq(cusd.balanceOf(sender), 100_000 ether);
        diamond.depositAsset(_cusd, 100_000 ether);
        assertEq(diamond.getAssetUserStruct(_cusd, sender).ercEscrowed, 100_000 ether);
        assertEq(cusd.balanceOf(sender), 0);
        assertEq(diamond.getAssetStruct(_cusd).ercDebt, 100_000 ether);
        assertGt(diamond.getVaultStruct(Vault.CARBON).zethTotal, 1000 ether);

        //Workflow: Market - Limit Ask
        diamond.createAsk(
            _cusd, uint80(diamond.getAssetPrice(_cusd)), 10_000 ether, false, orderHints
        );
        assertEq(diamond.getAssetUserStruct(_cusd, sender).ercEscrowed, 90_000 ether);
        assertEq(diamond.getAsks(_cusd).length, 1);
        assertEq(diamond.getAsks(_cusd)[0].ercAmount, 10_000 ether);
        vm.stopPrank();

        //receiver
        //Workflow: Market - Limit Bid
        vm.startPrank(receiver);
        diamond.createBid(
            _cusd,
            uint80(diamond.getAssetPrice(_cusd)),
            1_000 ether,
            false,
            orderHints,
            shortHints
        );
        uint256 bidEth = diamond.getAssetPrice(_cusd).mul(1_000 ether);
        receiverEthEscrowed -= bidEth;
        senderEthEscrowed += bidEth;
        assertEq(diamond.getAsks(_cusd)[0].ercAmount, 10_000 ether - 1_000 ether);
        assertEq(diamond.getAssetUserStruct(_cusd, receiver).ercEscrowed, 1_000 ether);
        assertApproxEqAbs(
            diamond.getVaultUserStruct(Vault.CARBON, receiver).ethEscrowed,
            receiverEthEscrowed,
            MAX_DELTA_SMALL
        );
        assertApproxEqAbs(
            diamond.getVaultUserStruct(Vault.CARBON, sender).ethEscrowed,
            senderEthEscrowed,
            MAX_DELTA_SMALL
        );

        //Workflow: ExitShort - Escrow / Wallet / Orderbook
        assertEq(receiverShort.ercDebt, 100_000 ether);

        diamond.withdrawAsset(_cusd, 500 ether);
        assertEq(diamond.getAssetUserStruct(_cusd, receiver).ercEscrowed, 500 ether);
        diamond.exitShortErcEscrowed(_cusd, 2, 500 ether);
        receiverShort.ercDebt -= 500 ether;
        assertEq(
            diamond.getShortRecords(_cusd, receiver)[0].ercDebt, receiverShort.ercDebt
        );
        assertEq(diamond.getAssetUserStruct(_cusd, receiver).ercEscrowed, 0);
        assertEq(cusd.balanceOf(receiver), 500 ether);
        diamond.exitShortWallet(_cusd, 2, 500 ether);
        assertEq(cusd.balanceOf(receiver), 0);
        receiverShort.ercDebt -= 500 ether;
        assertEq(
            diamond.getShortRecords(_cusd, receiver)[0].ercDebt, receiverShort.ercDebt
        );
        diamond.exitShort(
            _cusd, 2, 500 ether, uint80(diamond.getAssetPrice(_cusd)), shortHints
        );
        receiverShort.ercDebt -= 500 ether;
        receiverShort.collateral -= uint80(diamond.getAssetPrice(_cusd).mul(500 ether));
        senderEthEscrowed += diamond.getAssetPrice(_cusd).mul(500 ether);
        assertEq(
            diamond.getShortRecords(_cusd, receiver)[0].ercDebt, receiverShort.ercDebt
        );
        assertEq(
            receiverShort.collateral,
            diamond.getShortRecords(_cusd, receiver)[0].collateral
        );
        assertApproxEqAbs(
            diamond.getVaultUserStruct(Vault.CARBON, sender).ethEscrowed,
            senderEthEscrowed,
            MAX_DELTA_SMALL
        );
        vm.stopPrank();

        //sender
        //Workflow: Flag + Partial Liquidation
        vm.startPrank(sender);
        diamond.flagShort(_cusd, receiver, 2, Constants.HEAD);
        assertEq(
            diamond.getFlagger(diamond.getShortRecords(_cusd, receiver)[0].flaggerId),
            sender
        );
        assertEq(
            diamond.getShortRecords(_cusd, receiver)[0].updatedAt,
            diamond.getOffsetTimeHours()
        );

        vm.expectRevert(Errors.MarginCallIneligibleWindow.selector);
        diamond.liquidate(_cusd, receiver, 2, shortHints);

        currentPrice = uint80(diamond.getAssetPrice(_cusd));
        skip(10.2 hours);

        (uint256 liquidateGas,) = diamond.liquidate(_cusd, receiver, 2, shortHints);
        receiverShort.ercDebt -= 8500 ether;
        // .00015691 accounts for gas fee
        receiverShort.collateral -=
            uint80(currentPrice.mul(8500 ether).mul(1.03 ether) + liquidateGas);
        tappEscrow += currentPrice.mul(8500 ether).mul(0.025 ether);
        senderEthEscrowed +=
            (currentPrice.mul(8500 ether).mul(1.005 ether) + liquidateGas);
        assertEq(
            diamond.getShortRecords(_cusd, receiver)[0].ercDebt, receiverShort.ercDebt
        );
        assertApproxEqAbs(
            receiverShort.collateral,
            diamond.getShortRecords(_cusd, receiver)[0].collateral,
            0.0000001 ether
        );
        assertEq(
            // _diamond is TAPP
            diamond.getVaultUserStruct(Vault.CARBON, _diamond).ethEscrowed,
            tappEscrow
        );
        assertApproxEqAbs(
            diamond.getVaultUserStruct(Vault.CARBON, sender).ethEscrowed,
            senderEthEscrowed,
            0.0000001 ether
        );

        //Workflow: Secondary Liquidation
        MTypes.BatchMC[] memory batchMargin = new MTypes.BatchMC[](1);
        batchMargin[0] = MTypes.BatchMC({shorter: receiver, shortId: 2});
        diamond.liquidateSecondary(_cusd, batchMargin, 90_000 ether, false);
        receiverShort.collateral -=
            uint80(diamond.getProtocolAssetPrice(_cusd).mul(90_000 ether));
        senderEthEscrowed += diamond.getProtocolAssetPrice(_cusd).mul(90_000 ether);
        receiverEthEscrowed += receiverShort.collateral;
        assertApproxEqAbs(
            diamond.getVaultUserStruct(Vault.CARBON, sender).ethEscrowed,
            senderEthEscrowed,
            0.0000001 ether
        );
        assertApproxEqAbs(
            diamond.getVaultUserStruct(Vault.CARBON, receiver).ethEscrowed,
            receiverEthEscrowed,
            0.0000001 ether
        );

        assertEq(diamond.getAsks(_cusd).length, 0);
        assertEq(diamond.getBids(_cusd).length, 0);
        assertEq(diamond.getShorts(_cusd).length, 0);
        assertEq(diamond.getShortRecordCount(_cusd, receiver), 0);
        assertEq(diamond.getShortRecordCount(_cusd, sender), 0);
        assertEq(diamond.getAssetUserStruct(_cusd, sender).ercEscrowed, 0);
        assertEq(diamond.getAssetUserStruct(_cusd, receiver).ercEscrowed, 0);
        assertSR(diamond.getShortRecord(_cusd, receiver, 2).status, SR.Cancelled);

        //Workflow: Vault - Deposit Zeth
        diamond.depositZETH(_zeth, 100 ether);
        senderEthEscrowed += 100 ether;
        assertEq(zeth.balanceOf(sender), 0);
        assertApproxEqAbs(
            diamond.getVaultUserStruct(Vault.CARBON, sender).ethEscrowed,
            senderEthEscrowed,
            0.0000001 ether
        );
        assertApproxEqAbs(
            diamond.getVaultStruct(Vault.CARBON).zethTotal,
            diamond.getVaultUserStruct(Vault.CARBON, sender).ethEscrowed
                + diamond.getVaultUserStruct(Vault.CARBON, receiver).ethEscrowed
                + diamond.getVaultUserStruct(Vault.CARBON, _diamond).ethEscrowed,
            MAX_DELTA
        );

        vm.selectFork(bridgeFork);

        //Workflow: Bridge Steth - Withdraw
        diamond.withdraw(_bridgeSteth, 400 ether);
        senderEthEscrowed -= 400 ether;
        assertApproxEqAbs(
            diamond.getVaultUserStruct(Vault.CARBON, sender).ethEscrowed,
            senderEthEscrowed,
            0.0000001 ether
        );
        assertEq(steth.balanceOf(_bridgeSteth), 100 ether);
        assertApproxEqAbs(steth.balanceOf(sender), 400 ether, MAX_DELTA_SMALL);

        //Workflow: Bridge Steth - Unstake
        diamond.unstakeEth(_bridgeSteth, 100 ether);
        senderEthEscrowed -= 100 ether;
        assertApproxEqAbs(
            diamond.getVaultUserStruct(Vault.CARBON, sender).ethEscrowed,
            senderEthEscrowed,
            0.0000001 ether
        );
        assertApproxEqAbs(steth.balanceOf(_bridgeSteth), 0, MAX_DELTA);
        assertEq(unsteth.balanceOf(sender), 1);

        //Workflow: Bridge Reth - Withdraw
        uint256 withdrawnReth = reth.getRethValue(senderEthEscrowed).mul(0.995 ether);
        diamond.withdraw(
            _bridgeReth, diamond.getVaultUserStruct(Vault.CARBON, sender).ethEscrowed
        );
        assertEq(diamond.getVaultUserStruct(Vault.CARBON, sender).ethEscrowed, 0);
        assertApproxEqAbs(reth.balanceOf(sender), withdrawnReth, 0.0000001 ether);

        //receiver
        vm.startPrank(receiver);
        diamond.withdraw(_bridgeReth, 400 ether);
        withdrawnReth = reth.getRethValue(400 ether).mul(0.995 ether);
        receiverEthEscrowed -= 400 ether;
        assertApproxEqAbs(
            diamond.getVaultUserStruct(Vault.CARBON, receiver).ethEscrowed,
            receiverEthEscrowed,
            0.0000001 ether
        );
        assertApproxEqAbs(reth.balanceOf(receiver), withdrawnReth, 0.0000001 ether);
        vm.stopPrank();

        //Setup for unstake Reth
        deal(_reth, 100 ether);

        //Workflow: Bridge Reth - Unstake
        vm.startPrank(receiver);
        diamond.unstakeEth(
            _bridgeReth, diamond.getVaultUserStruct(Vault.CARBON, receiver).ethEscrowed
        );
        assertEq(diamond.getVaultUserStruct(Vault.CARBON, receiver).ethEscrowed, 0);

        assertApproxEqAbs(
            diamond.getVaultUserStruct(Vault.CARBON, _diamond).ethEscrowed,
            diamond.getVaultStruct(Vault.CARBON).zethTotal,
            MAX_DELTA
        );
    }
}
