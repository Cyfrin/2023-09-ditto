// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {Constants} from "contracts/libraries/Constants.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {F} from "contracts/libraries/DataTypes.sol";
import {OBFixture} from "test/utils/OBFixture.sol";

contract FreezeFunctionsTest is OBFixture {
    function setUp() public override {
        super.setUp();
    }

    function makeShorts() public {
        fundLimitBidOpt(1 ether, DEFAULT_AMOUNT + 1 ether, receiver);
        fundLimitShortOpt(1 ether, DEFAULT_AMOUNT + 1 ether, sender);
        fundLimitBidOpt(2 ether, DEFAULT_AMOUNT + 1 ether, receiver);
        fundLimitShortOpt(2 ether, DEFAULT_AMOUNT + 1 ether, sender);
        fundLimitBidOpt(3 ether, DEFAULT_AMOUNT + 1 ether, receiver);
        fundLimitShortOpt(3 ether, DEFAULT_AMOUNT + 1 ether, sender);

        r.ercEscrowed = (DEFAULT_AMOUNT + 1 ether) * 3;
        assertStruct(receiver, r);
        assertStruct(sender, s);
    }

    function testFreezeCombineShorts() public {
        makeShorts();

        vm.prank(owner);
        diamond.setFrozenT(asset, F.Permanent);
        vm.prank(sender);
        vm.expectRevert(Errors.AssetIsFrozen.selector);
        combineShorts({
            id1: Constants.SHORT_STARTING_ID,
            id2: Constants.SHORT_STARTING_ID + 2
        });
        vm.prank(owner);
        vm.expectRevert(Errors.AssetIsFrozen.selector);
        combineShorts({
            id1: Constants.SHORT_STARTING_ID,
            id2: Constants.SHORT_STARTING_ID + 2
        });

        vm.prank(owner);
        diamond.setFrozenT(asset, F.Unfrozen);
        vm.prank(sender);
        combineShorts({
            id1: Constants.SHORT_STARTING_ID,
            id2: Constants.SHORT_STARTING_ID + 2
        });
    }

    function testFreezeIncreaseCollateral() public {
        makeShorts();
        vm.prank(owner);
        diamond.setFrozenT(asset, F.Permanent);
        vm.prank(sender);
        vm.expectRevert(Errors.AssetIsFrozen.selector);
        increaseCollateral(Constants.SHORT_STARTING_ID, 1 ether);
    }

    function testFreezeDecreaseCollateral() public {
        makeShorts();
        vm.prank(owner);
        diamond.setFrozenT(asset, F.Permanent);
        vm.prank(sender);
        vm.expectRevert(Errors.AssetIsFrozen.selector);
        decreaseCollateral(Constants.SHORT_STARTING_ID, 1 ether);
    }

    function testFreezeCreateAsk() public {
        vm.prank(owner);
        diamond.setFrozenT(asset, F.Permanent);
        vm.prank(sender);
        vm.expectRevert(Errors.AssetIsFrozen.selector);
        createLimitAsk(1 ether, 1 ether);
    }

    function testFreezeCreateLimitShort() public {
        vm.prank(owner);
        diamond.setFrozenT(asset, F.Permanent);
        vm.prank(sender);
        vm.expectRevert(Errors.AssetIsFrozen.selector);

        diamond.createLimitShort(
            asset,
            1 ether,
            1 ether,
            badOrderHintArray,
            shortHintArrayStorage,
            initialMargin
        );
    }

    function testFreezeCreateBid() public {
        vm.prank(owner);
        diamond.setFrozenT(asset, F.Permanent);
        vm.prank(sender);
        vm.expectRevert(Errors.AssetIsFrozen.selector);
        createLimitBid(1 ether, 1 ether);
    }

    function testFreezeExitShort() public {
        vm.prank(owner);
        diamond.setFrozenT(asset, F.Permanent);
        vm.prank(_exitShort);
        vm.expectRevert(Errors.AssetIsFrozen.selector);
        diamond.exitShort(asset, 0, 2 ether, 1, shortHintArrayStorage);
    }

    function testFreezeExitShortWallet() public {
        vm.prank(owner);
        diamond.setFrozenT(asset, F.Permanent);
        vm.prank(_exitShort);
        vm.expectRevert(Errors.AssetIsFrozen.selector);
        diamond.exitShortWallet(asset, 1, 1);
    }

    function testFreezeExitShortErcEscrowed() public {
        vm.prank(owner);
        diamond.setFrozenT(asset, F.Permanent);
        vm.prank(_exitShort);
        vm.expectRevert(Errors.AssetIsFrozen.selector);
        diamond.exitShortErcEscrowed(asset, 1, 1);
    }

    function testFreezeLiquidate() public {
        vm.prank(owner);
        diamond.setFrozenT(asset, F.Permanent);
        vm.prank(sender);
        vm.expectRevert(Errors.AssetIsFrozen.selector);
        diamond.liquidate(asset, sender, 1, shortHintArrayStorage);
    }

    function testFreezeMintNFT() public {
        vm.prank(owner);
        diamond.setFrozenT(asset, F.Permanent);
        vm.prank(sender);
        vm.expectRevert(Errors.AssetIsFrozen.selector);
        diamond.mintNFT(asset, 2);
    }
}
