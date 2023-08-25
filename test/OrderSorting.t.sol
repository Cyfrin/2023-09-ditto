// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U88} from "contracts/libraries/PRBMathHelper.sol";
import {STypes, O} from "contracts/libraries/DataTypes.sol";

import {OBFixture} from "test/utils/OBFixture.sol";
// import {console} from "contracts/libraries/console.sol";

contract OrderSortingTest is OBFixture {
    using U88 for uint88;

    O[3] public types = [O.LimitBid, O.LimitAsk, O.LimitShort];

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

    // SCENARIOS:
    // First  Order: Default Price, Default Amount
    // Second Order:    High Price, Default Amount
    // ----
    // First  Order:    High Price, Default Amount
    // Second Order: Default Price, Default Amount
    // ----
    // First  Order: Default Price, High    Amount
    // Second Order: Default Price, Default Amount
    // ----
    // First  Order: Default Price, Default Amount
    // Second Order: Default Price, High    Amount

    function test_SortAsk_HigherPriceFirst() public {
        STypes.Order[] memory orders;
        fundOrder(O.LimitAsk, DEFAULT_PRICE + 1 wei, DEFAULT_AMOUNT, receiver);
        fundOrder(O.LimitAsk, DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        orders = currentOrders(O.LimitAsk);
        assertEq(orders[0].price, DEFAULT_PRICE);
        assertEq(orders[1].price, DEFAULT_PRICE + 1 wei);
    }

    function test_SortShort_HigherPriceFirst() public {
        STypes.Order[] memory orders;
        fundOrder(O.LimitShort, DEFAULT_PRICE + 1 wei, DEFAULT_AMOUNT, receiver);
        fundOrder(O.LimitShort, DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        orders = currentOrders(O.LimitShort);
        assertEq(orders[0].price, DEFAULT_PRICE);
        assertEq(orders[1].price, DEFAULT_PRICE + 1 wei);
    }

    function test_SortBid_HigherPriceFirst() public {
        STypes.Order[] memory orders;
        fundOrder(O.LimitBid, DEFAULT_PRICE + 1 wei, DEFAULT_AMOUNT, receiver);
        fundOrder(O.LimitBid, DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        orders = currentOrders(O.LimitBid);
        assertEq(orders[0].price, DEFAULT_PRICE + 1 wei);
        assertEq(orders[1].price, DEFAULT_PRICE);
    }

    function test_SortAsk_HigherPriceSecond() public {
        STypes.Order[] memory orders;
        fundOrder(O.LimitAsk, DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundOrder(O.LimitAsk, DEFAULT_PRICE + 1 wei, DEFAULT_AMOUNT, receiver);

        orders = currentOrders(O.LimitAsk);
        assertEq(orders[0].price, DEFAULT_PRICE);
        assertEq(orders[1].price, DEFAULT_PRICE + 1 wei);
    }

    function test_SortShort_HigherPriceSecond() public {
        STypes.Order[] memory orders;
        fundOrder(O.LimitShort, DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundOrder(O.LimitShort, DEFAULT_PRICE + 1 wei, DEFAULT_AMOUNT, receiver);

        orders = currentOrders(O.LimitShort);
        assertEq(orders[0].price, DEFAULT_PRICE);
        assertEq(orders[1].price, DEFAULT_PRICE + 1 wei);
    }

    function test_SortBid_HigherPriceSecond() public {
        STypes.Order[] memory orders;
        fundOrder(O.LimitBid, DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundOrder(O.LimitBid, DEFAULT_PRICE + 1 wei, DEFAULT_AMOUNT, receiver);

        orders = currentOrders(O.LimitBid);
        assertEq(orders[0].price, DEFAULT_PRICE + 1 wei);
        assertEq(orders[1].price, DEFAULT_PRICE);
    }

    function test_SortAsk_SamePrice_HigherAmountFirst() public {
        STypes.Order[] memory orders;
        fundOrder(O.LimitAsk, DEFAULT_PRICE, DEFAULT_AMOUNT + 2 wei, receiver);
        fundOrder(O.LimitAsk, DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        orders = currentOrders(O.LimitAsk);
        assertEq(orders[0].ercAmount, DEFAULT_AMOUNT + 2 wei);
        assertEq(orders[1].ercAmount, DEFAULT_AMOUNT);
    }

    function test_SortShortSamePrice_HigherAmountFirst() public {
        STypes.Order[] memory orders;
        fundOrder(O.LimitShort, DEFAULT_PRICE, DEFAULT_AMOUNT + 1 wei, receiver);
        fundOrder(O.LimitShort, DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        orders = currentOrders(O.LimitShort);
        assertEq(orders[0].ercAmount, DEFAULT_AMOUNT + 1 wei);
        assertEq(orders[1].ercAmount, DEFAULT_AMOUNT);
    }

    function test_SortBidSamePrice_HigherAmountFirst() public {
        STypes.Order[] memory orders;
        fundOrder(O.LimitBid, DEFAULT_PRICE, DEFAULT_AMOUNT + 1 wei, receiver);
        fundOrder(O.LimitBid, DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        orders = currentOrders(O.LimitBid);
        assertEq(orders[0].ercAmount, DEFAULT_AMOUNT + 1 wei);
        assertEq(orders[1].ercAmount, DEFAULT_AMOUNT);
    }

    function test_SortAsk_SamePrice_HigherAmountSecond() public {
        STypes.Order[] memory orders;
        fundOrder(O.LimitAsk, DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundOrder(O.LimitAsk, DEFAULT_PRICE, DEFAULT_AMOUNT + 2 wei, receiver);

        orders = currentOrders(O.LimitAsk);
        assertEq(orders[0].ercAmount, DEFAULT_AMOUNT);
        assertEq(orders[1].ercAmount, DEFAULT_AMOUNT + 2 wei);
    }

    function test_SortShortSamePrice_HigherAmountSecond() public {
        STypes.Order[] memory orders;
        fundOrder(O.LimitShort, DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundOrder(O.LimitShort, DEFAULT_PRICE, DEFAULT_AMOUNT + 1 wei, receiver);

        orders = currentOrders(O.LimitShort);
        assertEq(orders[0].ercAmount, DEFAULT_AMOUNT);
        assertEq(orders[1].ercAmount, DEFAULT_AMOUNT + 1 wei);
    }

    function test_SortBidSamePrice_HigherAmountSecond() public {
        STypes.Order[] memory orders;
        fundOrder(O.LimitBid, DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundOrder(O.LimitBid, DEFAULT_PRICE, DEFAULT_AMOUNT + 1 wei, receiver);

        orders = currentOrders(O.LimitBid);
        assertEq(orders[0].ercAmount, DEFAULT_AMOUNT);
        assertEq(orders[1].ercAmount, DEFAULT_AMOUNT + 1 wei);
    }

    function assertEqOrder(STypes.Order[] memory orders) public {
        assertEq(orders[0].price, 4 ether);
        assertEq(orders[1].price, 5 ether);
        assertEq(orders[2].price, 6 ether);
        assertEq(orders[3].price, 7 ether);
        assertEq(orders[4].price, 8 ether);
        assertEq(orders[5].price, 9 ether);

        assertEq(orders[0].ercAmount, DEFAULT_AMOUNT.mulU88(4 ether));
        assertEq(orders[1].ercAmount, DEFAULT_AMOUNT.mulU88(5 ether));
        assertEq(orders[2].ercAmount, DEFAULT_AMOUNT.mulU88(6 ether));
        assertEq(orders[3].ercAmount, DEFAULT_AMOUNT.mulU88(7 ether));
        assertEq(orders[4].ercAmount, DEFAULT_AMOUNT.mulU88(8 ether));
        assertEq(orders[5].ercAmount, DEFAULT_AMOUNT.mulU88(9 ether));
    }

    function test_SortShortOptimized() public {
        fundLimitShortOpt(5 ether, DEFAULT_AMOUNT.mulU88(5 ether), receiver);
        fundLimitShortOpt(6 ether, DEFAULT_AMOUNT.mulU88(6 ether), receiver);
        fundLimitShortOpt(7 ether, DEFAULT_AMOUNT.mulU88(7 ether), receiver);
        fundLimitShortOpt(4 ether, DEFAULT_AMOUNT.mulU88(4 ether), receiver);
        fundLimitShortOpt(8 ether, DEFAULT_AMOUNT.mulU88(8 ether), receiver);
        fundLimitShortOpt(9 ether, DEFAULT_AMOUNT.mulU88(9 ether), receiver);

        assertEqOrder(currentOrders(O.LimitShort));
    }

    function test_SortAskOptimized() public {
        fundLimitAskOpt(5 ether, DEFAULT_AMOUNT.mulU88(5 ether), receiver);
        fundLimitAskOpt(6 ether, DEFAULT_AMOUNT.mulU88(6 ether), receiver);
        fundLimitAskOpt(7 ether, DEFAULT_AMOUNT.mulU88(7 ether), receiver);
        fundLimitAskOpt(4 ether, DEFAULT_AMOUNT.mulU88(4 ether), receiver);
        fundLimitAskOpt(8 ether, DEFAULT_AMOUNT.mulU88(8 ether), receiver);
        fundLimitAskOpt(9 ether, DEFAULT_AMOUNT.mulU88(9 ether), receiver);

        assertEqOrder(currentOrders(O.LimitAsk));
    }

    function assertEqBids(STypes.Order[] memory _bids) public {
        assertEq(_bids[0].price, 6 ether);
        assertEq(_bids[1].price, 4 ether);
        assertEq(_bids[2].price, 4 ether);
        assertEq(_bids[3].price, 3 ether);
        assertEq(_bids[4].price, 2.5 ether);
        assertEq(_bids[5].price, 2 ether);
        assertEq(_bids[6].price, 1 ether);

        assertEq(_bids[0].ercAmount, DEFAULT_AMOUNT.mulU88(6 ether));
        assertEq(_bids[1].ercAmount, DEFAULT_AMOUNT.mulU88(4 ether));
        assertEq(_bids[2].ercAmount, DEFAULT_AMOUNT.mulU88(7 ether));
        assertEq(_bids[3].ercAmount, DEFAULT_AMOUNT.mulU88(3 ether));
        assertEq(_bids[4].ercAmount, DEFAULT_AMOUNT.mulU88(5 ether));
        assertEq(_bids[5].ercAmount, DEFAULT_AMOUNT.mulU88(2 ether));
        assertEq(_bids[6].ercAmount, DEFAULT_AMOUNT.mulU88(1 ether));
    }

    function test_SortBidOptimized() public {
        fundLimitBidOpt(1 ether, DEFAULT_AMOUNT.mulU88(1 ether), receiver);
        fundLimitBidOpt(2 ether, DEFAULT_AMOUNT.mulU88(2 ether), receiver);
        fundLimitBidOpt(4 ether, DEFAULT_AMOUNT.mulU88(4 ether), receiver);
        fundLimitBidOpt(3 ether, DEFAULT_AMOUNT.mulU88(3 ether), receiver);
        fundLimitBidOpt(2.5 ether, DEFAULT_AMOUNT.mulU88(5 ether), receiver);
        fundLimitBidOpt(6 ether, DEFAULT_AMOUNT.mulU88(6 ether), receiver);
        fundLimitBidOpt(4 ether, DEFAULT_AMOUNT.mulU88(7 ether), receiver);

        assertEqBids(getBids());
    }

    function test_SortBidOptimized2() public {
        fundLimitBidOpt(4 ether, DEFAULT_AMOUNT.mulU88(4 ether), receiver);
        fundLimitBidOpt(2.5 ether, DEFAULT_AMOUNT.mulU88(5 ether), receiver);
        fundLimitBidOpt(1 ether, DEFAULT_AMOUNT.mulU88(1 ether), receiver);
        fundLimitBidOpt(3 ether, DEFAULT_AMOUNT.mulU88(3 ether), receiver);
        fundLimitBidOpt(2 ether, DEFAULT_AMOUNT.mulU88(2 ether), receiver);
        fundLimitBidOpt(6 ether, DEFAULT_AMOUNT.mulU88(6 ether), receiver);
        fundLimitBidOpt(4 ether, DEFAULT_AMOUNT.mulU88(7 ether), receiver);

        assertEqBids(getBids());
    }

    function test_SortOrders() public {
        uint80 numOrders = 2;

        for (uint80 i = 1; i <= numOrders; i++) {
            fundOrder(O.LimitAsk, DEFAULT_PRICE + i, i * DEFAULT_AMOUNT, receiver);
        }
        for (uint80 i = numOrders; i > 0; i--) {
            fundOrder(O.LimitAsk, DEFAULT_PRICE + i, i * DEFAULT_AMOUNT, receiver);
        }

        for (uint80 i = 1; i <= numOrders; i++) {
            fundOrder(O.LimitShort, DEFAULT_PRICE + i, i * DEFAULT_AMOUNT, receiver);
        }
        for (uint80 i = numOrders; i > 0; i--) {
            fundOrder(O.LimitShort, DEFAULT_PRICE + i, i * DEFAULT_AMOUNT, receiver);
        }

        for (uint80 i = 1; i <= numOrders; i++) {
            fundOrder(O.LimitBid, DEFAULT_PRICE + i, i * DEFAULT_AMOUNT, sender);
        }
        for (uint80 i = numOrders; i > 0; i--) {
            fundOrder(O.LimitBid, DEFAULT_PRICE + i, i * DEFAULT_AMOUNT, sender);
        }

        checkOrdersPriceValidity();
    }

    function test_SortOrders2() public {
        uint80 numOrders = 2;

        for (uint80 i = 1; i <= numOrders; i++) {
            fundOrder(O.LimitAsk, DEFAULT_PRICE + i, i * DEFAULT_AMOUNT, receiver);
        }
        for (uint80 i = 1; i <= numOrders; i++) {
            fundOrder(O.LimitShort, DEFAULT_PRICE + i, i * DEFAULT_AMOUNT, receiver);
        }

        fundOrder(O.LimitBid, DEFAULT_PRICE + 2, 2 * DEFAULT_AMOUNT, receiver);
    }
}
