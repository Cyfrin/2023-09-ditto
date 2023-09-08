// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {Errors} from "contracts/libraries/Errors.sol";
import {Events} from "contracts/libraries/Events.sol";
import {STypes, MTypes, O} from "contracts/libraries/DataTypes.sol";
import {Constants} from "contracts/libraries/Constants.sol";

import {OBFixture} from "test/utils/OBFixture.sol";
// import {console} from "contracts/libraries/console.sol";

contract AskHintTest is OBFixture {
    uint256 private startGas;
    uint256 private gasUsed;
    uint256 private gasUsedOptimized;

    bool private constant ASK = true;
    bool private constant SHORT = false;

    //@dev AskHintTest is testing both ask and shorts
    function setUp() public override {
        super.setUp();
    }

    function currentOrders(O orderType)
        public
        view
        returns (STypes.Order[] memory orders)
    {
        if (orderType == O.LimitBid) {
            return getBids();
        } else if (orderType == O.LimitAsk) {
            return getAsks();
        } else if (orderType == O.LimitShort) {
            return getShorts();
        } else {
            revert("Invalid OrderType");
        }
    }

    ///////////Testing gas for optimized orders < non-optimized
    function addAskOrdersForTesting(bool askType, uint256 numOrders) public {
        depositEth(receiver, 1000000 ether);
        depositUsd(receiver, 1000000 ether);
        vm.startPrank(receiver);

        MTypes.OrderHint[] memory orderHintArray;

        //fill up market
        for (uint256 i = 0; i < numOrders; i++) {
            if (askType == SHORT) {
                orderHintArray =
                    diamond.getHintArray(asset, DEFAULT_AMOUNT * 5, O.LimitShort);
                diamond.createLimitShort(
                    asset,
                    DEFAULT_PRICE * 5,
                    DEFAULT_AMOUNT * 5,
                    orderHintArray,
                    shortHintArrayStorage,
                    initialMargin
                );
            } else {
                orderHintArray =
                    diamond.getHintArray(asset, DEFAULT_AMOUNT * 5, O.LimitAsk);
                diamond.createAsk(
                    asset,
                    DEFAULT_PRICE * 5,
                    DEFAULT_AMOUNT * 5,
                    Constants.LIMIT_ORDER,
                    orderHintArray
                );
            }
        }

        //add one more order (non optimized)
        if (askType == SHORT) {
            orderHintArray = diamond.getHintArray(asset, DEFAULT_AMOUNT * 6, O.LimitShort);
            startGas = gasleft();
            diamond.createLimitShort(
                asset,
                DEFAULT_PRICE * 6,
                DEFAULT_AMOUNT * 6,
                orderHintArray,
                shortHintArrayStorage,
                initialMargin
            );
        } else {
            orderHintArray = diamond.getHintArray(asset, DEFAULT_AMOUNT * 6, O.LimitAsk);
            startGas = gasleft();
            diamond.createAsk(
                asset,
                DEFAULT_PRICE * 6,
                DEFAULT_AMOUNT * 6,
                Constants.LIMIT_ORDER,
                orderHintArray
            );
        }
        gasUsed = startGas - gasleft();
        // emit log_named_uint("gasUsed", gasUsed);

        //add one more order (optimized)
        if (askType == SHORT) {
            orderHintArray = diamond.getHintArray(asset, DEFAULT_AMOUNT * 6, O.LimitShort);
            startGas = gasleft();
            diamond.createLimitShort(
                asset,
                DEFAULT_PRICE * 6,
                DEFAULT_AMOUNT * 6,
                orderHintArray,
                shortHintArrayStorage,
                initialMargin
            );
        } else {
            orderHintArray = diamond.getHintArray(asset, DEFAULT_AMOUNT * 6, O.LimitAsk);
            startGas = gasleft();
            diamond.createAsk(
                asset,
                DEFAULT_PRICE * 6,
                DEFAULT_AMOUNT * 6,
                Constants.LIMIT_ORDER,
                orderHintArray
            );
        }
        gasUsedOptimized = startGas - gasleft();
        // emit log_named_uint("gasUsedOptimized", gasUsedOptimized);
        vm.stopPrank();
    }

    function testOptGasAddingShortNumOrders2() public {
        uint256 numOrders = 2;
        addAskOrdersForTesting(SHORT, numOrders);
        assertGt(gasUsed, gasUsedOptimized);
    }

    function testOptGasAddingShortNumOrders25() public {
        uint256 numOrders = 25;
        addAskOrdersForTesting(SHORT, numOrders);
        assertGt(gasUsed, gasUsedOptimized);
    }

    function testOptGasAddingSellNumOrders2() public {
        uint256 numOrders = 2;
        addAskOrdersForTesting(ASK, numOrders);
        assertGt(gasUsed, gasUsedOptimized);
    }

    function testOptGasAddingSellNumOrders25() public {
        uint256 numOrders = 25;
        addAskOrdersForTesting(ASK, numOrders);
        assertGt(gasUsed, gasUsedOptimized);
    }

    //HINT!
    function fundHint() public {
        fundOrder(O.LimitAsk, DEFAULT_PRICE, DEFAULT_AMOUNT, sender); //100
        fundOrder(O.LimitAsk, DEFAULT_PRICE + 3 wei, DEFAULT_AMOUNT, sender); //101
        fundOrder(O.LimitAsk, DEFAULT_PRICE + 5 wei, DEFAULT_AMOUNT, sender); //102
        fundOrder(O.LimitAsk, DEFAULT_PRICE + 10 wei, DEFAULT_AMOUNT, sender); //103
    }

    function assertEqHint(STypes.Order[] memory asks) public {
        assertEq(asks[0].id, 100);
        assertEq(asks[1].id, 101);
        assertEq(asks[2].id, 104);
        assertEq(asks[3].id, 102);
        assertEq(asks[4].id, 103);

        assertEq(asks[0].price, DEFAULT_PRICE);
        assertEq(asks[1].price, DEFAULT_PRICE + 3 wei);
        assertEq(asks[2].price, DEFAULT_PRICE + 4 wei);
        assertEq(asks[3].price, DEFAULT_PRICE + 5 wei);
        assertEq(asks[4].price, DEFAULT_PRICE + 10 wei);
    }

    function testHintMoveBackAsk1() public {
        fundHint();
        fundLimitAskOpt(DEFAULT_PRICE + 4 wei, DEFAULT_AMOUNT, sender);
        assertEqHint(currentOrders(O.LimitAsk));
    }

    function testHintMoveBackAsk2() public {
        fundHint();
        fundLimitAskOpt(DEFAULT_PRICE + 4 wei, DEFAULT_AMOUNT, sender);
        assertEqHint(currentOrders(O.LimitAsk));
    }

    function testHintMoveForwardAsk1() public {
        fundHint();
        fundLimitAskOpt(DEFAULT_PRICE + 4 wei, DEFAULT_AMOUNT, sender);
        assertEqHint(currentOrders(O.LimitAsk));
    }

    function testHintExactMatchAsk() public {
        fundHint();
        fundLimitAskOpt(DEFAULT_PRICE + 4 wei, DEFAULT_AMOUNT, sender);
        assertEqHint(currentOrders(O.LimitAsk));
    }

    function testHintAsk() public {
        fundHint();
        fundLimitAskOpt(DEFAULT_PRICE + 4, DEFAULT_AMOUNT, sender);
        assertEqHint(currentOrders(O.LimitAsk));
    }

    //PrevId/NextId
    function testProperIDSettingAsk() public {
        uint16 numOrders = 10;
        for (uint16 i = 1; i <= numOrders; i++) {
            fundLimitAskOpt(DEFAULT_PRICE + i, i * DEFAULT_AMOUNT, receiver);
        }

        uint16 _id = Constants.HEAD;
        (uint16 prevId, uint16 nextId) = testFacet.getAskKey(asset, _id);
        uint256 index = 0;
        STypes.Order[] memory asks = getAsks();

        while (index <= asks.length) {
            (, _id) = testFacet.getAskKey(asset, _id);
            (prevId, nextId) = testFacet.getAskKey(asset, _id);
            if (
                (_id != Constants.HEAD && _id != Constants.TAIL)
                    && (nextId != Constants.HEAD && nextId != Constants.TAIL)
            ) {
                // testFacet.logAsks(asset);
                assertTrue(prevId < nextId);
            }
            index++;
        }
    }

    function testProperIDSettingAskForLoop() public {
        //NOTE: This test is good for logging
        // uint256 Constants.HEAD = 1;
        uint80 numOrders = 50;

        //creating asks
        for (uint80 i = 1; i <= numOrders; i++) {
            fundLimitAskOpt(DEFAULT_PRICE + i, i * DEFAULT_AMOUNT, receiver);
        }
        for (uint80 i = numOrders; i > 0; i--) {
            fundLimitAskOpt(DEFAULT_PRICE + i, i * DEFAULT_AMOUNT, receiver);
        }

        checkOrdersPriceValidity();
    }

    // order Hint Array
    function createSellsInMarket(bool sellType) public {
        if (sellType == ASK) {
            fundLimitAskOpt(DEFAULT_PRICE * 2, DEFAULT_AMOUNT, receiver);
            fundLimitAskOpt(DEFAULT_PRICE * 2, DEFAULT_AMOUNT, receiver);
            fundLimitAskOpt(DEFAULT_PRICE * 2, DEFAULT_AMOUNT, receiver);
            fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
            assertEq(getAsks()[0].id, 103);
            depositUsdAndPrank(receiver, DEFAULT_AMOUNT);
        } else {
            fundLimitShortOpt(DEFAULT_PRICE * 2, DEFAULT_AMOUNT, receiver);
            fundLimitShortOpt(DEFAULT_PRICE * 2, DEFAULT_AMOUNT, receiver);
            fundLimitShortOpt(DEFAULT_PRICE * 2, DEFAULT_AMOUNT, receiver);
            fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
            assertEq(getShorts()[0].id, 103);
            //@dev arbitrary amt
            depositEthAndPrank(receiver, DEFAULT_AMOUNT * 10);
        }
    }

    function revertOnBadHintIdArray(bool sellType) public {
        vm.expectRevert(Errors.BadHintIdArray.selector);
        if (sellType == ASK) {
            diamond.createAsk(
                asset,
                DEFAULT_PRICE * 2,
                DEFAULT_AMOUNT,
                Constants.LIMIT_ORDER,
                badOrderHintArray
            );
            // orderHintArray
        } else {
            diamond.createLimitShort(
                asset,
                DEFAULT_PRICE * 2,
                DEFAULT_AMOUNT,
                badOrderHintArray,
                shortHintArrayStorage,
                initialMargin
            );
        }
    }

    function testRevertBadHintIdArrayAsk() public {
        createSellsInMarket({sellType: ASK});
        revertOnBadHintIdArray({sellType: ASK});
    }

    function testFindProperAskHintId() public {
        createSellsInMarket({sellType: ASK});
        revertOnBadHintIdArray({sellType: ASK});
        fundLimitAskOpt(DEFAULT_PRICE * 2, DEFAULT_AMOUNT, receiver);
    }

    function testRevertBadHintIdArrayShort() public {
        createSellsInMarket({sellType: SHORT});
        revertOnBadHintIdArray({sellType: SHORT});
    }

    function testFindProperShortHintId() public {
        createSellsInMarket({sellType: SHORT});
        revertOnBadHintIdArray({sellType: SHORT});

        MTypes.OrderHint[] memory orderHintArray =
            diamond.getHintArray(asset, DEFAULT_PRICE * 2, O.LimitShort);

        vm.prank(receiver);
        diamond.createLimitShort(
            asset,
            DEFAULT_PRICE * 2,
            DEFAULT_AMOUNT,
            orderHintArray,
            shortHintArrayStorage,
            initialMargin
        );
    }

    function testGetAskHintArray() public {
        createSellsInMarket({sellType: ASK});

        MTypes.OrderHint[] memory orderHintArray =
            diamond.getHintArray(asset, DEFAULT_PRICE, O.LimitAsk);

        vm.prank(receiver);
        vm.expectEmit(_diamond);
        emit Events.FindOrderHintId(1);
        diamond.createAsk(
            asset, DEFAULT_PRICE, DEFAULT_AMOUNT, Constants.LIMIT_ORDER, orderHintArray
        );
        assertEq(getAsks()[1].id, 104);
    }

    function testGetShortHintArray() public {
        createSellsInMarket({sellType: SHORT});

        MTypes.OrderHint[] memory orderHintArray =
            diamond.getHintArray(asset, DEFAULT_PRICE, O.LimitShort);

        vm.prank(receiver);
        vm.expectEmit(_diamond);
        emit Events.FindOrderHintId(1);
        diamond.createLimitShort(
            asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT,
            orderHintArray,
            shortHintArrayStorage,
            initialMargin
        );
        assertEq(getShorts()[1].id, 104);
    }

    function testAddBestAskNotUsingOrderHint() public {
        createSellsInMarket({sellType: ASK});
        vm.stopPrank();
        fundLimitAskOpt(DEFAULT_PRICE - 1 wei, DEFAULT_AMOUNT, receiver);
        assertEq(getAsks().length, 5);
        assertEq(getAsks()[0].id, 104);
        assertEq(getAsks()[1].id, 103);
        assertEq(getAsks()[2].id, 100);
    }

    function testAddBestShortNotUsingOrderHint() public {
        createSellsInMarket({sellType: SHORT});
        vm.stopPrank();
        fundLimitShortOpt(DEFAULT_PRICE - 1 wei, DEFAULT_AMOUNT, receiver);
        assertEq(getShorts().length, 5);
        assertEq(getShorts()[0].id, 104);
        assertEq(getShorts()[1].id, 103);
        assertEq(getShorts()[2].id, 100);
    }

    //testing when creationTime is different
    function createMatchAndReuseFirstSell(bool sellType)
        public
        returns (MTypes.OrderHint[] memory orderHintArray)
    {
        if (sellType == ASK) {
            fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
            orderHintArray = diamond.getHintArray(asset, DEFAULT_PRICE, O.LimitAsk);
        } else if (sellType == SHORT) {
            fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
            orderHintArray = diamond.getHintArray(asset, DEFAULT_PRICE, O.LimitShort);
        }

        assertEq(orderHintArray[0].hintId, 100);
        assertEq(orderHintArray[0].creationTime, 1 seconds);

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        skip(1 seconds);

        if (sellType == ASK) {
            fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        } else if (sellType == SHORT) {
            fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        }
        orderHintArray = new MTypes.OrderHint[](1);
        orderHintArray[0] = MTypes.OrderHint({hintId: 100, creationTime: 123});

        return orderHintArray;
    }

    function testAddAskReusedMatched() public {
        MTypes.OrderHint[] memory orderHintArray =
            createMatchAndReuseFirstSell({sellType: ASK});

        //create ask with outdated hint array
        depositUsdAndPrank(sender, DEFAULT_AMOUNT);
        vm.expectEmit(_diamond);
        emit Events.FindOrderHintId(2);
        diamond.createAsk(
            asset, DEFAULT_PRICE, DEFAULT_AMOUNT, Constants.LIMIT_ORDER, orderHintArray
        );
    }

    function testAddShortReusedMatched() public {
        MTypes.OrderHint[] memory orderHintArray =
            createMatchAndReuseFirstSell({sellType: SHORT});

        //create short with outdated hint array
        depositEthAndPrank(sender, 10 ether);
        vm.expectEmit(_diamond);
        emit Events.FindOrderHintId(2);
        diamond.createLimitShort(
            asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT,
            orderHintArray,
            shortHintArrayStorage,
            initialMargin
        );
    }

    //@dev pass in a hint that needs to move backwards on linked list
    function testGetOrderIdDirectionPrevAsk() public {
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitAskOpt(DEFAULT_PRICE + 1 wei, DEFAULT_AMOUNT, sender);
        fundLimitAskOpt(DEFAULT_PRICE + 2 wei, DEFAULT_AMOUNT, sender);
        fundLimitAskOpt(DEFAULT_PRICE + 3 wei, DEFAULT_AMOUNT, sender);

        MTypes.OrderHint[] memory orderHintArray = new MTypes.OrderHint[](1);
        orderHintArray[0] = MTypes.OrderHint({hintId: 103, creationTime: 1});

        depositUsdAndPrank(sender, DEFAULT_AMOUNT);
        diamond.createAsk(
            asset, DEFAULT_PRICE, DEFAULT_AMOUNT, Constants.LIMIT_ORDER, orderHintArray
        );
    }

    function testGetOrderIdDirectionPrevShort() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitShortOpt(DEFAULT_PRICE + 1 wei, DEFAULT_AMOUNT, sender);
        fundLimitShortOpt(DEFAULT_PRICE + 2 wei, DEFAULT_AMOUNT, sender);
        fundLimitShortOpt(DEFAULT_PRICE + 3 wei, DEFAULT_AMOUNT, sender);

        MTypes.OrderHint[] memory orderHintArray = new MTypes.OrderHint[](1);
        orderHintArray[0] = MTypes.OrderHint({hintId: 103, creationTime: 1});

        depositEthAndPrank(sender, 10 ether);
        diamond.createLimitShort(
            asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT,
            orderHintArray,
            shortHintArrayStorage,
            initialMargin
        );
    }
}
