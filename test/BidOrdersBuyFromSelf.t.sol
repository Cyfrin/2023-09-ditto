// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U88, U80} from "contracts/libraries/PRBMathHelper.sol";

import {STypes} from "contracts/libraries/DataTypes.sol";

// import {console} from "contracts/libraries/console.sol";
import {OBFixture} from "test/utils/OBFixture.sol";

contract BuyFromSelfTest is OBFixture {
    using U256 for uint256;
    using U88 for uint88;
    using U80 for uint80;

    function setUp() public override {
        super.setUp();
    }
    //HELPERS

    function checkEscrowedAndOrders(
        uint256 receiverErcEscrowed,
        uint256 receiverEthEscrowed,
        uint256 senderErcEscrowed,
        uint256 senderEthEscrowed,
        uint256 bidLength,
        uint256 askLength,
        uint256 shortLength
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
    }

    function testAddingLimitBidPriceEqualShortPriceSelf() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
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
            shortLength: 0
        });
    }

    function testAddingMarketBidUsdEqualShortUsdSelf() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        (, uint256 ercAmountLeft) = fundMarketBid(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        assertEq(ercAmountLeft, 0);

        r.ercEscrowed = DEFAULT_AMOUNT;
        assertStruct(receiver, r);
        assertStruct(sender, s);
    }

    function testAddingMarketBidUsdEqualSellUsdSelf() public {
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        (, uint256 ercAmountLeft) = fundMarketBid(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        assertEq(ercAmountLeft, 0);

        r.ethEscrowed = DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT);
        r.ercEscrowed = DEFAULT_AMOUNT;
        assertStruct(receiver, r);
        assertStruct(sender, s);
    }

    function testAddingMarketBidUsdGreaterShortUsdSelf() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        (, uint256 ercAmountLeft) =
            fundMarketBid(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(2 ether), receiver);
        assertEq(ercAmountLeft, DEFAULT_AMOUNT);

        r.ethEscrowed = DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT);
        r.ercEscrowed = DEFAULT_AMOUNT;
        assertStruct(receiver, r);
        assertStruct(sender, s);

        STypes.Order[] memory bids = getBids();
        assertEq(bids.length, 0); //partial market => refund
    }

    function testAddingMarketBidUsdGreaterSellUsdSelf() public {
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        (, uint256 ercAmountLeft) =
            fundMarketBid(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(2 ether), receiver);
        assertEq(ercAmountLeft, DEFAULT_AMOUNT);

        r.ethEscrowed = DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT) * 2; //eth from refund + eth gained in sell
        r.ercEscrowed = DEFAULT_AMOUNT;
        assertStruct(receiver, r);
        assertStruct(sender, s);

        STypes.Order[] memory bids = getBids();
        assertEq(bids.length, 0); //partial market => refund
    }

    function testAddingMarketBidUsdLessShortUsdSelf() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(2 ether), receiver);
        fundMarketBid(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        STypes.Order[] memory shorts = getShorts();
        assertEq(shorts[0].ercAmount, DEFAULT_AMOUNT);
        assertEq(
            shorts[0].ercAmount.mul(shorts[0].price), DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT)
        );

        STypes.Order[] memory bids = getBids();
        assertEq(bids.length, 0);
        assertEq(shorts.length, 1);
        r.ercEscrowed = DEFAULT_AMOUNT;
        assertStruct(receiver, r);
        assertStruct(sender, s);
    }

    function testAddingMarketBidUsdLessSellUsdSelf() public {
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(2 ether), receiver);
        fundMarketBid(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        STypes.Order[] memory asks = getAsks();
        assertEq(asks[0].ercAmount, DEFAULT_AMOUNT);
        assertEq(
            asks[0].ercAmount.mul(asks[0].price), DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT)
        );

        STypes.Order[] memory bids = getBids();
        assertEq(bids.length, 0);
        assertEq(asks.length, 1);

        r.ethEscrowed = DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT);
        r.ercEscrowed = DEFAULT_AMOUNT;
        assertStruct(receiver, r);
        assertStruct(sender, s);
    }

    function testAddingLimitBidWithMultipleShortsSelf() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        (, uint256 ercAmountLeft) =
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        assertEq(ercAmountLeft, 0);
        r.ercEscrowed = DEFAULT_AMOUNT;
        assertStruct(receiver, r);
        assertStruct(sender, s);
    }

    function testAddingLimitBidWithMultipleSellsSelf() public {
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        (, uint256 ercAmountLeft) =
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        assertEq(ercAmountLeft, 0);

        r.ethEscrowed = DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT);
        r.ercEscrowed = DEFAULT_AMOUNT;
        assertStruct(receiver, r);
        assertStruct(sender, s);
    }

    //partial fills
    function testAddingBidUsdLessThanShortAskUsdSelf() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(2 ether), receiver);
        (, uint256 ercAmountLeft) =
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        STypes.Order[] memory shorts = getShorts();
        assertEq(shorts[0].price, DEFAULT_PRICE);
        assertEq(shorts[0].ercAmount, DEFAULT_AMOUNT);
        assertEq(
            shorts[0].ercAmount.mul(shorts[0].price), DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT)
        );

        assertEq(ercAmountLeft, 0);
        r.ercEscrowed = DEFAULT_AMOUNT;
        assertStruct(receiver, r);
        assertStruct(sender, s);
    }

    function testAddingBidUsdLessThanSellAskUsdSelf() public {
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(2 ether), receiver);
        (, uint256 ercAmountLeft) =
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        assertEq(ercAmountLeft, 0);

        STypes.Order[] memory asks = getAsks();
        assertEq(asks[0].ercAmount, DEFAULT_AMOUNT);
        assertEq(
            asks[0].ercAmount.mul(asks[0].price), DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT)
        );

        r.ethEscrowed = DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT);
        r.ercEscrowed = DEFAULT_AMOUNT;
        assertStruct(receiver, r);
        assertStruct(sender, s);
    }

    function testPartialMarketBuyDueToInsufficientAsksOnOBSelf() public {
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        (, uint256 ercAmountLeft) =
            fundMarketBid(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(2 ether), receiver);
        assertEq(ercAmountLeft, DEFAULT_AMOUNT);

        r.ethEscrowed = DEFAULT_AMOUNT.mulU88(DEFAULT_PRICE) * 2; //eth from refund + eth gained in sell
        r.ercEscrowed = DEFAULT_AMOUNT;
        assertStruct(receiver, r);
        assertStruct(sender, s);

        STypes.Order[] memory bids = getBids();
        assertEq(bids.length, 0); //partial market => refund
    }

    function testMarketBuyOutOfPriceRangeSelf() public {
        fundLimitAskOpt(1 ether, DEFAULT_AMOUNT, receiver);
        (, uint256 ercAmountLeft) = fundMarketBid(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        assertEq(ercAmountLeft, DEFAULT_AMOUNT);

        r.ethEscrowed = DEFAULT_AMOUNT.mulU88(DEFAULT_PRICE);
        assertStruct(receiver, r);
        assertStruct(sender, s);
    }

    function testPartialMarketBuyUpUntilPriceRangeFillSelf() public {
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(DEFAULT_PRICE * 2, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(DEFAULT_PRICE * 3, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(DEFAULT_PRICE * 4, DEFAULT_AMOUNT, receiver);
        (, uint256 ercAmountLeft) =
            fundMarketBid(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(4 ether), receiver);
        assertEq(ercAmountLeft, DEFAULT_AMOUNT.mulU88(3 ether));

        r.ethEscrowed = DEFAULT_AMOUNT.mulU88(DEFAULT_PRICE) * 4;
        r.ercEscrowed = DEFAULT_AMOUNT;
        assertStruct(receiver, r);
        assertStruct(sender, s);
    }

    function testCorrectIncomingBidUpdateOnMatchingPartialAskFillSelf() public {
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        (, uint256 ercAmountLeft) =
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(3.5 ether), receiver);
        assertEq(ercAmountLeft, 0);

        r.ethEscrowed = DEFAULT_AMOUNT.mulU88(DEFAULT_PRICE).mul(3.5 ether);
        r.ercEscrowed = DEFAULT_AMOUNT.mulU88(3.5 ether);
        assertStruct(receiver, r);
        assertStruct(sender, s);
    }

    function testCorrectIncomingBidUpdateOnMatchingPutOnOBSelf() public {
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(DEFAULT_PRICE * 2, DEFAULT_AMOUNT, receiver);
        (, uint256 ercAmountLeft) =
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(3.5 ether), receiver);
        assertEq(ercAmountLeft, DEFAULT_AMOUNT.mulU88(0.5 ether));

        r.ethEscrowed = DEFAULT_AMOUNT.mulU88(DEFAULT_PRICE) * 3;
        r.ercEscrowed = DEFAULT_AMOUNT.mulU88(3 ether);
        assertStruct(receiver, r);
        assertStruct(sender, s);
    }
}
