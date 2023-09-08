// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {Events} from "contracts/libraries/Events.sol";
import {MTypes} from "contracts/libraries/DataTypes.sol";
import {Constants, Vault} from "contracts/libraries/Constants.sol";
import {OBFixture} from "test/utils/OBFixture.sol";
import {U256, U88} from "contracts/libraries/PRBMathHelper.sol";

// import {console} from "contracts/libraries/console.sol";

contract EventsTest is OBFixture {
    using U256 for uint256;
    using U88 for uint88;

    uint16[] public shortHints = new uint16[](1);

    function setUp() public override {
        super.setUp();
        deal(sender, 500 ether);
        deal(receiver, 500 ether);
    }

    function test_Events() public {
        MTypes.OrderHint[] memory orderHints = new MTypes.OrderHint[](1);
        uint32 currentTime = uint32(diamond.getOffsetTime());

        vm.prank(sender);
        vm.expectEmit(_diamond);
        emit Events.DepositEth(_bridgeReth, sender, 500 ether);
        diamond.depositEth{value: 500 ether}(_bridgeReth);

        vm.startPrank(receiver);
        vm.expectEmit(_diamond);
        emit Events.DepositEth(_bridgeSteth, receiver, 500 ether);
        diamond.depositEth{value: 500 ether}(_bridgeSteth);

        vm.expectEmit(_diamond);
        emit Events.CreateShort(_cusd, receiver, 100, currentTime);
        diamond.createLimitShort(
            _cusd, DEFAULT_PRICE, 10_000 ether, orderHints, shortHints, initialMargin
        );

        vm.stopPrank();

        vm.startPrank(sender);
        vm.expectEmit(_diamond);
        emit Events.CreateBid(_cusd, sender, 101, currentTime);
        diamond.createBid(
            _cusd, DEFAULT_PRICE, 10_000 ether, false, orderHints, shortHints
        );

        diamond.withdrawZETH(_zeth, 100 ether);

        diamond.withdrawAsset(_cusd, 10_000 ether);

        diamond.depositAsset(_cusd, 10_000 ether);

        vm.expectEmit(_diamond);
        emit Events.CreateAsk(_cusd, sender, 101, currentTime);
        diamond.createAsk(
            asset, DEFAULT_PRICE, 5_000 ether, Constants.LIMIT_ORDER, orderHints
        );
        vm.stopPrank();

        vm.startPrank(receiver);
        diamond.mintNFT(asset, Constants.SHORT_STARTING_ID);
        diamond.setApprovalForAll(address(this), true);
        vm.expectEmit(_diamond);
        emit Events.CreateShortRecord(_cusd, sender, 2);
        diamond.safeTransferFrom(receiver, sender, 1, "");
        vm.stopPrank();

        vm.prank(sender);
        vm.expectEmit(_diamond);
        emit Events.Transfer(sender, extra, 1);
        diamond.safeTransferFrom(sender, extra, 1, "");

        vm.prank(extra);
        vm.expectEmit(_diamond);
        emit Events.DeleteShortRecord(asset, extra, Constants.SHORT_STARTING_ID);
        diamond.safeTransferFrom(extra, receiver, 1, "");

        vm.startPrank(receiver);
        vm.expectEmit(_diamond);
        emit Events.DecreaseCollateral(_cusd, receiver, 2, 2 ether);
        diamond.decreaseCollateral(_cusd, 2, 2 ether);

        deal(_steth, _bridgeSteth, 700 ether);
        skip(2 hours);
        _setETH(4000 ether);
        diamond.updateYield(Vault.CARBON);

        address[] memory assetArr = new address[](1);
        assetArr[0] = _cusd;
        vm.expectEmit(_diamond);
        emit Events.DistributeYield(
            Vault.CARBON, receiver, 179999999999999999989, 179999999999999999989
        );
        diamond.distributeYield(assetArr);

        diamond.withdrawDittoReward(Vault.CARBON);

        vm.expectEmit(_diamond);
        emit Events.IncreaseCollateral(_cusd, receiver, 2, 1 ether);
        diamond.increaseCollateral(_cusd, 2, 1 ether);

        diamond.createBid(_cusd, DEFAULT_PRICE, 1000 ether, false, orderHints, shortHints);

        vm.expectEmit(_diamond);
        emit Events.ExitShortErcEscrowed(_cusd, receiver, 2, 500 ether);
        diamond.exitShortErcEscrowed(_cusd, 2, 500 ether);

        diamond.withdrawAsset(_cusd, 500 ether);

        vm.expectEmit(_diamond);
        emit Events.ExitShortWallet(_cusd, receiver, 2, 500 ether);
        diamond.exitShortWallet(_cusd, 2, 500 ether);

        vm.expectEmit(_diamond);
        emit Events.ExitShort(_cusd, receiver, 2, 500 ether);
        diamond.exitShort(_cusd, 2, 500 ether, DEFAULT_PRICE, shortHints);
        vm.stopPrank();

        _setETH(2200 ether);

        vm.startPrank(sender);
        vm.expectEmit(_diamond);
        emit Events.FlagShort(_cusd, receiver, 2, sender, diamond.getOffsetTimeHours());
        diamond.flagShort(_cusd, receiver, 2, Constants.HEAD);
        skip(11 hours);
        _setETH(2200 ether);

        vm.expectEmit(_diamond);
        emit Events.Liquidate(_cusd, receiver, 2, sender, 3500 ether);
        diamond.liquidate(_cusd, receiver, 2, shortHints);

        _setETH(500 ether);
        skip(30 minutes);

        MTypes.BatchMC[] memory batchMargin = new MTypes.BatchMC[](1);
        batchMargin[0] = MTypes.BatchMC({shorter: receiver, shortId: 2});

        vm.expectEmit(_diamond);
        emit Events.LiquidateSecondary(_cusd, batchMargin, sender, false);
        diamond.liquidateSecondary(_cusd, batchMargin, 5000 ether, false);

        diamond.depositZETH(_zeth, 100 ether);

        vm.expectEmit(_diamond);
        emit Events.Withdraw(_bridgeSteth, sender, 400 ether, 0);
        diamond.withdraw(_bridgeSteth, 400 ether);

        vm.expectEmit(_diamond);
        emit Events.UnstakeEth(_bridgeSteth, sender, 100 ether, 0);
        diamond.unstakeEth(_bridgeSteth, 100 ether);

        uint88 withdrawReth = diamond.getVaultUserStruct(Vault.CARBON, sender).ethEscrowed;
        uint256 withdrawFee = withdrawReth.mul(0.005 ether);

        vm.expectEmit(_diamond);
        emit Events.Withdraw(_bridgeReth, sender, withdrawReth - withdrawFee, withdrawFee);
        diamond.withdraw(_bridgeReth, withdrawReth);
    }
}
