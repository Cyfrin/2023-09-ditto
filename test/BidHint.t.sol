// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U80} from "contracts/libraries/PRBMathHelper.sol";

import {Errors} from "contracts/libraries/Errors.sol";
import {Events} from "contracts/libraries/Events.sol";
import {STypes, MTypes, O} from "contracts/libraries/DataTypes.sol";
import {Constants} from "contracts/libraries/Constants.sol";

import {OBFixture} from "test/utils/OBFixture.sol";
// import {console} from "contracts/libraries/console.sol";

contract BidOrdersSortingTest is OBFixture {
    uint256 private startGas;
    uint256 private gasUsed;
    uint256 private gasUsedOptimized;

    using U256 for uint256;
    using U80 for uint80;

    function setUp() public override {
        super.setUp();
        shortHintArrayStorage = setShortHintArray();
    }

    function addBidOrdersForTesting(uint256 numOrders) public {
        depositEth(receiver, 200 ether);
        MTypes.OrderHint[] memory orderHintArray;
        for (uint256 i = 0; i < numOrders; i++) {
            fundLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        }

        vm.startPrank(receiver);
        startGas = gasleft();
        diamond.createBid(
            asset,
            LOWER_PRICE,
            DEFAULT_AMOUNT,
            Constants.LIMIT_ORDER,
            badOrderHintArray,
            shortHintArrayStorage
        );
        gasUsed = startGas - gasleft();

        // optimized
        orderHintArray = diamond.getHintArray(asset, LOWER_PRICE, O.LimitBid);
        startGas = gasleft();
        diamond.createBid(
            asset,
            LOWER_PRICE,
            DEFAULT_AMOUNT,
            Constants.LIMIT_ORDER,
            orderHintArray,
            shortHintArrayStorage
        );
        gasUsedOptimized = startGas - gasleft();
        vm.stopPrank();
    }

    function testOptGasAddingBidNumOrders2() public {
        uint256 numOrders = 2;
        addBidOrdersForTesting(numOrders);
        assertGt(gasUsed, gasUsedOptimized, "optGas2");
    }

    function testOptGasAddingBidNumOrders25() public {
        uint256 numOrders = 25;
        addBidOrdersForTesting(numOrders);
        assertGt(gasUsed, gasUsedOptimized, "optGas25");
    }

    //HINT!
    function fundHint() public {
        fundLimitBidOpt(DEFAULT_PRICE + 10 wei, DEFAULT_AMOUNT, receiver); //100
        fundLimitBidOpt(DEFAULT_PRICE + 5 wei, DEFAULT_AMOUNT, receiver); //101
        fundLimitBidOpt(DEFAULT_PRICE + 3 wei, DEFAULT_AMOUNT, receiver); //102
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); //103
    }

    function assertEqHint(STypes.Order[] memory bids) public {
        assertEq(bids[0].id, 100);
        assertEq(bids[1].id, 101);
        assertEq(bids[2].id, 104);
        assertEq(bids[3].id, 102);
        assertEq(bids[4].id, 103);

        assertEq(bids[0].price, DEFAULT_PRICE + 10 wei);
        assertEq(bids[1].price, DEFAULT_PRICE + 5 wei);
        assertEq(bids[2].price, DEFAULT_PRICE + 4 wei);
        assertEq(bids[3].price, DEFAULT_PRICE + 3 wei);
        assertEq(bids[4].price, DEFAULT_PRICE);
    }

    function testWithoutHint() public {
        fundHint();
        fundLimitBidOpt(DEFAULT_PRICE + 4 wei, DEFAULT_AMOUNT, receiver);
        assertEqHint(getBids());
    }

    function testHintMoveFowardBid1() public {
        fundHint();
        fundLimitBidOpt(DEFAULT_PRICE + 4 wei, DEFAULT_AMOUNT, receiver);
        assertEqHint(getBids());
    }

    function testHintExactMatchBid() public {
        fundHint();
        fundLimitBidOpt(DEFAULT_PRICE + 4 wei, DEFAULT_AMOUNT, receiver);
        assertEqHint(getBids());
    }

    function testHintMoveBackBid1() public {
        fundHint();
        fundLimitBidOpt(DEFAULT_PRICE + 4 wei, DEFAULT_AMOUNT, receiver);
        assertEqHint(getBids());
    }

    function testHintMoveBackBid2() public {
        fundHint();
        fundLimitBidOpt(DEFAULT_PRICE + 4 wei, DEFAULT_AMOUNT, receiver);
        assertEqHint(getBids());
    }

    function testHintMoveBackBid3() public {
        fundHint();
        fundLimitBidOpt(DEFAULT_PRICE + 4 wei, DEFAULT_AMOUNT, receiver);
        assertEqHint(getBids());
    }

    function testHintBid() public {
        fundHint();
        fundLimitBidOpt(DEFAULT_PRICE + 4, DEFAULT_AMOUNT, receiver);
        assertEqHint(getBids());
    }

    //PrevId/NextId
    function testProperIDSettingBid() public {
        uint16 numOrders = 10;

        for (uint80 i = 1; i <= numOrders; i++) {
            fundLimitBidOpt(DEFAULT_PRICE + i, i * DEFAULT_AMOUNT, receiver);
        }

        STypes.Order[] memory bids = getBids();
        uint16 _id = Constants.HEAD;
        (uint16 prevId, uint16 nextId) = testFacet.getBidKey(asset, _id);
        uint256 index = 0;
        while (index <= bids.length) {
            (, _id) = testFacet.getBidKey(asset, _id);
            (prevId, nextId) = testFacet.getBidKey(asset, _id);
            if (
                prevId != Constants.HEAD && prevId != Constants.TAIL
                    && _id != Constants.HEAD && _id != Constants.TAIL
            ) {
                assertTrue(prevId > nextId);
            }
            index++;
        }
    }

    // order Hint Array
    function createBidsInMarket() public {
        //create some bids
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(DEFAULT_PRICE * 2, DEFAULT_AMOUNT, receiver);
        assertEq(getBids()[0].id, 103);
        depositEthAndPrank(receiver, DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT));
    }

    function revertOnBadHintIdArray() public {
        vm.expectRevert(Errors.BadHintIdArray.selector);
        diamond.createBid(
            asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT,
            Constants.LIMIT_ORDER,
            badOrderHintArray,
            shortHintArrayStorage
        );
    }

    function testRevertBadHintIdArrayBid() public {
        createBidsInMarket();
        revertOnBadHintIdArray();
    }

    function testFindProperBidHintId() public {
        createBidsInMarket();
        revertOnBadHintIdArray();

        //@dev get the right hint
        MTypes.OrderHint[] memory orderHintArray =
            diamond.getHintArray(asset, DEFAULT_PRICE, O.LimitBid);
        vm.prank(receiver);
        vm.expectEmit(_diamond);
        emit Events.FindOrderHintId(1);
        diamond.createBid(
            asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT,
            Constants.LIMIT_ORDER,
            orderHintArray,
            shortHintArrayStorage
        );

        assertEq(getBids()[4].id, 104);
    }

    //@dev Had errors in front end. Trying to see if error is with contract or front end by replicating front end actions
    function testFrontEndReplication(uint80 fuzz_price) public {
        vm.assume(fuzz_price > diamond.getAssetNormalizedStruct(asset).minBidEth);
        vm.assume(fuzz_price < 1 ether);

        depositEth(receiver, 1000000 ether);
        vm.startPrank(receiver);

        for (uint256 i = 0; i < 10; i++) {
            diamond.createBid(
                asset,
                fuzz_price,
                DEFAULT_AMOUNT,
                Constants.LIMIT_ORDER,
                diamond.getHintArray(asset, fuzz_price, O.LimitBid),
                shortHintArrayStorage
            );
        }
    }

    function testAddBestBidNotUsingOrderHint() public {
        createBidsInMarket();
        vm.stopPrank();
        fundLimitBidOpt(DEFAULT_PRICE * 3, DEFAULT_AMOUNT, receiver);
        assertEq(getBids().length, 5);
        assertEq(getBids()[0].id, 104);
        assertEq(getBids()[1].id, 103);
        assertEq(getBids()[2].id, 100);
    }

    //testing when creationTime is different
    function createMatchAndReuseFirstBid()
        public
        returns (MTypes.OrderHint[] memory orderHintArray)
    {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        orderHintArray = diamond.getHintArray(asset, DEFAULT_PRICE, O.LimitBid);
        assertEq(orderHintArray[0].hintId, 100);
        assertEq(orderHintArray[0].creationTime, 1 seconds);

        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        skip(1 seconds);

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        orderHintArray = new MTypes.OrderHint[](1);
        orderHintArray[0] = MTypes.OrderHint({hintId: 100, creationTime: 123});

        return orderHintArray;
    }

    function testAddBidReusedMatched() public {
        MTypes.OrderHint[] memory orderHintArray = createMatchAndReuseFirstBid();

        //create bid with outdated hint array
        depositEthAndPrank(receiver, DEFAULT_PRICE.mulU80(DEFAULT_AMOUNT));
        vm.expectEmit(_diamond);
        emit Events.FindOrderHintId(2);
        diamond.createBid(
            asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT,
            Constants.LIMIT_ORDER,
            orderHintArray,
            shortHintArrayStorage
        );
    }

    //@dev pass in a hint that needs to move backwards on linked list
    function testGetOrderIdDirectionPrevBid() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(DEFAULT_PRICE + 1 wei, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(DEFAULT_PRICE + 2 wei, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(DEFAULT_PRICE + 3 wei, DEFAULT_AMOUNT, receiver);

        MTypes.OrderHint[] memory orderHintArray = new MTypes.OrderHint[](1);
        orderHintArray[0] = MTypes.OrderHint({hintId: 100, creationTime: 1});

        depositEthAndPrank(receiver, (DEFAULT_PRICE + 3 wei).mulU88(DEFAULT_AMOUNT));

        diamond.createBid(
            asset,
            DEFAULT_PRICE + 3 wei,
            DEFAULT_AMOUNT,
            Constants.LIMIT_ORDER,
            orderHintArray,
            shortHintArrayStorage
        );
    }

    //@dev what happens if we pass in a hintId of a matached order?
    function testRevertFindOrderHintIdMatchedHint() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        MTypes.OrderHint[] memory orderHintArray = new MTypes.OrderHint[](1);
        orderHintArray[0] = MTypes.OrderHint({hintId: 100, creationTime: 1});

        depositEthAndPrank(receiver, DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT));
        vm.expectRevert(Errors.BadHintIdArray.selector);
        diamond.createBid(
            asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT,
            Constants.LIMIT_ORDER,
            orderHintArray,
            shortHintArrayStorage
        );
    }

    //@dev what happens if we pass in a hintId of a cancelled order?
    function testRevertFindOrderHintIdCancelledHint() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        vm.prank(receiver);
        cancelBid(100);

        MTypes.OrderHint[] memory orderHintArray = new MTypes.OrderHint[](1);
        orderHintArray[0] = MTypes.OrderHint({hintId: 100, creationTime: 1});

        depositEthAndPrank(receiver, DEFAULT_PRICE);
        vm.expectRevert(Errors.BadHintIdArray.selector);
        diamond.createBid(
            asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT,
            Constants.LIMIT_ORDER,
            orderHintArray,
            shortHintArrayStorage
        );
    }
}
