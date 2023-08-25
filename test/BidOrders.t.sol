// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {stdError} from "forge-std/StdError.sol";
import {U256, U88, U80} from "contracts/libraries/PRBMathHelper.sol";
import {Constants} from "contracts/libraries/Constants.sol";
import {STypes, MTypes, O} from "contracts/libraries/DataTypes.sol";

import {OBFixture} from "test/utils/OBFixture.sol";
import {console} from "contracts/libraries/console.sol";

contract BidOrdersTest is OBFixture {
    event LOG(string message);

    using U256 for uint256;
    using U88 for uint88;
    using U80 for uint80;

    function setUp() public override {
        super.setUp();
    }

    //HELPERS
    function createMultipleOrdersAtSamePriceAndAmount(
        O orderType,
        uint8 numOrders,
        uint80 price,
        uint88 ercAmount,
        address account
    ) public {
        for (uint8 i = 0; i < numOrders; i++) {
            fundOrder(orderType, price, ercAmount, account);
        }
    }

    function checkEscrowedAndOrders(
        uint256 receiverErcEscrowed,
        uint256 receiverEthEscrowed,
        uint256 senderErcEscrowed,
        uint256 senderEthEscrowed,
        uint256 bidLength,
        uint256 askLength,
        uint256 shortLength,
        uint256 senderPrice
    ) public {
        r.ercEscrowed = receiverErcEscrowed;
        r.ethEscrowed = receiverEthEscrowed;
        assertStruct(receiver, r);
        s.ercEscrowed = senderErcEscrowed;
        s.ethEscrowed = senderEthEscrowed;
        assertStruct(sender, s);
        STypes.Order[] memory bids = getBids();
        assertEq(bids.length, bidLength);
        STypes.Order[] memory asks = getAsks();
        assertEq(asks.length, askLength);
        STypes.Order[] memory shorts = getShorts();
        assertEq(shorts.length, shortLength);
        // Asset level ercDebt
        uint256 askFillErc = senderEthEscrowed.div(senderPrice);
        uint256 shortFillErc = receiverErcEscrowed - askFillErc;
        assertEq(diamond.getAssetStruct(asset).ercDebt, shortFillErc);
    }
    ///////matching tests///////
    //Limit Bid
    //Different Prices

    function testAddingBidsWithNoSells() public {
        (, uint256 ercAmountLeft) =
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        assertStruct(receiver, r);

        STypes.Order[] memory bids = getBids();
        assertEq(bids[0].price, DEFAULT_PRICE);
        assertEq(ercAmountLeft, DEFAULT_AMOUNT);
    }

    function testShortPriceGreaterThanBidPrice() public {
        fundLimitShortOpt(DEFAULT_PRICE + 1 wei, DEFAULT_AMOUNT, sender);
        (, uint256 ercAmountLeft) =
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        checkEscrowedAndOrders({
            receiverErcEscrowed: 0,
            receiverEthEscrowed: 0,
            senderErcEscrowed: 0,
            senderEthEscrowed: 0,
            bidLength: 1,
            askLength: 0,
            shortLength: 1,
            senderPrice: DEFAULT_PRICE + 1 wei
        });

        assertEq(getShorts()[0].price, DEFAULT_PRICE + 1 wei);
        assertEq(getShorts()[0].ercAmount, DEFAULT_AMOUNT);
        assertEq(getShorts()[0].id, 100);

        assertEq(getBids()[0].price, DEFAULT_PRICE);
        assertEq(getBids()[0].ercAmount, DEFAULT_AMOUNT);
        assertEq(getBids()[0].id, 101);
        assertEq(getBids()[0].ercAmount, ercAmountLeft);
        assertGt(ercAmountLeft, 0);
    }

    function testAddingLimitBidPriceEqualShortPrice() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        (, uint256 ercAmountLeft) =
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT,
            receiverEthEscrowed: 0,
            senderErcEscrowed: 0,
            senderEthEscrowed: 0,
            bidLength: 0,
            askLength: 0,
            shortLength: 0,
            senderPrice: DEFAULT_PRICE
        });
        assertEq(ercAmountLeft, 0);
    }

    function testAddingLimitBidPriceLessThanShortPrice() public {
        (, uint256 ercAmountLeft) =
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        assertGt(ercAmountLeft, 0);
        fundLimitShortOpt(DEFAULT_PRICE + 1 wei, DEFAULT_AMOUNT, sender);

        checkEscrowedAndOrders({
            receiverErcEscrowed: 0,
            receiverEthEscrowed: 0,
            senderErcEscrowed: 0,
            senderEthEscrowed: 0,
            bidLength: 1,
            askLength: 0,
            shortLength: 1,
            senderPrice: DEFAULT_PRICE
        });
    }

    function testAddingLimitBidPriceLessThanAskPrice() public {
        (, uint256 ercAmountLeft) =
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(DEFAULT_PRICE + 1 wei, DEFAULT_AMOUNT, sender);
        assertGt(ercAmountLeft, 0);

        checkEscrowedAndOrders({
            receiverErcEscrowed: 0,
            receiverEthEscrowed: 0,
            senderErcEscrowed: 0,
            senderEthEscrowed: 0,
            bidLength: 1,
            askLength: 1,
            shortLength: 0,
            senderPrice: DEFAULT_PRICE + 1 wei
        });
    }
    //Different ErcAmounts

    function testAddingLimitBidUsdGreaterSellUsd() public {
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        (, uint256 ercAmountLeft) =
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 2, receiver);
        assertEq(ercAmountLeft, DEFAULT_AMOUNT);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT,
            receiverEthEscrowed: 0,
            senderErcEscrowed: 0,
            senderEthEscrowed: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT),
            bidLength: 1,
            askLength: 0,
            shortLength: 0,
            senderPrice: DEFAULT_PRICE
        });
    }

    function testAddingBidUsdLessThanShortAskUsd() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 2, sender);
        (, uint256 ercAmountLeft) =
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        assertEq(ercAmountLeft, 0);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT,
            receiverEthEscrowed: 0,
            senderErcEscrowed: 0,
            senderEthEscrowed: 0,
            bidLength: 0,
            askLength: 0,
            shortLength: 1,
            senderPrice: DEFAULT_PRICE
        });

        assertEq(getShorts()[0].price, DEFAULT_PRICE);
        assertEq(getShorts()[0].ercAmount, DEFAULT_AMOUNT);
    }

    function testAddingBidUsdLessThanShortAskUsd2() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 5, sender);
        (, uint256 ercAmountLeft) =
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(1.5 ether), receiver);
        assertEq(ercAmountLeft, 0);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT.mulU88(1.5 ether),
            receiverEthEscrowed: 0,
            senderErcEscrowed: 0,
            senderEthEscrowed: 0,
            bidLength: 0,
            askLength: 0,
            shortLength: 1,
            senderPrice: DEFAULT_PRICE
        });
    }

    function testAddingBidUsdLessThanShortAskUsd3() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 5, sender);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(1.5 ether), receiver);
        (, uint256 ercAmountLeft) =
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(3.5 ether), receiver);
        assertEq(ercAmountLeft, 0);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT * 5,
            receiverEthEscrowed: 0,
            senderErcEscrowed: 0,
            senderEthEscrowed: 0,
            bidLength: 0,
            askLength: 0,
            shortLength: 0,
            senderPrice: DEFAULT_PRICE
        });
    }

    function testAddingBidUsdLessThanSellAskUsd() public {
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 2, sender);
        (, uint256 ercAmountLeft) =
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        assertEq(ercAmountLeft, 0);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT,
            receiverEthEscrowed: 0,
            senderErcEscrowed: 0,
            senderEthEscrowed: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT),
            bidLength: 0,
            askLength: 1,
            shortLength: 0,
            senderPrice: DEFAULT_PRICE
        });

        assertEq(getAsks()[0].price, DEFAULT_PRICE);
        assertEq(getAsks()[0].ercAmount, DEFAULT_AMOUNT);
    }

    function testAddingBidUsdLessThanSellAskUsd2() public {
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 5, sender);
        (, uint256 ercAmountLeft) =
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(1.5 ether), receiver);
        assertEq(ercAmountLeft, 0);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT.mulU88(1.5 ether),
            receiverEthEscrowed: 0,
            senderErcEscrowed: 0,
            senderEthEscrowed: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT).mul(1.5 ether),
            bidLength: 0,
            askLength: 1,
            shortLength: 0,
            senderPrice: DEFAULT_PRICE
        });

        assertEq(getAsks()[0].price, DEFAULT_PRICE);
        assertEq(getAsks()[0].ercAmount, DEFAULT_AMOUNT.mulU88(3.5 ether));
    }

    function testAddingBidUsdLessThanSellAskUsd3() public {
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 5, sender);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(1.5 ether), receiver);
        (, uint256 ercAmountLeft) =
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(3.5 ether), receiver);
        assertEq(ercAmountLeft, 0);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT * 5,
            receiverEthEscrowed: 0,
            senderErcEscrowed: 0,
            senderEthEscrowed: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT) * 5,
            bidLength: 0,
            askLength: 0,
            shortLength: 0,
            senderPrice: DEFAULT_PRICE
        });
    }

    //Matching Bids against asks and shorts
    function testMatchingLimitBidToAsksDifferentPriceNoShort() public {
        fundLimitAskOpt(DEFAULT_PRICE - 2 wei, DEFAULT_AMOUNT, sender);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        (, uint256 ercAmountLeft) =
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 2, receiver);
        assertEq(ercAmountLeft, 0);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT * 2,
            receiverEthEscrowed: DEFAULT_AMOUNT.mulU88(2 wei),
            senderErcEscrowed: 0,
            senderEthEscrowed: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT)
                + (DEFAULT_PRICE - 2 wei).mulU88(DEFAULT_AMOUNT),
            bidLength: 0,
            askLength: 0,
            shortLength: 0,
            senderPrice: DEFAULT_PRICE - 1 wei // average price
        });
    }

    function testMatchingLimitBidToAsksSamePriceNoShort() public {
        createMultipleOrdersAtSamePriceAndAmount({
            orderType: O.LimitAsk,
            numOrders: 2,
            price: DEFAULT_PRICE,
            ercAmount: DEFAULT_AMOUNT,
            account: sender
        });
        (, uint256 ercAmountLeft) =
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 2, receiver);
        assertEq(ercAmountLeft, 0);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT * 2,
            receiverEthEscrowed: 0,
            senderErcEscrowed: 0,
            senderEthEscrowed: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT) * 2,
            bidLength: 0,
            askLength: 0,
            shortLength: 0,
            senderPrice: DEFAULT_PRICE
        });
    }

    function testMatchingLimitBidToShortsDifferentPriceNoAsk() public {
        fundLimitShortOpt(DEFAULT_PRICE + 2 wei, DEFAULT_AMOUNT, sender);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        (, uint256 ercAmountLeft) =
            fundLimitBidOpt(DEFAULT_PRICE + 2 wei, DEFAULT_AMOUNT * 2, receiver);
        assertEq(ercAmountLeft, 0);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT * 2,
            receiverEthEscrowed: DEFAULT_AMOUNT.mulU88(2 wei), //change
            senderErcEscrowed: 0,
            senderEthEscrowed: 0,
            bidLength: 0,
            askLength: 0,
            shortLength: 0,
            senderPrice: DEFAULT_PRICE + 1 wei // average price
        });
    }

    function testMatchingLimitBidToShortsSamePriceNoAsk() public {
        createMultipleOrdersAtSamePriceAndAmount({
            orderType: O.LimitShort,
            numOrders: 2,
            price: DEFAULT_PRICE,
            ercAmount: DEFAULT_AMOUNT,
            account: sender
        });
        (, uint256 ercAmountLeft) =
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 2, receiver);
        assertEq(ercAmountLeft, 0);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT * 2,
            receiverEthEscrowed: 0,
            senderErcEscrowed: 0,
            senderEthEscrowed: 0,
            bidLength: 0,
            askLength: 0,
            shortLength: 0,
            senderPrice: DEFAULT_PRICE
        });
    }

    function createAsksAndShortsWithDifferentPrices() public {
        fundLimitAskOpt(DEFAULT_PRICE + 1 wei, DEFAULT_AMOUNT, sender);
        fundLimitAskOpt(DEFAULT_PRICE + 2 wei, DEFAULT_AMOUNT, sender);
        fundLimitAskOpt(DEFAULT_PRICE + 3 wei, DEFAULT_AMOUNT, sender);
        fundLimitAskOpt(DEFAULT_PRICE + 4 wei, DEFAULT_AMOUNT, sender);
        fundLimitShortOpt(DEFAULT_PRICE + 1 wei, DEFAULT_AMOUNT, sender);
        fundLimitShortOpt(DEFAULT_PRICE + 2 wei, DEFAULT_AMOUNT, sender);
        fundLimitShortOpt(DEFAULT_PRICE + 3 wei, DEFAULT_AMOUNT, sender);
    }

    function testMatchingLimitBidOnAsksAndShortsDifferentPrices() public {
        createAsksAndShortsWithDifferentPrices();
        fundLimitBidOpt(DEFAULT_PRICE + 4 wei, DEFAULT_AMOUNT * 6, receiver);

        //putting ugly accounting numbers into variables
        uint256 bidEth = ((DEFAULT_PRICE + 4 wei).mulU88(DEFAULT_AMOUNT) * 6);
        uint256 askEthSold = (DEFAULT_PRICE + 1 wei).mulU88(DEFAULT_AMOUNT)
            + (DEFAULT_PRICE + 2 wei).mulU88(DEFAULT_AMOUNT)
            + (DEFAULT_PRICE + 3 wei).mulU88(DEFAULT_AMOUNT);
        uint256 shortEthSold = (DEFAULT_PRICE + 1 wei).mulU88(DEFAULT_AMOUNT)
            + (DEFAULT_PRICE + 2 wei).mulU88(DEFAULT_AMOUNT)
            + (DEFAULT_PRICE + 3 wei).mulU88(DEFAULT_AMOUNT);
        uint256 ethSold = askEthSold + shortEthSold;
        uint256 totalRefund = bidEth - ethSold; // equals 12

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT * 6,
            receiverEthEscrowed: totalRefund,
            senderErcEscrowed: 0,
            senderEthEscrowed: askEthSold,
            bidLength: 0,
            askLength: 1,
            shortLength: 0,
            senderPrice: DEFAULT_PRICE + 2 wei // average price
        });

        assertEq(getAsks()[0].price, DEFAULT_PRICE + 4 wei);
    }

    function testMatchingLimitBidOnAsksAndShortsSamePrices() public {
        createMultipleOrdersAtSamePriceAndAmount({
            orderType: O.LimitAsk,
            numOrders: 3,
            price: DEFAULT_PRICE * 5,
            ercAmount: DEFAULT_AMOUNT,
            account: sender
        });
        createMultipleOrdersAtSamePriceAndAmount({
            orderType: O.LimitShort,
            numOrders: 3,
            price: DEFAULT_PRICE * 5,
            ercAmount: DEFAULT_AMOUNT,
            account: sender
        });

        fundLimitBidOpt(DEFAULT_PRICE * 5, DEFAULT_AMOUNT * 5, receiver);

        //reminder: matched asks gives sender eth, while shorters lock up the gained eth as collateral
        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT * 5,
            receiverEthEscrowed: 0,
            senderErcEscrowed: 0,
            senderEthEscrowed: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT) * 5 * 3,
            bidLength: 0,
            askLength: 0,
            shortLength: 1,
            senderPrice: DEFAULT_PRICE * 5
        });

        assertEq(getShorts()[0].price, DEFAULT_PRICE * 5);
    }

    function testMatchingLimitBidToShortsDifferentPriceNoAskOptimized() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender); //100
        fundLimitShortOpt(DEFAULT_PRICE - 1 wei, DEFAULT_AMOUNT, sender); //101 skip
        // G -> 101 -> 100 -> G
        (, uint256 ercAmountLeft) =
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 2, receiver);
        assertEq(ercAmountLeft, DEFAULT_AMOUNT);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT,
            receiverEthEscrowed: 0,
            senderErcEscrowed: 0,
            senderEthEscrowed: 0,
            bidLength: 1,
            askLength: 0,
            shortLength: 1,
            senderPrice: DEFAULT_PRICE
        });
    }

    function testMatchingLimitBidToShortsSamePriceNoAskOptimized() public {
        createMultipleOrdersAtSamePriceAndAmount({
            orderType: O.LimitShort,
            numOrders: 2,
            price: DEFAULT_PRICE,
            ercAmount: DEFAULT_AMOUNT,
            account: sender
        });
        (, uint256 ercAmountLeft) =
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 2, receiver);
        assertEq(ercAmountLeft, 0);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT * 2,
            receiverEthEscrowed: 0,
            senderErcEscrowed: 0,
            senderEthEscrowed: 0,
            bidLength: 0,
            askLength: 0,
            shortLength: 0,
            senderPrice: DEFAULT_PRICE
        });
    }

    function testMatchingLimitBidOnAsksAndShortsDifferentPricesOptimized() public {
        createAsksAndShortsWithDifferentPrices();
        //putting ugly accounting numbers into variables
        uint256 bidEth = ((DEFAULT_PRICE + 4 wei).mulU88(DEFAULT_AMOUNT) * 6);
        uint256 askEthSold = (DEFAULT_PRICE + 1 wei).mulU88(DEFAULT_AMOUNT)
            + (DEFAULT_PRICE + 2 wei).mulU88(DEFAULT_AMOUNT)
            + (DEFAULT_PRICE + 3 wei).mulU88(DEFAULT_AMOUNT);
        uint256 shortEthSold = (DEFAULT_PRICE + 1 wei).mulU88(DEFAULT_AMOUNT)
            + (DEFAULT_PRICE + 2 wei).mulU88(DEFAULT_AMOUNT)
            + (DEFAULT_PRICE + 3 wei).mulU88(DEFAULT_AMOUNT);
        uint256 ethSold = askEthSold + shortEthSold;
        uint256 totalRefund = bidEth - ethSold; // equals 12

        fundLimitBidOpt(DEFAULT_PRICE + 4 wei, DEFAULT_AMOUNT * 6, receiver);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT * 6,
            receiverEthEscrowed: totalRefund,
            senderErcEscrowed: 0,
            senderEthEscrowed: askEthSold,
            bidLength: 0,
            askLength: 1,
            shortLength: 0,
            senderPrice: DEFAULT_PRICE + 2 wei // average price
        });

        assertEq(getAsks()[0].price, DEFAULT_PRICE + 4 wei);
    }

    function testMatchingLimitBidOnAsksAndShortsSamePricesOptimized() public {
        createMultipleOrdersAtSamePriceAndAmount({
            orderType: O.LimitAsk,
            numOrders: 3,
            price: DEFAULT_PRICE * 5,
            ercAmount: DEFAULT_AMOUNT,
            account: sender
        });
        createMultipleOrdersAtSamePriceAndAmount({
            orderType: O.LimitShort,
            numOrders: 3,
            price: DEFAULT_PRICE * 5,
            ercAmount: DEFAULT_AMOUNT,
            account: sender
        });

        fundLimitBidOpt(DEFAULT_PRICE * 5, DEFAULT_AMOUNT * 5, receiver);

        //reminder: matched asks gives sender eth, while shorters lock up the gained eth as collateral
        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT * 5,
            receiverEthEscrowed: 0,
            senderErcEscrowed: 0,
            senderEthEscrowed: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT) * 5 * 3,
            bidLength: 0,
            askLength: 0,
            shortLength: 1,
            senderPrice: DEFAULT_PRICE * 5
        });

        assertEq(getShorts()[0].price, DEFAULT_PRICE * 5);
    }

    //Market Bid

    function testMarketBuyNoSells() public {
        assertEq(getBids().length, 0);
        fundMarketBid(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        assertEq(getBids().length, 0);
    }

    function testAddingMarketBidUsdEqualShortUsd() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        (, uint256 ercAmountLeft) = fundMarketBid(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        assertEq(ercAmountLeft, 0);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT,
            receiverEthEscrowed: 0,
            senderErcEscrowed: 0,
            senderEthEscrowed: 0,
            bidLength: 0,
            askLength: 0,
            shortLength: 0,
            senderPrice: DEFAULT_PRICE
        });
    }

    function testAddingMarketBidUsdEqualSellUsd() public {
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        (, uint256 ercAmountLeft) = fundMarketBid(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        assertEq(ercAmountLeft, 0);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT,
            receiverEthEscrowed: 0,
            senderErcEscrowed: 0,
            senderEthEscrowed: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT),
            bidLength: 0,
            askLength: 0,
            shortLength: 0,
            senderPrice: DEFAULT_PRICE
        });
    }

    function testAddingMarketBidUsdGreaterShortUsd() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        (, uint256 ercAmountLeft) =
            fundMarketBid(DEFAULT_PRICE, DEFAULT_AMOUNT * 2, receiver);
        assertEq(ercAmountLeft, DEFAULT_AMOUNT);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT,
            receiverEthEscrowed: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT),
            senderErcEscrowed: 0,
            senderEthEscrowed: 0,
            bidLength: 0, //partial market => refund
            askLength: 0,
            shortLength: 0,
            senderPrice: DEFAULT_PRICE
        });
    }

    function testAddingMarketBidUsdGreaterSellUsd() public {
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        (, uint256 ercAmountLeft) =
            fundMarketBid(DEFAULT_PRICE, DEFAULT_AMOUNT * 2, receiver);
        assertEq(ercAmountLeft, DEFAULT_AMOUNT);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT,
            receiverEthEscrowed: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT),
            senderErcEscrowed: 0,
            senderEthEscrowed: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT),
            bidLength: 0, //partial market => refund
            askLength: 0,
            shortLength: 0,
            senderPrice: DEFAULT_PRICE
        });
    }

    function testAddingMarketBidUsdLessShortUsd() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 2, sender);
        (, uint256 ercAmountLeft) = fundMarketBid(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        assertEq(ercAmountLeft, 0);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT,
            receiverEthEscrowed: 0,
            senderErcEscrowed: 0,
            senderEthEscrowed: 0,
            bidLength: 0,
            askLength: 0,
            shortLength: 1,
            senderPrice: DEFAULT_PRICE
        });

        assertEq(getShorts()[0].ercAmount, DEFAULT_AMOUNT);
    }

    function testAddingMarketBidUsdLessSellUsd() public {
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 2, sender);
        (, uint256 ercAmountLeft) = fundMarketBid(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        assertEq(ercAmountLeft, 0);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT,
            receiverEthEscrowed: 0,
            senderErcEscrowed: 0,
            senderEthEscrowed: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT),
            bidLength: 0,
            askLength: 1,
            shortLength: 0,
            senderPrice: DEFAULT_PRICE
        });

        assertEq(getAsks()[0].ercAmount, DEFAULT_AMOUNT);
    }

    function testPartialMarketBuyDueToInsufficientAsksOnOB() public {
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        (, uint256 ercAmountLeft) =
            fundMarketBid(DEFAULT_PRICE, DEFAULT_AMOUNT * 2, receiver);
        assertGt(ercAmountLeft, 0);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT,
            receiverEthEscrowed: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT),
            senderErcEscrowed: 0,
            senderEthEscrowed: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT),
            bidLength: 0, //partial market => refund
            askLength: 0,
            shortLength: 0,
            senderPrice: DEFAULT_PRICE
        });
    }

    function testMarketBuyOutOfPriceRange() public {
        fundLimitAskOpt(1 ether, DEFAULT_AMOUNT, sender);
        (, uint256 ercAmountLeft) = fundMarketBid(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        assertGt(ercAmountLeft, 0);

        checkEscrowedAndOrders({
            receiverErcEscrowed: 0,
            receiverEthEscrowed: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT),
            senderErcEscrowed: 0,
            senderEthEscrowed: 0,
            bidLength: 0,
            askLength: 1,
            shortLength: 0,
            senderPrice: 1 ether
        });
    }

    //Partial Fill - Market
    function testPartialMarketBuyUpUntilPriceRangeFill() public {
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        createMultipleOrdersAtSamePriceAndAmount({
            orderType: O.LimitAsk,
            numOrders: 3,
            price: DEFAULT_PRICE * 2,
            ercAmount: DEFAULT_AMOUNT,
            account: sender
        });

        (, uint256 ercAmountLeft) =
            fundMarketBid(DEFAULT_PRICE, DEFAULT_AMOUNT * 4, receiver);
        assertGt(ercAmountLeft, 0);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT,
            receiverEthEscrowed: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT) * 3,
            senderErcEscrowed: 0,
            senderEthEscrowed: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT),
            bidLength: 0,
            askLength: 3,
            shortLength: 0,
            senderPrice: DEFAULT_PRICE
        });
    }

    //Partial Fill - Limit
    function testPartiallyFilledLimitBid() public {
        createMultipleOrdersAtSamePriceAndAmount({
            orderType: O.LimitAsk,
            numOrders: 3,
            price: DEFAULT_PRICE,
            ercAmount: DEFAULT_AMOUNT,
            account: sender
        });
        fundLimitAskOpt(DEFAULT_PRICE * 2, DEFAULT_AMOUNT, sender);
        (, uint256 ercAmountLeft) =
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(3.5 ether), receiver);
        assertGt(ercAmountLeft, 0);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT * 3,
            receiverEthEscrowed: 0,
            senderErcEscrowed: 0,
            senderEthEscrowed: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT) * 3,
            bidLength: 1,
            askLength: 1,
            shortLength: 0,
            senderPrice: DEFAULT_PRICE
        });
    }

    ///////Testing empty OB scenarios///////
    function testPartialMarketBuyOBSuddenlyEmptyAsks() public {
        createMultipleOrdersAtSamePriceAndAmount({
            orderType: O.LimitAsk,
            numOrders: 3,
            price: DEFAULT_PRICE,
            ercAmount: DEFAULT_AMOUNT,
            account: sender
        });
        (, uint256 ercAmountLeft) =
            fundMarketBid(DEFAULT_PRICE, DEFAULT_AMOUNT * 4, receiver);
        assertGt(ercAmountLeft, 0);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT * 3,
            receiverEthEscrowed: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT),
            senderErcEscrowed: 0,
            senderEthEscrowed: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT) * 3,
            bidLength: 0,
            askLength: 0,
            shortLength: 0,
            senderPrice: DEFAULT_PRICE
        });
    }

    function testPartialMarketBuyOBSuddenlyEmptyShorts() public {
        createMultipleOrdersAtSamePriceAndAmount({
            orderType: O.LimitShort,
            numOrders: 3,
            price: DEFAULT_PRICE,
            ercAmount: DEFAULT_AMOUNT,
            account: sender
        });
        (, uint256 ercAmountLeft) =
            fundMarketBid(DEFAULT_PRICE, DEFAULT_AMOUNT * 4, receiver);
        assertGt(ercAmountLeft, 0);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT * 3,
            receiverEthEscrowed: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT), //refund
            senderErcEscrowed: 0,
            senderEthEscrowed: 0,
            bidLength: 0,
            askLength: 0,
            shortLength: 0,
            senderPrice: DEFAULT_PRICE
        });
    }

    function testPartialLimitBidOBSuddenlyEmptyAsks() public {
        createMultipleOrdersAtSamePriceAndAmount({
            orderType: O.LimitAsk,
            numOrders: 3,
            price: DEFAULT_PRICE,
            ercAmount: DEFAULT_AMOUNT,
            account: sender
        });

        (, uint256 ercAmountLeft) =
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 4, receiver);
        assertGt(ercAmountLeft, 0);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT * 3,
            receiverEthEscrowed: 0,
            senderErcEscrowed: 0,
            senderEthEscrowed: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT) * 3,
            bidLength: 1,
            askLength: 0,
            shortLength: 0,
            senderPrice: DEFAULT_PRICE
        });
        assertEq(getBids()[0].ercAmount, DEFAULT_AMOUNT);
    }

    function testPartialLimitBidOBSuddenlyEmptyShort() public {
        createMultipleOrdersAtSamePriceAndAmount({
            orderType: O.LimitShort,
            numOrders: 3,
            price: DEFAULT_PRICE,
            ercAmount: DEFAULT_AMOUNT,
            account: sender
        });
        (, uint256 ercAmountLeft) =
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 4, receiver);
        assertGt(ercAmountLeft, 0);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT * 3,
            receiverEthEscrowed: 0,
            senderErcEscrowed: 0,
            senderEthEscrowed: 0,
            bidLength: 1,
            askLength: 0,
            shortLength: 0,
            senderPrice: DEFAULT_PRICE
        });

        assertEq(getBids()[0].ercAmount, DEFAULT_AMOUNT);
    }

    // Testing refund when matched price is better than order price
    function testLimitBidRefund() public {
        fundLimitAskOpt(DEFAULT_PRICE - 1 wei, DEFAULT_AMOUNT, sender);
        assertStruct(receiver, r);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT,
            receiverEthEscrowed: DEFAULT_AMOUNT.mulU88(1 wei),
            senderErcEscrowed: 0,
            senderEthEscrowed: DEFAULT_AMOUNT.mulU88(DEFAULT_PRICE - 1),
            bidLength: 0,
            askLength: 0,
            shortLength: 0,
            senderPrice: DEFAULT_PRICE - 1 wei
        });
    }

    function testMarketBidRefund() public {
        fundLimitAskOpt(DEFAULT_PRICE - 1 wei, DEFAULT_AMOUNT, sender);
        fundMarketBid(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT,
            receiverEthEscrowed: DEFAULT_AMOUNT.mulU88(1 wei),
            senderErcEscrowed: 0,
            senderEthEscrowed: (DEFAULT_PRICE - 1 wei).mulU88(DEFAULT_AMOUNT),
            bidLength: 0,
            askLength: 0,
            shortLength: 0,
            senderPrice: DEFAULT_PRICE - 1 wei
        });
    }

    function testMarketBidPartialFillRefund() public {
        //make cheaper asks
        createMultipleOrdersAtSamePriceAndAmount({
            orderType: O.LimitAsk,
            numOrders: 3,
            price: DEFAULT_PRICE - 1 wei, //bidder will get refund based on this
            ercAmount: DEFAULT_AMOUNT,
            account: sender
        });

        fundMarketBid(DEFAULT_PRICE, DEFAULT_AMOUNT * 4, receiver);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT * 3,
            receiverEthEscrowed: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT) * 4
                - (DEFAULT_PRICE - 1 wei).mulU88(DEFAULT_AMOUNT) * 3,
            senderErcEscrowed: 0,
            senderEthEscrowed: (DEFAULT_PRICE - 1 wei).mulU88(DEFAULT_AMOUNT) * 3,
            bidLength: 0,
            askLength: 0,
            shortLength: 0,
            senderPrice: DEFAULT_PRICE - 1 wei
        });
    }

    //OrderType and prevOrderType

    function testPrevOrderTypeCancelledBid() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        assertTrue(getBids()[0].orderType == O.LimitBid);
        assertTrue(getBids()[0].prevOrderType == O.Uninitialized);

        vm.prank(receiver);
        cancelBid(100);

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        assertTrue(getBids()[0].orderType == O.LimitBid);
        assertTrue(getBids()[0].prevOrderType == O.Cancelled);
    }

    function testPrevOrderTypeMatchedBid() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        assertTrue(getBids()[0].orderType == O.LimitBid);
        assertTrue(getBids()[0].prevOrderType == O.Uninitialized);

        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        assertTrue(getBids()[0].orderType == O.LimitBid);
        assertTrue(getBids()[0].prevOrderType == O.Matched);
    }

    //Testing max orderId
    function testCanStillMatchOrderWhenBidOrderIdIsMaxed() public {
        vm.prank(owner);
        //@dev 65535 is max value
        testFacet.setOrderIdT(asset, 65534);

        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        assertEq(diamond.getAssetNormalizedStruct(asset).orderId, 65535);
        MTypes.OrderHint[] memory orderHintArray =
            diamond.getHintArray(asset, LOWER_PRICE, O.LimitBid);

        //trigger overflow when incoming bid can't be matched
        depositEthAndPrank(receiver, LOWER_PRICE.mulU88(DEFAULT_AMOUNT));
        vm.expectRevert(stdError.arithmeticError);
        diamond.createBid(
            asset,
            LOWER_PRICE,
            DEFAULT_AMOUNT,
            Constants.LIMIT_ORDER,
            orderHintArray,
            shortHintArrayStorage
        );

        //@dev Can still match since orderId isn't used invoked until it needs to be added on ob
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        assertEq(diamond.getAssetNormalizedStruct(asset).orderId, 65535);
    }

    function testBidDustAmountCancelled() public {
        // Before
        assertEq(diamond.getVaultUserStruct(vault, sender).ethEscrowed, 0);
        assertEq(diamond.getAssetUserStruct(asset, receiver).ercEscrowed, 0);
        // Match
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender); // Should be filled
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender); // Should not be filled
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT + 1, receiver);
        // After
        assertEq(
            diamond.getVaultUserStruct(vault, sender).ethEscrowed,
            DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT)
        );
        assertEq(diamond.getShortRecords(asset, sender).length, 0);
        assertEq(diamond.getAssetUserStruct(asset, receiver).ercEscrowed, DEFAULT_AMOUNT);
        // Bid is not on the orderbook
        assertEq(diamond.getBidOrder(asset, Constants.HEAD).prevId, Constants.HEAD);
        assertEq(diamond.getBidOrder(asset, Constants.HEAD).nextId, Constants.HEAD);
    }

    function testBidDustAmountFromAskCancelled() public {
        // Before
        assertEq(diamond.getVaultUserStruct(vault, sender).ethEscrowed, 0);
        assertEq(diamond.getAssetUserStruct(asset, receiver).ercEscrowed, 0);
        // Match
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT + 1, sender);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        // After
        assertEq(
            diamond.getVaultUserStruct(vault, sender).ethEscrowed,
            DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT)
        );
        assertEq(diamond.getAssetUserStruct(asset, receiver).ercEscrowed, DEFAULT_AMOUNT);
        // Ask is considered fully filled and reuseable
        assertEq(diamond.getAskOrder(asset, Constants.HEAD).prevId, 100);
        assertEq(diamond.getAskOrder(asset, Constants.HEAD).nextId, Constants.HEAD);
    }

    function testBidDustAmountFromShortCancelled() public {
        // Before
        assertEq(diamond.getShortRecords(asset, sender).length, 0);
        assertEq(diamond.getAssetUserStruct(asset, receiver).ercEscrowed, 0);
        // Match
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT + 1, sender);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        // After
        assertEq(diamond.getShortRecords(asset, sender).length, 1);
        assertEq(diamond.getAssetUserStruct(asset, receiver).ercEscrowed, DEFAULT_AMOUNT);
        // Short is considered fully filled and reuseable
        assertEq(diamond.getShortOrder(asset, Constants.HEAD).prevId, 100);
        assertEq(diamond.getShortOrder(asset, Constants.HEAD).nextId, Constants.HEAD);
    }

    //@dev scenario: HEAD S1 S2 HINT S3 S4
    function test_MoveBackThenFwd() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, address(1)); //100
        fundLimitShortOpt(DEFAULT_PRICE + 1 wei, DEFAULT_AMOUNT, address(2)); //101
        fundLimitShortOpt(DEFAULT_PRICE + 2 wei, DEFAULT_AMOUNT, address(3)); //102
        fundLimitShortOpt(DEFAULT_PRICE + 3 wei, DEFAULT_AMOUNT, address(4)); //103

        uint16[] memory shortHintArray = new uint16[](1);
        shortHintArray[0] = 101;
        //Match 101 -> 100 -> 103 -> 104 (partly)
        depositEthAndPrank(sender, DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT) * 10);
        diamond.createBid(
            asset,
            DEFAULT_PRICE + 3 wei,
            DEFAULT_AMOUNT.mulU88(3.5 ether),
            Constants.LIMIT_ORDER,
            badOrderHintArray,
            shortHintArray
        );

        assertEq(diamond.getShorts(asset).length, 1);
        assertEq(diamond.getShorts(asset)[0].id, 103);
        assertEq(diamond.getShorts(asset)[0].ercAmount, DEFAULT_AMOUNT.mulU88(0.5 ether));
    }

    function test_BidMatchAlgo_IncomingBidERCEqShortERC() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, address(1)); //100
        fundLimitShortOpt(DEFAULT_PRICE + 1 wei, DEFAULT_AMOUNT, address(2)); //101
        fundLimitShortOpt(DEFAULT_PRICE + 2 wei, DEFAULT_AMOUNT, address(3)); //102
        fundLimitShortOpt(DEFAULT_PRICE + 3 wei, DEFAULT_AMOUNT, address(4)); //103
        fundLimitShortOpt(DEFAULT_PRICE + 4 wei, DEFAULT_AMOUNT, address(4)); //104

        uint16[] memory shortHintArray = new uint16[](1);
        shortHintArray[0] = 101;
        depositEthAndPrank(sender, DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT) * 10);
        diamond.createBid(
            asset,
            DEFAULT_PRICE + 3 wei,
            DEFAULT_AMOUNT * 4,
            Constants.LIMIT_ORDER,
            badOrderHintArray,
            shortHintArray
        );

        assertEq(diamond.getShorts(asset).length, 1);
        assertEq(diamond.getShorts(asset)[0].id, 104);
        assertEq(diamond.getShorts(asset)[0].ercAmount, DEFAULT_AMOUNT);
    }

    function test_BidUpdateOracleAndStartingShortViaThreshold() public {
        assertEq(diamond.getAssetStruct(asset).startingShortId, 1);
        assertEq(diamond.getOraclePriceT(asset), 0.00025 ether);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        assertEq(diamond.getAssetStruct(asset).startingShortId, 100);

        ethAggregator.setRoundData(
            92233720368547778907 wei,
            3900 ether / Constants.BASE_ORACLE_DECIMALS,
            block.timestamp,
            block.timestamp,
            92233720368547778907 wei
        );

        //asserts that protocol price is still default price, but oracle has updated
        assertEq(diamond.getOraclePriceT(asset), 0.00025 ether);
        assertEq(diamond.getAssetPrice(asset), U256.inv(3900 ether));

        assertEq(diamond.getBids(asset).length, 0);

        uint16[] memory shortHintArray = new uint16[](1);
        shortHintArray[0] = 100;
        depositEthAndPrank(receiver, DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT) * 2);
        //trigger oracle update via threshold
        diamond.createBid(
            asset,
            DEFAULT_PRICE.mulU80(1.01 ether),
            DEFAULT_AMOUNT,
            Constants.LIMIT_ORDER,
            badOrderHintArray,
            shortHintArray
        );

        //bid has been placed and untouched
        assertEq(diamond.getBids(asset).length, 1);
        assertEq(diamond.getBids(asset)[0].ercAmount, DEFAULT_AMOUNT);
        //short still present
        assertEq(diamond.getShorts(asset).length, 1);

        assertEq(diamond.getAssetStruct(asset).startingShortId, 1);
    }
}
