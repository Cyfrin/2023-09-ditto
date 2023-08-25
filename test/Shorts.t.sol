// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U88, U80} from "contracts/libraries/PRBMathHelper.sol";

import {STypes, SR} from "contracts/libraries/DataTypes.sol";

import {OBFixture} from "test/utils/OBFixture.sol";
import {Constants} from "contracts/libraries/Constants.sol";
import {Errors} from "contracts/libraries/Errors.sol";

import {console} from "contracts/libraries/console.sol";

contract ShortsTest is OBFixture {
    using U256 for uint256;
    using U88 for uint88;
    using U80 for uint80;

    uint8 public constant PRIMARY = 0;
    uint8 public constant ERC_ESCROWED = 1;
    uint8 public constant WALLET = 2;

    bool public constant PARTIAL_EXIT = false;
    bool public constant FULL_EXIT = true;

    uint80 public constant SHORT1_PRICE = DEFAULT_PRICE;
    uint80 public constant SHORT2_PRICE = DEFAULT_PRICE * 2;
    uint80 public constant SHORT3_PRICE = DEFAULT_PRICE * 3;

    uint80 public SHORT1_COLLATERAL = SHORT1_PRICE.mulU80(DEFAULT_AMOUNT) * 6;
    uint80 public SHORT2_COLLATERAL = SHORT2_PRICE.mulU80(DEFAULT_AMOUNT) * 6;
    uint80 public SHORT3_COLLATERAL = SHORT3_PRICE.mulU80(DEFAULT_AMOUNT) * 6;

    function setUp() public override {
        super.setUp();
    }

    function makeShorts() public {
        fundLimitBidOpt(SHORT1_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(SHORT1_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(SHORT2_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(SHORT2_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(SHORT3_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(SHORT3_PRICE, DEFAULT_AMOUNT, sender);

        r.ercEscrowed = DEFAULT_AMOUNT.mulU88(3 ether);
        assertStruct(receiver, r);
        assertStruct(sender, s);
        assertEq(getShortRecordCount(sender), 3);
        assertEq(
            getShortRecord(s.addr, Constants.SHORT_STARTING_ID).collateral,
            SHORT1_COLLATERAL
        );
        assertEq(
            getShortRecord(s.addr, Constants.SHORT_STARTING_ID + 1).collateral,
            SHORT2_COLLATERAL
        );
        assertEq(
            getShortRecord(s.addr, Constants.SHORT_STARTING_ID + 2).collateral,
            SHORT3_COLLATERAL
        );
        assertEq(
            getShortRecord(sender, Constants.SHORT_STARTING_ID).ercDebt, DEFAULT_AMOUNT
        );
        assertEq(
            getShortRecord(sender, Constants.SHORT_STARTING_ID + 1).ercDebt,
            DEFAULT_AMOUNT
        );
        assertEq(
            getShortRecord(sender, Constants.SHORT_STARTING_ID + 2).ercDebt,
            DEFAULT_AMOUNT
        );
    }

    function prepareExitShort(uint8 exitType) public {
        makeShorts();

        if (exitType == PRIMARY) {
            fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, extra);
            fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, extra);
            fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, extra);
            r.ercEscrowed = DEFAULT_AMOUNT * 3; //from bid
        } else if (exitType == ERC_ESCROWED) {
            depositUsd(sender, DEFAULT_AMOUNT * 3);
            s.ercEscrowed = DEFAULT_AMOUNT * 3;
        } else if (exitType == WALLET) {
            vm.prank(_diamond);
            token.mint(sender, DEFAULT_AMOUNT * 3);
            assertEq(token.balanceOf(sender), DEFAULT_AMOUNT * 3);
            vm.prank(sender);
            token.increaseAllowance(_diamond, DEFAULT_AMOUNT * 3);
        }

        r.ethEscrowed = 0;
        assertStruct(receiver, r);
        s.ethEscrowed = 0;
        assertStruct(sender, s);
        e.ethEscrowed = 0;
        e.ercEscrowed = 0;
        assertStruct(extra, e);
    }

    function primaryExitShort(bool isFullExit) public {
        if (isFullExit) {
            //@dev: fully exit all 1 short
            exitShort(
                Constants.SHORT_STARTING_ID + 1, DEFAULT_AMOUNT, DEFAULT_PRICE, sender
            );
            assertEq(getShortRecordCount(sender), 2);
            assertEq(
                diamond.getAssetStruct(asset).ercDebt, DEFAULT_AMOUNT.mulU88(2 ether)
            );

            r.ethEscrowed = 0;
            r.ercEscrowed = DEFAULT_AMOUNT * 3; //from bid
            assertStruct(receiver, r);
            s.ethEscrowed = SHORT2_COLLATERAL - DEFAULT_PRICE.mulU80(DEFAULT_AMOUNT);
            s.ercEscrowed = 0 ether;
            assertStruct(sender, s);
            e.ethEscrowed = DEFAULT_PRICE.mulU80(DEFAULT_AMOUNT);
            e.ercEscrowed = 0;
            assertStruct(extra, e);
        } else {
            uint88 partialAmt = DEFAULT_AMOUNT / 2;
            //@dev: partially exit one short
            exitShort(Constants.SHORT_STARTING_ID + 1, partialAmt, DEFAULT_PRICE, sender);
            uint256 shortCount = getShortRecordCount(sender);
            assertEq(shortCount, 3);

            r.ethEscrowed = 0;
            r.ercEscrowed = DEFAULT_AMOUNT * 3;
            assertStruct(receiver, r);
            s.ethEscrowed = 0 ether;
            s.ercEscrowed = 0; //burned after bought back
            assertStruct(sender, s);
            e.ethEscrowed = DEFAULT_PRICE.mulU80(DEFAULT_AMOUNT).mul(0.5 ether); //gained from exitShort
            e.ercEscrowed = 0;
            assertStruct(extra, e);

            assertEq(
                getShortRecord(sender, Constants.SHORT_STARTING_ID).collateral,
                SHORT1_COLLATERAL
            );
            assertEq(
                getShortRecord(sender, Constants.SHORT_STARTING_ID + 1).collateral,
                SHORT2_COLLATERAL - (DEFAULT_PRICE.mul(partialAmt))
            );
            assertEq(
                getShortRecord(sender, Constants.SHORT_STARTING_ID + 2).collateral,
                SHORT3_COLLATERAL
            );
            assertEq(
                getShortRecord(sender, Constants.SHORT_STARTING_ID + 1).ercDebt,
                partialAmt
            );
            assertEq(
                diamond.getAssetStruct(asset).ercDebt, DEFAULT_AMOUNT.mulU88(2.5 ether)
            );
        }
    }

    function exitShortFromWallet(bool isFullExit) public {
        if (isFullExit) {
            exitShortWallet(Constants.SHORT_STARTING_ID + 1, DEFAULT_AMOUNT, sender);
            assertEq(token.balanceOf(sender), DEFAULT_AMOUNT * 2);
            assertEq(getShortRecordCount(sender), 2);
            s.ethEscrowed = SHORT2_COLLATERAL;
            assertEq(token.balanceOf(sender), DEFAULT_AMOUNT * 2);
            assertEq(diamond.getAssetStruct(asset).ercDebt, DEFAULT_AMOUNT * 2);
        } else {
            exitShortWallet(Constants.SHORT_STARTING_ID + 1, DEFAULT_AMOUNT / 2, sender);
            uint256 shortCount = getShortRecordCount(sender);
            assertEq(shortCount, 3);
            assertEq(
                getShortRecord(sender, Constants.SHORT_STARTING_ID + 1).ercDebt,
                DEFAULT_AMOUNT.mulU88(0.5 ether)
            );
            s.ethEscrowed = 0;
            assertEq(
                diamond.getAssetStruct(asset).ercDebt,
                DEFAULT_AMOUNT * 3 - (DEFAULT_AMOUNT / 2)
            );
        }

        r.ercEscrowed = DEFAULT_AMOUNT * 3;
        assertStruct(receiver, r);
        assertStruct(sender, s);
        assertStruct(extra, e);
    }

    function exitShortWithERC(bool isFullExit) public {
        if (isFullExit) {
            exitShortErcEscrowed(Constants.SHORT_STARTING_ID + 1, DEFAULT_AMOUNT, sender);
            assertEq(getShortRecordCount(sender), 2);
            s.ethEscrowed = SHORT2_COLLATERAL;
            s.ercEscrowed = DEFAULT_AMOUNT * 2;
            assertEq(diamond.getAssetStruct(asset).ercDebt, DEFAULT_AMOUNT * 2);
        } else {
            exitShortErcEscrowed(
                Constants.SHORT_STARTING_ID + 1, DEFAULT_AMOUNT / 2, sender
            );
            assertEq(getShortRecordCount(sender), 3);
            s.ercEscrowed = DEFAULT_AMOUNT * 3 - (DEFAULT_AMOUNT / 2);
            assertEq(
                diamond.getAssetStruct(asset).ercDebt,
                DEFAULT_AMOUNT * 3 - (DEFAULT_AMOUNT / 2)
            );
        }
        assertStruct(receiver, r);
        assertStruct(sender, s);
        assertStruct(extra, e);
    }

    function checkCombineShortsx3() public {
        assertEq(getShortRecordCount(sender), 1);
        assertStruct(sender, s);
        assertEq(
            getShortRecord(sender, Constants.SHORT_STARTING_ID).collateral,
            SHORT1_COLLATERAL + SHORT2_COLLATERAL + SHORT3_COLLATERAL
        );
        assertEq(
            getShortRecord(sender, Constants.SHORT_STARTING_ID).ercDebt,
            DEFAULT_AMOUNT * 3
        );
    }

    function checkShortLinking(uint8 shortRecordId) public {
        STypes.Order[] memory shortsUnfilled = getShorts();
        assertEq(shortsUnfilled[0].shortRecordId, shortRecordId);
        STypes.ShortRecord memory short = getShortRecord(sender, shortRecordId);
        assertEq(short.collateral, DEFAULT_AMOUNT.mulU88(6 ether));
        assertTrue(short.status == SR.PartialFill);
        assertEq(
            getShortRecordCount(sender), shortRecordId - Constants.SHORT_STARTING_ID + 1
        );
        // Partial Fill 2/2
        fundLimitBidOpt(1 ether, DEFAULT_AMOUNT, receiver);
        shortsUnfilled = getShorts();
        assertEq(shortsUnfilled[0].shortRecordId, shortRecordId);
        short = getShortRecord(sender, shortRecordId);
        assertEq(short.collateral, DEFAULT_AMOUNT.mulU88(12 ether));
        assertTrue(short.status == SR.PartialFill);
        assertEq(
            getShortRecordCount(sender), shortRecordId - Constants.SHORT_STARTING_ID + 1
        );
        // Fully Filled
        fundLimitBidOpt(1 ether, DEFAULT_AMOUNT, receiver);
        shortsUnfilled = getShorts();
        assertEq(shortsUnfilled.length, 0);
        short = getShortRecord(sender, shortRecordId);
        assertEq(short.collateral, DEFAULT_AMOUNT.mulU88(18 ether));
        assertTrue(short.status == SR.FullyFilled);
        assertEq(
            getShortRecordCount(sender), shortRecordId - Constants.SHORT_STARTING_ID + 1
        );
        assertEq(diamond.getAssetStruct(asset).ercDebt, getTotalErc());
    }

    function recycleShortRecordOrder(uint8 id1, uint8 id2, uint8 id3) public {
        makeShorts();
        // Exit shorts
        createAsk(
            DEFAULT_PRICE,
            DEFAULT_AMOUNT * 3,
            Constants.LIMIT_ORDER,
            badOrderHintArray,
            receiver
        );
        exitShort(id1, DEFAULT_AMOUNT, SHORT1_PRICE, sender);
        assertEq(getShortRecordCount(sender), 2);
        exitShort(id2, DEFAULT_AMOUNT, SHORT1_PRICE, sender);
        assertEq(getShortRecordCount(sender), 1);
        exitShort(id3, DEFAULT_AMOUNT, SHORT1_PRICE, sender);
        assertEq(getShortRecordCount(sender), 0);
        // Recycle shorts
        fundLimitBidOpt(SHORT1_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(SHORT1_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(SHORT2_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(SHORT2_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(SHORT3_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(SHORT3_PRICE, DEFAULT_AMOUNT, sender);
        assertEq(getShortRecordCount(sender), 3);
        // Check order and id, should be reversed
        STypes.ShortRecord memory short = getShortRecord(sender, id1);
        assertEq(short.collateral, SHORT3_COLLATERAL);
        short = getShortRecord(sender, id2);
        assertEq(short.collateral, SHORT2_COLLATERAL);
        short = getShortRecord(sender, id3);
        assertEq(short.collateral, SHORT1_COLLATERAL);
        short = getShortRecord(sender, 1);
        assertEq(diamond.getAssetStruct(asset).ercDebt, getTotalErc());
    }

    //Primary Exit Short
    function testExitShortPrimaryFull() public {
        prepareExitShort({exitType: PRIMARY});
        primaryExitShort({isFullExit: FULL_EXIT});
    }

    function testExitShortPrimaryPartial() public {
        prepareExitShort({exitType: PRIMARY});
        primaryExitShort({isFullExit: PARTIAL_EXIT});
    }

    function testTryFullExitShortNotEnoughAsksForBuyBack() public {
        makeShorts();
        //create ask to allow exit short
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT / 2, extra);
        assertEq(getTotalErc(), DEFAULT_AMOUNT.mulU88(3.5 ether));
        exitShort(Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT, DEFAULT_PRICE, sender);
        uint256 shortCount = getShortRecordCount(sender);
        assertEq(shortCount, 3);

        r.ethEscrowed = 0;
        r.ercEscrowed = DEFAULT_AMOUNT.mulU88(3 ether);
        assertStruct(receiver, r);
        s.ethEscrowed = 0; //collateral used for buy back. Remainder gets locked again
        s.ercEscrowed = 0;
        assertStruct(sender, s);
        e.ethEscrowed = DEFAULT_PRICE.mul(DEFAULT_AMOUNT / 2); //gained from exitShort
        e.ercEscrowed = 0;
        assertStruct(extra, e);
        assertEq(diamond.getAssetStruct(asset).ercDebt, DEFAULT_AMOUNT.mulU88(2.5 ether));
    }

    ////// Secondary Exit Short//////

    function testExitShortSecondaryErcEscrowedFull() public {
        prepareExitShort({exitType: ERC_ESCROWED});
        exitShortWithERC({isFullExit: FULL_EXIT});
    }

    function testExitShortSecondaryErcEscrowedPartial() public {
        prepareExitShort({exitType: ERC_ESCROWED});
        exitShortWithERC({isFullExit: PARTIAL_EXIT});
    }

    function testExitShortSecondaryWalletFull() public {
        prepareExitShort({exitType: WALLET});
        exitShortFromWallet({isFullExit: FULL_EXIT});
    }

    function testExitShortSecondaryWalletPartial() public {
        prepareExitShort({exitType: WALLET});
        exitShortFromWallet({isFullExit: PARTIAL_EXIT});
    }
    //////Updating Collateral//////

    function testIncreaseCollateral() public {
        uint256 collateral = DEFAULT_PRICE.mulU80(DEFAULT_AMOUNT) * 6;
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        assertEq(
            getShortRecord(sender, Constants.SHORT_STARTING_ID).collateral, collateral
        );
        depositEthAndPrank(sender, DEFAULT_AMOUNT);
        increaseCollateral(Constants.SHORT_STARTING_ID, 1 wei);
        assertEq(
            getShortRecord(sender, Constants.SHORT_STARTING_ID).collateral,
            collateral + 1 wei
        );
    }

    function testDecreaseCollateral() public {
        uint256 collateral = DEFAULT_PRICE.mulU80(DEFAULT_AMOUNT) * 6;
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        assertEq(
            getShortRecord(sender, Constants.SHORT_STARTING_ID).collateral, collateral
        );
        vm.prank(sender);
        decreaseCollateral(Constants.SHORT_STARTING_ID, 1 wei);
        assertEq(
            getShortRecord(sender, Constants.SHORT_STARTING_ID).collateral,
            collateral - 1 wei
        );
    }

    //////Combine Shorts//////
    function testCombineShortsx2() public {
        makeShorts();

        vm.prank(sender);
        combineShorts({
            id1: Constants.SHORT_STARTING_ID,
            id2: Constants.SHORT_STARTING_ID + 2
        });

        assertEq(getShortRecordCount(sender), 2);
        assertStruct(sender, s);
        assertEq(
            getShortRecord(sender, Constants.SHORT_STARTING_ID).collateral,
            SHORT1_COLLATERAL + SHORT3_COLLATERAL
        );
        assertEq(
            getShortRecord(sender, Constants.SHORT_STARTING_ID + 1).collateral,
            SHORT2_COLLATERAL
        );
    }

    function testCombineShortsx3() public {
        makeShorts();

        uint8[] memory shortRecords = new uint8[](3);
        shortRecords[0] = Constants.SHORT_STARTING_ID;
        shortRecords[1] = Constants.SHORT_STARTING_ID + 1;
        shortRecords[2] = Constants.SHORT_STARTING_ID + 2;
        vm.prank(sender);
        diamond.combineShorts(asset, shortRecords);
        checkCombineShortsx3();
    }

    function testCombineShortsx3LowCR() public {
        makeShorts();
        _setETH(1333 ether); // Could be flagged but aren't
        uint8[] memory shortRecords = new uint8[](3);
        shortRecords[0] = Constants.SHORT_STARTING_ID;
        shortRecords[1] = Constants.SHORT_STARTING_ID + 1;
        shortRecords[2] = Constants.SHORT_STARTING_ID + 2;

        vm.prank(sender);
        diamond.combineShorts(asset, shortRecords);
        checkCombineShortsx3();

        // Ensure still flaggable, no revert
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID, Constants.HEAD);
    }

    function testCombineShortsFlaggedFirst() public {
        makeShorts();
        _setETH(1334 ether);
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID, Constants.HEAD);

        uint8[] memory shortRecords = new uint8[](3);
        shortRecords[0] = Constants.SHORT_STARTING_ID; //flagged
        shortRecords[1] = Constants.SHORT_STARTING_ID + 1;
        shortRecords[2] = Constants.SHORT_STARTING_ID + 2;

        vm.prank(sender);
        diamond.combineShorts(asset, shortRecords);
        checkCombineShortsx3();

        // Ensure c-ratio greater than the flagging threshold
        vm.expectRevert(Errors.SufficientCollateral.selector);
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID, Constants.HEAD);
    }

    function testCombineShortsFlaggedNonFirst() public {
        makeShorts();
        _setETH(1333 ether); // low enough to flag short 3
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID + 1, Constants.HEAD);
        _setETH(1334 ether); // high enough to bring combined c-ratio above min

        uint8[] memory shortRecords = new uint8[](3);
        shortRecords[0] = Constants.SHORT_STARTING_ID;
        shortRecords[1] = Constants.SHORT_STARTING_ID + 1; //flagged
        shortRecords[2] = Constants.SHORT_STARTING_ID + 2;

        vm.prank(sender);
        diamond.combineShorts(asset, shortRecords);
        checkCombineShortsx3();

        // Ensure c-ratio greater than the flagging threshold
        vm.expectRevert(Errors.SufficientCollateral.selector);
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID, Constants.HEAD);
    }

    function testCombineShortsFlaggedAll() public {
        makeShorts();
        console.log("yo");
        _setETH(1 ether);
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID, Constants.HEAD);
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID + 1, Constants.HEAD);
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID + 2, Constants.HEAD);
        _setETH(1334 ether);

        uint8[] memory shortRecords = new uint8[](3);
        shortRecords[0] = Constants.SHORT_STARTING_ID; // flagged
        shortRecords[1] = Constants.SHORT_STARTING_ID + 1; // flagged
        shortRecords[2] = Constants.SHORT_STARTING_ID + 2; // flagged

        vm.prank(sender);
        diamond.combineShorts(asset, shortRecords);
        checkCombineShortsx3();

        // Ensure c-ratio greater than the flagging threshold
        vm.expectRevert(Errors.SufficientCollateral.selector);
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID, Constants.HEAD);
    }

    function testRevertCombineShortsFlaggedFirst() public {
        makeShorts();
        _setETH(1333 ether);
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID, Constants.HEAD);

        uint8[] memory shortRecords = new uint8[](3);
        shortRecords[0] = Constants.SHORT_STARTING_ID; // flagged
        shortRecords[1] = Constants.SHORT_STARTING_ID + 1;
        shortRecords[2] = Constants.SHORT_STARTING_ID + 2;

        vm.prank(sender);
        vm.expectRevert(Errors.InsufficientCollateral.selector);
        diamond.combineShorts(asset, shortRecords);
    }

    function testRevertCombineShortsFlaggedNonFirst() public {
        makeShorts();
        _setETH(1333 ether);
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID + 1, Constants.HEAD);

        uint8[] memory shortRecords = new uint8[](3);
        shortRecords[0] = Constants.SHORT_STARTING_ID;
        shortRecords[1] = Constants.SHORT_STARTING_ID + 1; // flagged
        shortRecords[2] = Constants.SHORT_STARTING_ID + 2;
        vm.prank(sender);
        vm.expectRevert(Errors.InsufficientCollateral.selector);
        diamond.combineShorts(asset, shortRecords);
    }

    //////Short Linking, Ordering//////
    function testShortLinkingBidThenShortUnique() public {
        // Partial Fill 1/2
        fundLimitBidOpt(1 ether, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(1 ether, DEFAULT_AMOUNT.mulU88(3 ether), sender);
        checkShortLinking(Constants.SHORT_STARTING_ID);
    }

    function testShortLinkingBidThenShortNonUnique() public {
        makeShorts();
        // Partial Fill 1/2
        fundLimitBidOpt(1 ether, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(1 ether, DEFAULT_AMOUNT.mulU88(3 ether), sender);
        checkShortLinking(Constants.SHORT_STARTING_ID + 3);
    }

    function testShortLinkingShortUniqueThenBid() public {
        // Temp workaround to pass correct shortHintId
        fundLimitBidOpt(1 ether, DEFAULT_AMOUNT, receiver);
        vm.prank(receiver);
        cancelBid(100);
        // Partial Fill 1/2
        fundLimitShortOpt(1 ether, DEFAULT_AMOUNT.mulU88(3 ether), sender);
        fundLimitBidOpt(1 ether, DEFAULT_AMOUNT, receiver);
        checkShortLinking(Constants.SHORT_STARTING_ID);
    }

    function testShortLinkingShortNonUniqueThenBid() public {
        makeShorts();
        // Partial Fill 1/2
        fundLimitShortOpt(1 ether, DEFAULT_AMOUNT.mulU88(3 ether), sender);
        fundLimitBidOpt(1 ether, DEFAULT_AMOUNT, receiver);
        checkShortLinking(Constants.SHORT_STARTING_ID + 3);
    }

    function testShortLinkingCancelShortOrderResetId() public {
        fundLimitBidOpt(1 ether, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(1 ether, DEFAULT_AMOUNT.mulU88(3 ether), sender);
        STypes.Order[] memory shortsUnfilled = getShorts();
        assertEq(shortsUnfilled[0].shortRecordId, Constants.SHORT_STARTING_ID);

        vm.prank(sender);
        cancelShort(101);
        shortsUnfilled = getShorts();
        assertEq(shortsUnfilled.length, 0);

        fundLimitShortOpt(1 ether, DEFAULT_AMOUNT, sender);
        shortsUnfilled = getShorts();
        assertEq(shortsUnfilled[0].shortRecordId, 0);

        assertEq(diamond.getAssetStruct(asset).ercDebt, getTotalErc());
    }

    function testShortLinkingCancelShortOrderWhenRecordPartialFill() public {
        fundLimitBidOpt(1 ether, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(1 ether, DEFAULT_AMOUNT.mulU88(3 ether), sender);
        STypes.ShortRecord memory short = getShortRecord(sender, 100);
        assertTrue(short.status == SR.PartialFill);

        vm.prank(sender);
        cancelShort(101);
        short = getShortRecord(sender, Constants.SHORT_STARTING_ID);
        assertTrue(short.status == SR.FullyFilled);
        assertEq(diamond.getAssetStruct(asset).ercDebt, getTotalErc());
    }

    function testShortLinkingCancelShortOrderWhenRecordCancelled() public {
        fundLimitBidOpt(1 ether, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(1 ether, DEFAULT_AMOUNT.mulU88(3 ether), sender);

        STypes.ShortRecord memory short =
            getShortRecord(sender, Constants.SHORT_STARTING_ID);
        assertTrue(short.status == SR.PartialFill);

        createAsk(
            DEFAULT_PRICE,
            DEFAULT_AMOUNT,
            Constants.LIMIT_ORDER,
            badOrderHintArray,
            receiver
        );
        exitShort(Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT, 1 ether, sender);
        short = getShortRecord(sender, Constants.SHORT_STARTING_ID);
        assertTrue(short.status == SR.Cancelled);

        vm.prank(sender);
        cancelShort(101);
        short = getShortRecord(sender, Constants.SHORT_STARTING_ID);
        assertTrue(short.status == SR.Cancelled);
        assertEq(short.prevId, Constants.HEAD);
        assertEq(diamond.getAssetStruct(asset).ercDebt, getTotalErc());
    }

    function testShortLinkingWhenRecordCancelled() public {
        fundLimitBidOpt(1 ether, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(1 ether, DEFAULT_AMOUNT.mulU88(3 ether), sender);

        STypes.ShortRecord memory short =
            getShortRecord(sender, Constants.SHORT_STARTING_ID);
        assertTrue(short.status == SR.PartialFill);

        createAsk(
            DEFAULT_PRICE,
            DEFAULT_AMOUNT,
            Constants.LIMIT_ORDER,
            badOrderHintArray,
            receiver
        );
        exitShort(Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT, 1 ether, sender);
        short = getShortRecord(sender, Constants.SHORT_STARTING_ID);
        assertTrue(short.status == SR.Cancelled);

        fundLimitBidOpt(1 ether, DEFAULT_AMOUNT.mulU88(2 ether), receiver);
        short = getShortRecord(sender, Constants.SHORT_STARTING_ID);
        assertTrue(short.status == SR.FullyFilled);
        assertEq(short.collateral, DEFAULT_AMOUNT.mulU88(12 ether));
        assertEq(short.ercDebt, DEFAULT_AMOUNT.mulU88(2 ether));
        assertEq(diamond.getAssetStruct(asset).ercDebt, getTotalErc());
    }

    function testRecycleShortRecordOrder012() public {
        recycleShortRecordOrder(
            Constants.SHORT_STARTING_ID,
            Constants.SHORT_STARTING_ID + 1,
            Constants.SHORT_STARTING_ID + 2
        );
    }

    function testRecycleShortRecordOrder021() public {
        recycleShortRecordOrder(
            Constants.SHORT_STARTING_ID,
            Constants.SHORT_STARTING_ID + 2,
            Constants.SHORT_STARTING_ID + 1
        );
    }

    function testRecycleShortRecordOrder102() public {
        recycleShortRecordOrder(
            Constants.SHORT_STARTING_ID + 1,
            Constants.SHORT_STARTING_ID,
            Constants.SHORT_STARTING_ID + 2
        );
    }

    function testRecycleShortRecordOrder120() public {
        recycleShortRecordOrder(
            Constants.SHORT_STARTING_ID + 1,
            Constants.SHORT_STARTING_ID + 2,
            Constants.SHORT_STARTING_ID
        );
    }

    function testRecycleShortRecordOrder201() public {
        recycleShortRecordOrder(
            Constants.SHORT_STARTING_ID + 2,
            Constants.SHORT_STARTING_ID,
            Constants.SHORT_STARTING_ID + 1
        );
    }

    function testRecycleShortRecordOrder210() public {
        recycleShortRecordOrder(
            Constants.SHORT_STARTING_ID + 2,
            Constants.SHORT_STARTING_ID + 1,
            Constants.SHORT_STARTING_ID
        );
    }

    //Test reset flagShort from partial exitShort
    function createAndFlagShort(uint8 exitType) public {
        prepareExitShort(exitType);
        _setETH(2666 ether);

        STypes.ShortRecord memory shortRecord =
            getShortRecord(sender, Constants.SHORT_STARTING_ID);
        assertEq(shortRecord.flaggerId, 0);
        assertEq(diamond.getFlagger(shortRecord.flaggerId), address(0));

        vm.prank(receiver);
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID, Constants.HEAD);
        shortRecord = getShortRecord(sender, Constants.SHORT_STARTING_ID);
        assertEq(shortRecord.flaggerId, 1);
        assertEq(diamond.getFlagger(shortRecord.flaggerId), receiver);

        //@dev set price to get healthy c-ratio again
        _setETH(4000 ether);
    }

    function testResetFlagShortPartialExitShortPrimary() public {
        createAndFlagShort({exitType: PRIMARY});

        uint88 partialAmt = DEFAULT_AMOUNT / 2;
        exitShort(Constants.SHORT_STARTING_ID, partialAmt, DEFAULT_PRICE, sender);

        STypes.ShortRecord memory shortRecord =
            getShortRecord(sender, Constants.SHORT_STARTING_ID);
        assertEq(shortRecord.flaggerId, 0);
        assertEq(diamond.getFlagger(shortRecord.flaggerId), address(0));
    }

    function testResetFlagShortPartialExitShortErcEscrowed() public {
        createAndFlagShort({exitType: ERC_ESCROWED});

        uint88 partialAmt = DEFAULT_AMOUNT / 2;
        exitShortErcEscrowed(Constants.SHORT_STARTING_ID, partialAmt, sender);

        STypes.ShortRecord memory shortRecord = getShortRecord(sender, 100);
        assertEq(shortRecord.flaggerId, 0);
        assertEq(diamond.getFlagger(shortRecord.flaggerId), address(0));
    }

    function testResetFlagShortPartialExitShortWallet() public {
        createAndFlagShort({exitType: WALLET});

        uint88 partialAmt = DEFAULT_AMOUNT / 2;
        exitShortWallet(Constants.SHORT_STARTING_ID, partialAmt, sender);

        STypes.ShortRecord memory shortRecord =
            getShortRecord(sender, Constants.SHORT_STARTING_ID);
        assertEq(shortRecord.flaggerId, 0);
        assertEq(diamond.getFlagger(shortRecord.flaggerId), address(0));
    }

    function test_GetTokenID() public {
        assertEq(diamond.getTokenId(), 1);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        assertEq(diamond.getTokenId(), 1);
        vm.prank(sender);
        diamond.mintNFT(asset, Constants.SHORT_STARTING_ID);
        assertEq(diamond.getTokenId(), 2);

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        assertEq(diamond.getTokenId(), 2);
        vm.prank(sender);
        diamond.mintNFT(asset, Constants.SHORT_STARTING_ID + 1);
        assertEq(diamond.getTokenId(), 3);

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        assertEq(diamond.getTokenId(), 3);
        vm.prank(sender);
        diamond.mintNFT(asset, Constants.SHORT_STARTING_ID + 2);
        assertEq(diamond.getTokenId(), 4);
    }
}
