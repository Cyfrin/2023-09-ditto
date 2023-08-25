// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {stdError} from "forge-std/StdError.sol";
import {U256, U88, U80} from "contracts/libraries/PRBMathHelper.sol";
import {Constants} from "contracts/libraries/Constants.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {STypes, MTypes, O} from "contracts/libraries/DataTypes.sol";

import {OBFixture} from "test/utils/OBFixture.sol";
// import {console} from "contracts/libraries/console.sol";

contract SellOrdersTest is OBFixture {
    using U256 for uint256;
    using U88 for uint88;
    using U80 for uint80;

    function setUp() public override {
        super.setUp();
    }
    //HELPERS

    function createBidsAtDefaultPrice() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
    }

    function createBidsForPartialAsk() public {
        createBidsAtDefaultPrice();
        fundLimitBidOpt(DEFAULT_PRICE - 1, DEFAULT_AMOUNT, receiver); //shouldn't match
    }

    function checkEscrowedAndOrders(
        uint256 receiverErcEscrowed,
        uint256 senderErcEscrowed,
        uint256 senderEthEscrowed,
        uint256 bidLength,
        uint256 askLength
    ) public {
        r.ercEscrowed = receiverErcEscrowed;
        assertStruct(receiver, r);
        s.ercEscrowed = senderErcEscrowed;
        s.ethEscrowed = senderEthEscrowed;
        assertStruct(sender, s);
        STypes.Order[] memory bids = getBids();
        assertEq(bids.length, bidLength);
        STypes.Order[] memory asks = getAsks();
        assertEq(asks.length, askLength);
        // Asset level ercDebt
        assertEq(diamond.getAssetStruct(asset).ercDebt, 0);
    }
    //Matching Orders

    function testAddingSellWithNoBids() public {
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        STypes.Order[] memory asks = getAsks();
        assertEq(asks[0].price, DEFAULT_PRICE);
    }

    function testAddingLimitSellAskUsdGreaterThanBidUsd() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 2, sender);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT,
            senderErcEscrowed: 0,
            senderEthEscrowed: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT),
            bidLength: 0,
            askLength: 1
        });
        assertEq(getAsks()[0].price, DEFAULT_PRICE);
    }

    function testAddingLimitSellAskWithMultipleBids() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT,
            senderErcEscrowed: 0,
            senderEthEscrowed: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT),
            bidLength: 1,
            askLength: 0
        });

        assertEq(getBids()[0].price, DEFAULT_PRICE);
    }

    //partial fills from ask
    function testAddingSellUsdLessThanBidUsd() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 2, receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT,
            senderErcEscrowed: 0,
            senderEthEscrowed: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT),
            bidLength: 1,
            askLength: 0
        });

        assertEq(getBids()[0].price, DEFAULT_PRICE);
        assertEq(getBids()[0].ercAmount, DEFAULT_AMOUNT);
    }

    function testAddingSellUsdLessThanBidUsd2() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 5, receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(1.5 ether), sender);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT.mulU88(1.5 ether),
            senderErcEscrowed: 0,
            senderEthEscrowed: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT).mul(1.5 ether),
            bidLength: 1,
            askLength: 0
        });

        assertEq(getBids()[0].price, DEFAULT_PRICE);
        assertEq(getBids()[0].ercAmount, (DEFAULT_AMOUNT).mul(3.5 ether));
    }

    function testAddingSellUsdLessThanBidUsdUntilBidIsFullyFilled() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 5, receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(1.5 ether), sender);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(3.5 ether), sender);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT * 5,
            senderErcEscrowed: 0,
            senderEthEscrowed: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT).mul(5 ether),
            bidLength: 0,
            askLength: 0
        });
    }

    function testPartialMarketSellDueToInsufficientBidsOnOB() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundMarketAsk(DEFAULT_PRICE, DEFAULT_AMOUNT * 2, sender);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT,
            senderErcEscrowed: DEFAULT_AMOUNT,
            senderEthEscrowed: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT),
            bidLength: 0,
            askLength: 0
        });
    }

    function testPartialLimitAsk() public {
        createBidsForPartialAsk();
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(3.5 ether), sender);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT * 3,
            senderErcEscrowed: 0,
            senderEthEscrowed: DEFAULT_PRICE.mul(DEFAULT_AMOUNT * 3),
            bidLength: 1,
            askLength: 1
        });
    }

    //Testing empty OB scenarios
    function testPartialMarketAskOBSuddenlyEmpty() public {
        createBidsAtDefaultPrice();
        fundMarketAsk(DEFAULT_PRICE, DEFAULT_AMOUNT * 4, sender);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT * 3,
            senderErcEscrowed: DEFAULT_AMOUNT,
            senderEthEscrowed: DEFAULT_PRICE.mul(DEFAULT_AMOUNT * 3),
            bidLength: 0,
            askLength: 0
        });
    }

    function testPartialLimitAskOBSuddenlyEmpty() public {
        createBidsAtDefaultPrice();
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 4, sender);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT * 3,
            senderErcEscrowed: 0,
            senderEthEscrowed: DEFAULT_PRICE.mul(DEFAULT_AMOUNT * 3),
            bidLength: 0,
            askLength: 1
        });
    }

    //test matching based on price differences
    function testAddingLimitSellAskPriceEqualBidPrice() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT,
            senderErcEscrowed: 0,
            senderEthEscrowed: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT),
            bidLength: 0,
            askLength: 0
        });
    }

    //@dev no match because price out of range
    function testAddingLimitSellAskPriceGreaterBidPrice() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(DEFAULT_PRICE + 1 wei, DEFAULT_AMOUNT, sender);

        checkEscrowedAndOrders({
            receiverErcEscrowed: 0,
            senderErcEscrowed: 0,
            senderEthEscrowed: 0,
            bidLength: 1,
            askLength: 1
        });
    }

    function testAddingLimitSellAskPriceLessBidPrice() public {
        fundLimitBidOpt(DEFAULT_PRICE + 1 wei, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT,
            senderErcEscrowed: 0,
            senderEthEscrowed: (DEFAULT_PRICE + 1 wei).mulU88(DEFAULT_AMOUNT),
            bidLength: 0,
            askLength: 0
        });
    }

    function testMarketSellNoBids() public {
        assertEq(getAsks().length, 0);
        fundMarketAsk(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        assertEq(getAsks().length, 0);
    }
    //OrderType and prevOrderType

    function testPrevOrderTypeCancelledAsk() public {
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        assertTrue(getAsks()[0].orderType == O.LimitAsk);
        assertTrue(getAsks()[0].prevOrderType == O.Uninitialized);

        vm.prank(sender);
        cancelAsk(100);

        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        assertTrue(getAsks()[0].orderType == O.LimitAsk);
        assertTrue(getAsks()[0].prevOrderType == O.Cancelled);
    }

    function testPrevOrderTypeMatchedAsk() public {
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        assertTrue(getAsks()[0].orderType == O.LimitAsk);
        assertTrue(getAsks()[0].prevOrderType == O.Uninitialized);

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        assertTrue(getAsks()[0].orderType == O.LimitAsk);
        assertTrue(getAsks()[0].prevOrderType == O.Matched);
    }

    function testPrevOrderTypeCancelledShort() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        assertTrue(getShorts()[0].orderType == O.LimitShort);
        assertTrue(getShorts()[0].prevOrderType == O.Uninitialized);

        vm.prank(sender);
        cancelShort(100);

        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        assertTrue(getShorts()[0].orderType == O.LimitShort);
        assertTrue(getShorts()[0].prevOrderType == O.Cancelled);
    }

    function testPrevOrderTypeMatchedShort() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        assertTrue(getShorts()[0].orderType == O.LimitShort);
        assertTrue(getShorts()[0].prevOrderType == O.Uninitialized);

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        assertTrue(getShorts()[0].orderType == O.LimitShort);
        assertTrue(getShorts()[0].prevOrderType == O.Matched);
    }

    //Testing max orderId
    function testCanStillMatchOrderWhenAskOrderIdIsMaxed() public {
        vm.prank(owner);
        //@dev 65535 is max value
        testFacet.setOrderIdT(asset, 65534);

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        assertEq(diamond.getAssetNormalizedStruct(asset).orderId, 65535);
        MTypes.OrderHint[] memory orderHintArray =
            diamond.getHintArray(asset, HIGHER_PRICE, O.LimitAsk);

        //trigger overflow when incoming ask can't be matched
        depositUsdAndPrank(receiver, DEFAULT_AMOUNT);
        vm.expectRevert(stdError.arithmeticError);
        diamond.createAsk(
            asset,
            DEFAULT_PRICE * 10, // not matched
            DEFAULT_AMOUNT,
            Constants.LIMIT_ORDER,
            orderHintArray
        );

        //@dev Can still match since orderId isn't used invoked until it needs to be added on ob
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        assertEq(diamond.getAssetNormalizedStruct(asset).orderId, 65535);
    }

    function testAskDustAmountCancelled() public {
        // Before
        assertEq(diamond.getVaultUserStruct(vault, sender).ethEscrowed, 0);
        assertEq(diamond.getAssetUserStruct(asset, receiver).ercEscrowed, 0);
        // Match
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // Should be filled
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // Should not be filled
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT + 1, sender);
        // After
        assertEq(diamond.getAssetUserStruct(asset, receiver).ercEscrowed, DEFAULT_AMOUNT);
        assertEq(
            diamond.getVaultUserStruct(vault, sender).ethEscrowed,
            DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT)
        );
        // Ask is not on the orderbook
        assertEq(diamond.getAskOrder(asset, Constants.HEAD).prevId, Constants.HEAD);
        assertEq(diamond.getAskOrder(asset, Constants.HEAD).nextId, Constants.HEAD);
        assertEq(
            diamond.getBidOrder(asset, Constants.STARTING_ID).ercAmount, DEFAULT_AMOUNT
        );
    }

    function testAskDustAmountFromBidCancelled() public {
        // Before
        assertEq(diamond.getVaultUserStruct(vault, sender).ethEscrowed, 0);
        assertEq(diamond.getAssetUserStruct(asset, receiver).ercEscrowed, 0);
        // Match
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT + 1, receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        // After
        assertEq(diamond.getAssetUserStruct(asset, receiver).ercEscrowed, DEFAULT_AMOUNT);
        assertEq(
            diamond.getVaultUserStruct(vault, sender).ethEscrowed,
            DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT)
        );
        // Bid is considered fully filled and reuseable
        assertEq(diamond.getBidOrder(asset, Constants.HEAD).prevId, 100);
        assertEq(diamond.getBidOrder(asset, Constants.HEAD).nextId, Constants.HEAD);
    }
}
