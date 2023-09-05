// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U88, U80} from "contracts/libraries/PRBMathHelper.sol";
import {Constants} from "contracts/libraries/Constants.sol";
import {ForkHelper} from "test/fork/ForkHelper.sol";

import {Vault} from "contracts/libraries/Constants.sol";
import {MTypes, STypes, SR} from "contracts/libraries/DataTypes.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {IMockAggregatorV3} from "interfaces/IMockAggregatorV3.sol";
import {IAsset} from "interfaces/IAsset.sol";

// import {console} from "contracts/libraries/console.sol";

contract MultiAssetForkTest is ForkHelper {
    using U256 for uint256;
    using U88 for uint88;
    using U80 for uint80;

    //current price at block 15_333_111 above using chainlink
    uint256 public currentEthPriceUSD = 1992.70190598 ether;
    uint16[] public shortHints = new uint16[](1);
    STypes.ShortRecord public receiverShort;
    uint256 public receiverPostCollateral;
    uint256 public receiverEthEscrowed;
    uint256 public receiverErcEscrowed;
    uint256 public senderEthEscrowed;
    uint256 public senderErcEscrowed;
    uint80 public currentPrice;
    address public _cxau;
    IAsset public cxau;
    address public _xauAggregator;
    IMockAggregatorV3 public xauAggregator;

    function setUp() public virtual override {
        super.setUp();

        _xauAggregator = address(0x214eD9Da11D2fbe465a6fc601a91E62EbEc1a0D6);
        xauAggregator = IMockAggregatorV3(_xauAggregator);

        _cxau = deployCode("Asset.sol", abi.encode(_diamond, "Carbon Gold", "CXAU"));
        cxau = IAsset(_cxau);
        vm.label(_cxau, "CXAU");

        STypes.Asset memory a;
        a.vault = uint8(Vault.CARBON);
        a.oracle = _xauAggregator;
        a.initialMargin = 400; // 400 -> 4 ether
        a.primaryLiquidationCR = 350; // 300 -> 3 ether
        a.secondaryLiquidationCR = 300; // 200 -> 2 ether
        a.forcedBidPriceBuffer = 120; // 120 -> 1.2 ether
        a.resetLiquidationTime = 1400; // 1400 -> 14 hours
        a.secondLiquidationTime = 1000; // 1000 -> 10 hours
        a.firstLiquidationTime = 800; // 800 -> 8 hours
        a.minimumCR = 120; // 120 -> 1.2 ether
        a.tappFeePct = 30; // 30 -> .03 ether
        a.callerFeePct = 6; // 10 -> .006 ether
        a.minBidEth = 1; // 1 -> .001 ether
        a.minAskEth = 1; // 1 -> .001 ether
        a.minShortErc = 1; // 1 -> 1 ether

        vm.prank(owner);
        diamond.createMarket({asset: _cxau, a: a});

        deal(sender, 1000 ether);
        deal(receiver, 1000 ether);

        vm.makePersistent(_cxau);
        vm.prank(sender);
        diamond.depositEth{value: 500 ether}(_bridgeReth);
        vm.prank(receiver);
        diamond.depositEth{value: 500 ether}(_bridgeSteth);
        skip(1 hours);
        senderEthEscrowed = diamond.getVaultUserStruct(Vault.CARBON, sender).ethEscrowed;
        receiverEthEscrowed =
            diamond.getVaultUserStruct(Vault.CARBON, receiver).ethEscrowed;
        currentPrice = diamond.getOraclePriceT(_cxau);
        assertApproxEqAbs(currentPrice, 0.903386499805991418 ether, MAX_DELTA_SMALL);
        //eth/usd ~ $1992.27
        //xau/usd ~ $1800.18
        //xau/eth ~ .9033 eth

        assertEq(diamond.getAssetUserStruct(_cxau, sender).ercEscrowed, 0);
        assertEq(diamond.getAssetUserStruct(_cxau, receiver).ercEscrowed, 0);
        assertEq(diamond.getAsks(_cxau).length, 0);
    }

    function checkEthEscrowed(address user) internal {
        uint256 amount;
        if (user == sender) {
            amount = senderEthEscrowed;
        } else if (user == receiver) {
            amount = receiverEthEscrowed;
        } else {
            revert("bad user");
        }

        assertApproxEqAbs(
            diamond.getVaultUserStruct(Vault.CARBON, user).ethEscrowed, amount, MAX_DELTA
        );
    }

    function checkErcEscrowed(address user) internal {
        uint256 amount;
        if (user == sender) {
            amount = senderErcEscrowed;
        } else if (user == receiver) {
            amount = receiverErcEscrowed;
        } else {
            revert("bad user");
        }
        assertApproxEqAbs(
            diamond.getAssetUserStruct(_cxau, user).ercEscrowed, amount, MAX_DELTA
        );
    }

    function checkErcDebt() internal {
        assertApproxEqAbs(
            diamond.getShortRecords(_cxau, receiver)[0].ercDebt,
            receiverShort.ercDebt,
            MAX_DELTA_SMALL
        );
    }

    function checkCollateral() internal {
        assertApproxEqAbs(
            diamond.getShortRecords(_cxau, receiver)[0].collateral,
            receiverShort.collateral,
            MAX_DELTA_SMALL
        );
    }

    function testFork_MultiAsset() public {
        MTypes.OrderHint[] memory orderHints = new MTypes.OrderHint[](1);
        uint16 initialMargin = diamond.getAssetStruct(_cxau).initialMargin;
        vm.prank(receiver);
        diamond.createLimitShort(
            _cxau, currentPrice, 50 ether, orderHints, shortHints, initialMargin
        );
        receiverPostCollateral = diamond.getAssetNormalizedStruct(_cxau).initialMargin.mul(
            currentPrice.mul(50 ether)
        );
        receiverEthEscrowed -= receiverPostCollateral;
        checkEthEscrowed(receiver);

        shortHints[0] = diamond.getShortIdAtOracle(_cxau);
        vm.prank(sender);
        diamond.createBid(_cxau, currentPrice, 25 ether, false, orderHints, shortHints);
        senderEthEscrowed -= currentPrice.mul(25 ether);
        checkEthEscrowed(sender);
        senderErcEscrowed += 25 ether;
        checkErcEscrowed(sender);
        assertEq(diamond.getShorts(_cxau).length, 1);

        vm.prank(sender);
        diamond.createBid(_cxau, currentPrice, 25 ether, false, orderHints, shortHints);
        senderEthEscrowed -= currentPrice.mul(25 ether);
        checkEthEscrowed(sender);
        senderErcEscrowed += 25 ether;
        checkErcEscrowed(sender);
        assertEq(diamond.getShorts(_cxau).length, 0);

        receiverShort = diamond.getShortRecords(_cxau, receiver)[0];
        assertEq(receiverShort.ercDebt, 50 ether);
        assertEq(
            receiverShort.collateral, receiverPostCollateral + currentPrice.mul(50 ether)
        );
        assertSR(SR.FullyFilled, receiverShort.status);

        vm.prank(receiver);
        diamond.decreaseCollateral(
            _cxau, receiverShort.id, uint88(currentPrice.mul(50 ether))
        );
        receiverEthEscrowed += currentPrice.mul(50 ether);
        checkEthEscrowed(receiver);
        receiverShort.collateral -= uint88(currentPrice.mul(50 ether));
        checkCollateral();

        vm.prank(sender);
        vm.expectRevert(Errors.SufficientCollateral.selector);
        diamond.liquidate(_cxau, receiver, receiverShort.id, shortHints);

        vm.selectFork(liquidationFork);

        currentPrice = uint80(diamond.getProtocolAssetPrice(_cxau));

        vm.prank(receiver);
        diamond.createBid(_cxau, currentPrice, 2 ether, false, orderHints, shortHints);
        assertEq(diamond.getBids(_cxau).length, 1);
        receiverEthEscrowed -= currentPrice.mul(2 ether);
        checkEthEscrowed(receiver);

        vm.prank(sender);
        diamond.createAsk(_cxau, currentPrice, 15 ether, false, orderHints);
        assertEq(diamond.getAsks(_cxau).length, 1);
        senderErcEscrowed -= 15 ether;
        checkErcEscrowed(sender);
        senderEthEscrowed += currentPrice.mul(2 ether);
        checkEthEscrowed(sender);
        receiverErcEscrowed += 2 ether;
        checkErcEscrowed(receiver);

        vm.startPrank(receiver);
        STypes.Vault memory oldVault = diamond.getVaultStruct(Vault.CARBON);
        assertEq(diamond.getVaultUserStruct(Vault.CARBON, receiver).dittoReward, 0);

        diamond.updateYield(Vault.CARBON);
        address[] memory assetArr = new address[](1);
        assetArr[0] = _cxau;
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

        diamond.increaseCollateral(_cxau, receiverShort.id, 1 ether);
        receiverEthEscrowed -= 1 ether;
        checkEthEscrowed(receiver);
        receiverShort.collateral += 1 ether;
        checkCollateral();

        diamond.withdrawAsset(_cxau, 1 ether);
        receiverErcEscrowed -= 1 ether;
        checkErcEscrowed(receiver);
        assertEq(cxau.balanceOf(receiver), 1 ether);

        diamond.exitShortWallet(_cxau, receiverShort.id, 1 ether);
        assertEq(cxau.balanceOf(receiver), 0);
        receiverShort.ercDebt -= 1 ether;
        checkErcDebt();

        diamond.exitShortErcEscrowed(_cxau, receiverShort.id, 1 ether);
        receiverErcEscrowed -= 1 ether;
        checkErcEscrowed(receiver);
        receiverShort.ercDebt -= 1 ether;
        checkErcDebt();

        diamond.exitShort(_cxau, receiverShort.id, 8 ether, currentPrice, shortHints);
        receiverShort.collateral -= uint80(currentPrice.mul(8 ether));
        checkCollateral();
        receiverShort.ercDebt -= 8 ether;
        checkErcDebt();
        senderEthEscrowed += uint80(currentPrice.mul(8 ether));
        checkEthEscrowed(sender);
        vm.stopPrank();

        vm.startPrank(sender);
        diamond.flagShort(_cxau, receiver, receiverShort.id, Constants.HEAD);
        assertEq(
            diamond.getFlagger(diamond.getShortRecords(_cxau, receiver)[0].flaggerId),
            sender
        );
        assertEq(
            diamond.getShortRecords(_cxau, receiver)[0].updatedAt,
            diamond.getOffsetTimeHours()
        );

        vm.expectRevert(Errors.MarginCallIneligibleWindow.selector);
        diamond.liquidate(_cxau, receiver, receiverShort.id, shortHints);

        skip(10.3 hours);

        (uint256 liquidateGas,) =
            diamond.liquidate(_cxau, receiver, receiverShort.id, shortHints);
        receiverShort.ercDebt -= 5 ether;
        checkErcDebt();
        receiverShort.collateral -=
            uint80(currentPrice.mul(5 ether).mul(1.036 ether) + liquidateGas);
        checkCollateral();
        senderEthEscrowed += (currentPrice.mul(5 ether).mul(1.006 ether) + liquidateGas);
        checkEthEscrowed(sender);
        tappEscrow += currentPrice.mul(5 ether).mul(0.03 ether);
        assertEq(
            // _diamond is TAPP
            diamond.getVaultUserStruct(Vault.CARBON, _diamond).ethEscrowed,
            tappEscrow
        );
        assertEq(diamond.getAsks(_cxau).length, 0);

        vm.stopPrank();
        vm.startPrank(owner);
        diamond.setOracleTimeAndPrice(_cxau, diamond.getOraclePriceT(_cxau));
        diamond.setOracleTimeAndPrice(
            _cusd, uint256(ethAggregator.latestAnswer() * ORACLE_DECIMALS).inv()
        );
        vm.stopPrank();

        MTypes.BatchMC[] memory batchMargin = new MTypes.BatchMC[](1);
        batchMargin[0] = MTypes.BatchMC({shorter: receiver, shortId: receiverShort.id});
        vm.prank(sender);
        diamond.liquidateSecondary(_cxau, batchMargin, 35 ether, false);
        receiverShort.collateral -= uint80(currentPrice.mul(35 ether));
        receiverEthEscrowed += receiverShort.collateral;
        checkEthEscrowed(receiver);
        assertEq(
            uint8(diamond.getShortRecord(_cxau, receiver, receiverShort.id).status),
            uint8(SR.Cancelled)
        );

        senderEthEscrowed += uint80(currentPrice.mul(35 ether));
        checkEthEscrowed(sender);

        senderErcEscrowed = 0;
        checkErcEscrowed(sender);
    }
}
