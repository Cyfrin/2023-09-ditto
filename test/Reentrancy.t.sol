// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256} from "contracts/libraries/PRBMathHelper.sol";

import {Errors} from "contracts/libraries/Errors.sol";
import {F, MTypes} from "contracts/libraries/DataTypes.sol";
import {Constants} from "contracts/libraries/Constants.sol";

import {OBFixture} from "test/utils/OBFixture.sol";
// import {console} from "contracts/libraries/console.sol";

contract ReentrancyTest is OBFixture {
    using U256 for uint256;

    function setUp() public override {
        super.setUp();
        testFacet.setReentrantStatus(Constants.ENTERED);
    }

    //Non-view
    function testReentrancyCreateAsk() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.createAsk(
            asset, DEFAULT_PRICE, DEFAULT_AMOUNT, Constants.LIMIT_ORDER, badOrderHintArray
        );
    }

    function testReentrancyCreateBid() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.createBid(
            asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT,
            Constants.LIMIT_ORDER,
            badOrderHintArray,
            shortHintArrayStorage
        );
    }

    function testReentrancyDeposit() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.deposit(_bridgeReth, DEFAULT_AMOUNT);
    }

    function testReentrancyDepositEth() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.depositEth{value: 5 ether}(_bridgeSteth);
    }

    function testReentrancyWithdraw() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.withdraw(_bridgeReth, 1);
    }

    function testReentrancyExitShortWallet() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.exitShortWallet(asset, 1, 1);
    }

    function testReentrancyExitShortErcEscrowed() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.exitShortErcEscrowed(asset, 1, 1);
    }

    function testReentrancyExitShort() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.exitShort(asset, 100, 2 ether, DEFAULT_PRICE, shortHintArrayStorage);
    }

    function testReentrancyRedeemErc() public {
        vm.prank(owner);
        diamond.setFrozenT(asset, F.Permanent);
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.redeemErc(asset, 0, DEFAULT_AMOUNT);
    }

    function testReentrancyFlagShort() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.flagShort(asset, sender, 100, Constants.HEAD);
    }

    function testReentrancyLiquidateWallet() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        liquidateWallet(sender, 100, DEFAULT_AMOUNT, receiver);
    }

    function testReentrancyLiquidateErcEscrowed() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        liquidateErcEscrowed(sender, 100, DEFAULT_AMOUNT, receiver);
    }

    function testReentrancyLiquidate() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.liquidate(asset, sender, 100, shortHintArrayStorage);
    }

    function testReentrancyCancelBid() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.cancelBid(asset, 1);
    }

    function testReentrancyCancelAsk() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.cancelAsk(asset, 1);
    }

    function testReentrancyCancelShort() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.cancelShort(asset, 1);
    }

    function testReentrancyIncreaseCollateral() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.increaseCollateral(asset, 100, 120 ether);
    }

    function testReentrancyDecreaseCollateral() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.decreaseCollateral(asset, 100, 120 ether);
    }

    function testReentrancyCombineShorts() public {
        uint8[] memory shortRecords = new uint8[](3);
        shortRecords[0] = 100;
        shortRecords[1] = 101;
        shortRecords[2] = 102;
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.combineShorts(asset, shortRecords);
    }

    function testReentrancyDepositAsset() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.depositAsset(_cusd, 1 ether);
    }

    function testReentrancyWithdrawAsset() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.withdrawAsset(asset, DEFAULT_AMOUNT);
    }

    function testReentrancyUpdateYield() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.updateYield(vault);
    }

    function testReentrancyDistributeYield() public {
        address[] memory assets = new address[](1);
        assets[0] = asset;

        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.distributeYield(assets);
    }

    function testReentrancyClaimDittoMatchedReward() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.claimDittoMatchedReward(vault);
    }

    function testReentrancyWithdrawDittoReward() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.withdrawDittoReward(vault);
    }

    //View

    function testReentrancyViewGetAssetCollateralRatio() public {
        vm.expectRevert(Errors.ReentrantCallView.selector);
        diamond.getAssetCollateralRatio(asset);
    }

    function testReentrancyViewBids() public {
        vm.expectRevert(Errors.ReentrantCallView.selector);
        diamond.getBids(asset);
    }

    function testReentrancyViewAsks() public {
        vm.expectRevert(Errors.ReentrantCallView.selector);
        diamond.getAsks(asset);
    }

    function testReentrancyViewShorts() public {
        vm.expectRevert(Errors.ReentrantCallView.selector);
        diamond.getShorts(asset);
    }

    function testReentrancyViewGetShortIdAtOracle() public {
        vm.expectRevert(Errors.ReentrantCallView.selector);
        diamond.getShortIdAtOracle(asset);
    }

    function testReentrancyViewGetShortRecords() public {
        vm.expectRevert(Errors.ReentrantCallView.selector);
        diamond.getShortRecords(asset, sender);
    }

    function testReentrancyViewGetShortRecord() public {
        vm.expectRevert(Errors.ReentrantCallView.selector);
        diamond.getShortRecord(asset, sender, 1);
    }

    function testReentrancyViewgetShortRecordCount() public {
        vm.expectRevert(Errors.ReentrantCallView.selector);
        diamond.getShortRecordCount(asset, sender);
    }

    function testReentrancyViewGetZethBalance() public {
        vm.expectRevert(Errors.ReentrantCallView.selector);
        diamond.getZethBalance(vault, sender);
    }

    function testReentrancyViewGetAssetBalance() public {
        vm.expectRevert(Errors.ReentrantCallView.selector);
        diamond.getAssetBalance(asset, sender);
    }

    function testReentrancyViewGetUndistributedYield() public {
        vm.expectRevert(Errors.ReentrantCallView.selector);
        diamond.getUndistributedYield(vault);
    }

    function testReentrancyViewGetYield() public {
        vm.expectRevert(Errors.ReentrantCallView.selector);
        diamond.getYield(asset, sender);
    }

    function testReentrancyViewGetDittoMatchedReward() public {
        vm.expectRevert(Errors.ReentrantCallView.selector);
        diamond.getDittoMatchedReward(vault, sender);
    }

    function testReentrancyViewGetDittoReward() public {
        vm.expectRevert(Errors.ReentrantCallView.selector);
        diamond.getDittoReward(vault, sender);
    }
}
