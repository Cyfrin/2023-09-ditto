// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {STypes, MTypes, O} from "contracts/libraries/DataTypes.sol";

import {OBFixture} from "test/utils/OBFixture.sol";

contract InactiveOrdersTest is OBFixture {
    function setUp() public override {
        super.setUp();
    }

    function testOrderIdBids() public {
        assertEq(diamond.getAssetStruct(asset).orderId, 100);
        fundLimitBidOpt(4 ether, 1 ether, receiver);
        assertEq(diamond.getAssetStruct(asset).orderId, 101);

        vm.prank(receiver);
        cancelBid(100);
        assertEq(diamond.getAssetStruct(asset).orderId, 101);

        fundLimitBidOpt(4 ether, 1 ether, receiver);
        assertEq(diamond.getAssetStruct(asset).orderId, 101);

        fundLimitBidOpt(3 ether, 1 ether, receiver);
        assertEq(diamond.getAssetStruct(asset).orderId, 102);

        vm.prank(receiver);
        cancelBid(100);
        assertEq(diamond.getAssetStruct(asset).orderId, 102);

        vm.prank(receiver);
        cancelBid(101);
        assertEq(diamond.getAssetStruct(asset).orderId, 102);

        fundLimitBidOpt(4 ether, 1 ether, receiver);
        assertEq(diamond.getAssetStruct(asset).orderId, 102);
        fundLimitBidOpt(3 ether, 1 ether, receiver);
        assertEq(diamond.getAssetStruct(asset).orderId, 102);
        fundLimitBidOpt(2 ether, 1 ether, receiver);
        assertEq(diamond.getAssetStruct(asset).orderId, 103);
    }

    function testCancelInactiveBidOrders() public {
        fundLimitBidOpt(4 ether, 1 ether, receiver);
        STypes.Order[] memory bids = getBids();
        assertEq(bids.length, 1);
        assertEq(bids[0].id, 100);
        assertEq(bids[0].price, 4 ether);
        STypes.Order[] memory inactiveBids = testFacet.currentInactiveBids(asset);
        assertEq(inactiveBids.length, 0);

        vm.prank(receiver);
        cancelBid(100);

        bids = getBids();
        assertEq(bids.length, 0);
        inactiveBids = testFacet.currentInactiveBids(asset);
        assertEq(inactiveBids.length, 1);
        assertEq(inactiveBids[0].id, 100);
        assertEq(inactiveBids[0].price, 4 ether);
        assertEq(inactiveBids[0].orderType, O.Cancelled);

        fundLimitBidOpt(4 ether, 1 ether, receiver);
        fundLimitBidOpt(3 ether, 1 ether, receiver);

        bids = getBids();
        assertEq(bids.length, 2);
        assertEq(bids[0].id, 100);
        assertEq(bids[0].price, 4 ether);
        assertEq(bids[1].id, 101);
        assertEq(bids[1].price, 3 ether);
        inactiveBids = testFacet.currentInactiveBids(asset);
        assertEq(inactiveBids.length, 0);

        vm.prank(receiver);
        cancelBid(100);

        bids = getBids();
        assertEq(bids.length, 1);
        assertEq(bids[0].id, 101);
        assertEq(bids[0].price, 3 ether);
        inactiveBids = testFacet.currentInactiveBids(asset);
        assertEq(inactiveBids.length, 1);
        assertEq(inactiveBids[0].id, 100);
        assertEq(inactiveBids[0].price, 4 ether);
        assertEq(inactiveBids[0].orderType, O.Cancelled);

        vm.prank(receiver);
        cancelBid(101);

        bids = getBids();
        assertEq(bids.length, 0);
        inactiveBids = testFacet.currentInactiveBids(asset);
        assertEq(inactiveBids.length, 2);
        assertEq(inactiveBids[0].id, 101);
        assertEq(inactiveBids[0].price, 3 ether);
        assertEq(inactiveBids[0].orderType, O.Cancelled);
        assertEq(inactiveBids[1].id, 100);
        assertEq(inactiveBids[1].price, 4 ether);
        assertEq(inactiveBids[1].orderType, O.Cancelled);

        fundLimitBidOpt(4 ether, 1 ether, receiver);
        fundLimitBidOpt(3 ether, 1 ether, receiver);
        fundLimitBidOpt(2 ether, 1 ether, receiver);

        bids = getBids();
        assertEq(bids.length, 3);
        assertEq(bids[0].id, 101);
        assertEq(bids[0].price, 4 ether);
        assertEq(bids[1].id, 100);
        assertEq(bids[1].price, 3 ether);
        assertEq(bids[2].id, 102);
        assertEq(bids[2].price, 2 ether);

        vm.prank(receiver);
        cancelBid(102);

        bids = getBids();
        assertEq(bids.length, 2);
        assertEq(bids[0].id, 101);
        assertEq(bids[0].price, 4 ether);
        assertEq(bids[1].id, 100);
        assertEq(bids[1].price, 3 ether);
        inactiveBids = testFacet.currentInactiveBids(asset);
        assertEq(inactiveBids.length, 1);
        assertEq(inactiveBids[0].id, 102);
        assertEq(inactiveBids[0].price, 2 ether);
        assertEq(inactiveBids[0].orderType, O.Cancelled);

        vm.prank(receiver);
        cancelBid(101);

        bids = getBids();
        assertEq(bids.length, 1);
        assertEq(bids[0].id, 100);
        assertEq(bids[0].price, 3 ether);
        inactiveBids = testFacet.currentInactiveBids(asset);
        assertEq(inactiveBids.length, 2);
        assertEq(inactiveBids[0].id, 101);
        assertEq(inactiveBids[0].price, 4 ether);
        assertEq(inactiveBids[0].orderType, O.Cancelled);
        assertEq(inactiveBids[1].id, 102);
        assertEq(inactiveBids[1].price, 2 ether);
        assertEq(inactiveBids[1].orderType, O.Cancelled);

        vm.prank(receiver);
        cancelBid(100);

        bids = getBids();
        assertEq(bids.length, 0);
        inactiveBids = testFacet.currentInactiveBids(asset);
        assertEq(inactiveBids.length, 3);
        assertEq(inactiveBids[0].id, 100);
        assertEq(inactiveBids[0].price, 3 ether);
        assertEq(inactiveBids[0].orderType, O.Cancelled);
        assertEq(inactiveBids[1].id, 101);
        assertEq(inactiveBids[1].price, 4 ether);
        assertEq(inactiveBids[1].orderType, O.Cancelled);
        assertEq(inactiveBids[2].id, 102);
        assertEq(inactiveBids[2].price, 2 ether);
        assertEq(inactiveBids[2].orderType, O.Cancelled);

        fundLimitBidOpt(4 ether, 1 ether, receiver);
        fundLimitBidOpt(3 ether, 1 ether, receiver);
        fundLimitBidOpt(2 ether, 1 ether, receiver);
        fundLimitBidOpt(1 ether, 1 ether, receiver);

        bids = getBids();
        assertEq(bids.length, 4);
        assertEq(bids[0].id, 100);
        assertEq(bids[0].price, 4 ether);
        assertEq(bids[1].id, 101);
        assertEq(bids[1].price, 3 ether);
        assertEq(bids[2].id, 102);
        assertEq(bids[2].price, 2 ether);
        assertEq(bids[3].id, 103);
        assertEq(bids[3].price, 1 ether);
    }

    function testOrderIdAsks() public {
        assertEq(diamond.getAssetStruct(asset).orderId, 100);
        fundLimitAskOpt(4 ether, 1 ether, receiver);
        assertEq(diamond.getAssetStruct(asset).orderId, 101);

        vm.prank(receiver);
        cancelAsk(100);
        assertEq(diamond.getAssetStruct(asset).orderId, 101);

        fundLimitAskOpt(4 ether, 1 ether, receiver);
        assertEq(diamond.getAssetStruct(asset).orderId, 101);

        fundLimitAskOpt(3 ether, 1 ether, receiver);
        assertEq(diamond.getAssetStruct(asset).orderId, 102);

        vm.prank(receiver);
        cancelAsk(100);
        assertEq(diamond.getAssetStruct(asset).orderId, 102);

        vm.prank(receiver);
        cancelAsk(101);
        assertEq(diamond.getAssetStruct(asset).orderId, 102);

        fundLimitAskOpt(4 ether, 1 ether, receiver);
        assertEq(diamond.getAssetStruct(asset).orderId, 102);
        fundLimitAskOpt(3 ether, 1 ether, receiver);
        assertEq(diamond.getAssetStruct(asset).orderId, 102);
        fundLimitAskOpt(2 ether, 1 ether, receiver);
        assertEq(diamond.getAssetStruct(asset).orderId, 103);
    }

    function testCancelInactiveAskOrders() public {
        assertEq(diamond.getAssetStruct(asset).orderId, 100);

        fundLimitAskOpt(4 ether, 1 ether, receiver); // 100

        STypes.Order[] memory asks = getAsks();
        assertEq(asks.length, 1);
        assertEq(asks[0].id, 100);
        assertEq(asks[0].price, 4 ether);
        STypes.Order[] memory inactiveAsks = testFacet.currentInactiveAsks(asset);
        assertEq(inactiveAsks.length, 0);

        vm.prank(receiver);
        cancelAsk(100);

        asks = getAsks();
        assertEq(asks.length, 0);
        inactiveAsks = testFacet.currentInactiveAsks(asset);
        assertEq(inactiveAsks.length, 1);
        assertEq(inactiveAsks[0].id, 100);
        assertEq(inactiveAsks[0].price, 4 ether);
        assertEq(inactiveAsks[0].orderType, O.Cancelled);

        fundLimitAskOpt(4 ether, 1 ether, receiver); // 100
        fundLimitAskOpt(3 ether, 1 ether, receiver); // 101

        asks = getAsks();
        assertEq(asks.length, 2);
        assertEq(asks[0].id, 101);
        assertEq(asks[0].price, 3 ether);
        assertEq(asks[1].id, 100);
        assertEq(asks[1].price, 4 ether);
        inactiveAsks = testFacet.currentInactiveAsks(asset);
        assertEq(inactiveAsks.length, 0);

        vm.prank(receiver);
        cancelAsk(100);

        asks = getAsks();
        assertEq(asks.length, 1);
        assertEq(asks[0].id, 101);
        assertEq(asks[0].price, 3 ether);
        inactiveAsks = testFacet.currentInactiveAsks(asset);
        assertEq(inactiveAsks.length, 1);
        assertEq(inactiveAsks[0].id, 100);
        assertEq(inactiveAsks[0].price, 4 ether);
        assertEq(inactiveAsks[0].orderType, O.Cancelled);

        vm.prank(receiver);
        cancelAsk(101);

        asks = getAsks();
        assertEq(asks.length, 0);
        inactiveAsks = testFacet.currentInactiveAsks(asset);
        assertEq(inactiveAsks.length, 2);
        assertEq(inactiveAsks[0].id, 101);
        assertEq(inactiveAsks[0].price, 3 ether);
        assertEq(inactiveAsks[0].orderType, O.Cancelled);
        assertEq(inactiveAsks[1].id, 100);
        assertEq(inactiveAsks[1].price, 4 ether);
        assertEq(inactiveAsks[1].orderType, O.Cancelled);

        fundLimitAskOpt(4 ether, 1 ether, receiver); // 101
        fundLimitAskOpt(3 ether, 1 ether, receiver); // 100
        fundLimitAskOpt(2 ether, 1 ether, receiver); // 102

        asks = getAsks();
        assertEq(asks.length, 3);

        assertEq(asks[0].id, 102);
        assertEq(asks[0].price, 2 ether);
        assertEq(asks[1].id, 100);
        assertEq(asks[1].price, 3 ether);
        assertEq(asks[2].id, 101);
        assertEq(asks[2].price, 4 ether);

        vm.prank(receiver);
        cancelAsk(102);

        asks = getAsks();
        assertEq(asks.length, 2);
        assertEq(asks[0].id, 100);
        assertEq(asks[0].price, 3 ether);
        assertEq(asks[1].id, 101);
        assertEq(asks[1].price, 4 ether);
        inactiveAsks = testFacet.currentInactiveAsks(asset);
        assertEq(inactiveAsks.length, 1);
        assertEq(inactiveAsks[0].id, 102);
        assertEq(inactiveAsks[0].price, 2 ether);
        assertEq(inactiveAsks[0].orderType, O.Cancelled);

        vm.prank(receiver);
        cancelAsk(101);

        asks = getAsks();
        assertEq(asks.length, 1);
        assertEq(asks[0].id, 100);
        assertEq(asks[0].price, 3 ether);
        inactiveAsks = testFacet.currentInactiveAsks(asset);
        assertEq(inactiveAsks.length, 2);
        assertEq(inactiveAsks[0].id, 101);
        assertEq(inactiveAsks[0].price, 4 ether);
        assertEq(inactiveAsks[0].orderType, O.Cancelled);
        assertEq(inactiveAsks[1].id, 102);
        assertEq(inactiveAsks[1].price, 2 ether);
        assertEq(inactiveAsks[1].orderType, O.Cancelled);

        vm.prank(receiver);
        cancelAsk(100);

        asks = getAsks();
        assertEq(asks.length, 0);
        inactiveAsks = testFacet.currentInactiveAsks(asset);
        assertEq(inactiveAsks.length, 3);
        assertEq(inactiveAsks[0].id, 100);
        assertEq(inactiveAsks[0].price, 3 ether);
        assertEq(inactiveAsks[0].orderType, O.Cancelled);
        assertEq(inactiveAsks[1].id, 101);
        assertEq(inactiveAsks[1].price, 4 ether);
        assertEq(inactiveAsks[1].orderType, O.Cancelled);
        assertEq(inactiveAsks[2].id, 102);
        assertEq(inactiveAsks[2].price, 2 ether);
        assertEq(inactiveAsks[2].orderType, O.Cancelled);

        fundLimitAskOpt(4 ether, 1 ether, receiver);
        fundLimitAskOpt(3 ether, 1 ether, receiver);
        fundLimitAskOpt(2 ether, 1 ether, receiver);
        fundLimitAskOpt(1 ether, 1 ether, receiver);

        asks = getAsks();
        assertEq(asks.length, 4);

        assertEq(asks[0].id, 103);
        assertEq(asks[0].price, 1 ether);
        assertEq(asks[1].id, 102);
        assertEq(asks[1].price, 2 ether);
        assertEq(asks[2].id, 101);
        assertEq(asks[2].price, 3 ether);
        assertEq(asks[3].id, 100);
        assertEq(asks[3].price, 4 ether);
    }
}
