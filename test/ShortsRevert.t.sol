// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {stdError} from "forge-std/StdError.sol";
import {U256, U88, U80} from "contracts/libraries/PRBMathHelper.sol";

import {Constants} from "contracts/libraries/Constants.sol";
import {LibOrders} from "contracts/libraries/LibOrders.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {MTypes, STypes, O} from "contracts/libraries/DataTypes.sol";

import {OBFixture} from "test/utils/OBFixture.sol";
// import {console} from "contracts/libraries/console.sol";

contract ShortsRevertTest is OBFixture {
    uint16 private lastShortId;

    using U256 for uint256;
    using U88 for uint88;
    using U80 for uint80;

    function setUp() public override {
        super.setUp();
    }

    function makeShorts() public {
        fundLimitBidOpt(1 ether, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(1 ether, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(2 ether, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(2 ether, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(3 ether, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(3 ether, DEFAULT_AMOUNT, sender);

        r.ercEscrowed = DEFAULT_AMOUNT * 3;

        assertStruct(receiver, r);
        assertStruct(sender, s);
    }

    function testCannotExitWithNoShorts() public {
        //have to set here like this because the revert will incorrectly catch the getLastShortId()
        vm.prank(sender);
        vm.expectRevert(Errors.InvalidShortId.selector);
        diamond.exitShort(
            asset, 100, DEFAULT_AMOUNT, DEFAULT_PRICE, shortHintArrayStorage
        );
    }

    function test_RevertCombineMaxShorts() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, 300_000_000 ether, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, 300_000_000 ether, sender);
        fundLimitBidOpt(DEFAULT_PRICE, 300_000_000 ether, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, 300_000_000 ether, sender);

        uint8[] memory shortRecords = new uint8[](3);
        shortRecords[0] = Constants.SHORT_STARTING_ID;
        shortRecords[1] = Constants.SHORT_STARTING_ID + 1;
        shortRecords[2] = Constants.SHORT_STARTING_ID + 2;
        vm.expectRevert(stdError.arithmeticError);
        vm.prank(sender);
        diamond.combineShorts(asset, shortRecords);
    }

    function testCannotExitWithInvalidIdLow() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        //have to set here like this because the revert will incorrectly catch the getLastShortId()
        vm.prank(sender);
        vm.expectRevert(Errors.InvalidShortId.selector);
        diamond.exitShort(asset, 99, DEFAULT_AMOUNT, DEFAULT_PRICE, shortHintArrayStorage);
    }

    function testExitShortFirstElement() public {
        makeShorts();
        //create ask to allow exit short
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        STypes.ShortRecord memory shortRecord =
            getShortRecord(sender, Constants.SHORT_STARTING_ID);
        assertGt(shortRecord.collateral, 0);
        assertEq(getShortRecordCount(sender), 3);
        exitShort(Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT, DEFAULT_PRICE, sender);
        assertEq(getShortRecordCount(sender), 2);
        //have to set here like this because the revert will incorrectly catch the getLastShortId()
        vm.prank(sender);
        vm.expectRevert(Errors.InvalidShortId.selector);
        diamond.exitShort(
            asset,
            Constants.SHORT_STARTING_ID,
            DEFAULT_AMOUNT,
            DEFAULT_PRICE,
            shortHintArrayStorage
        );
    }

    function testExitShortLastElement() public {
        makeShorts();
        //create ask to allow exit short
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        STypes.ShortRecord memory shortRecord =
            getShortRecord(sender, Constants.SHORT_STARTING_ID + 2);
        assertGt(shortRecord.collateral, 0);
        assertEq(getShortRecordCount(sender), 3);
        exitShort(Constants.SHORT_STARTING_ID + 2, DEFAULT_AMOUNT, DEFAULT_PRICE, sender);
        assertEq(getShortRecordCount(sender), 2);
        //have to set here like this because the revert will incorrectly catch the getLastShortId()
        vm.prank(sender);
        vm.expectRevert(Errors.InvalidShortId.selector);
        diamond.exitShort(
            asset,
            Constants.SHORT_STARTING_ID + 2,
            DEFAULT_AMOUNT,
            DEFAULT_PRICE,
            shortHintArrayStorage
        );
    }

    function testExitShortMiddleElement() public {
        makeShorts();
        //create ask to allow exit short
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        STypes.ShortRecord memory shortRecord =
            getShortRecord(sender, Constants.SHORT_STARTING_ID + 1);
        assertGt(shortRecord.collateral, 0);
        assertEq(getShortRecordCount(sender), 3);
        exitShort(Constants.SHORT_STARTING_ID + 1, DEFAULT_AMOUNT, DEFAULT_PRICE, sender);
        assertEq(getShortRecordCount(sender), 2);
        //have to set here like this because the revert will incorrectly catch the getLastShortId()
        vm.prank(sender);
        vm.expectRevert(Errors.InvalidShortId.selector);
        diamond.exitShort(
            asset,
            Constants.SHORT_STARTING_ID + 1,
            DEFAULT_AMOUNT,
            DEFAULT_PRICE,
            shortHintArrayStorage
        );
    }

    function testCantExitShortTwice() public {
        fundLimitBidOpt(1 ether, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(1 ether, DEFAULT_AMOUNT, sender);

        fundLimitBidOpt(1 ether, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(1 ether, DEFAULT_AMOUNT, sender);

        assertEq(getShortRecordCount(sender), 2);

        fundLimitAskOpt(1 ether, DEFAULT_AMOUNT, receiver);

        // First Exit
        exitShort(Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT, 1 ether, sender);
        assertEq(getShortRecordCount(sender), 1);
        // Second Exits
        vm.prank(sender);
        vm.expectRevert(Errors.InvalidShortId.selector);
        diamond.exitShort(
            asset,
            Constants.SHORT_STARTING_ID,
            DEFAULT_AMOUNT,
            DEFAULT_PRICE,
            shortHintArrayStorage
        );
        vm.expectRevert(Errors.InvalidShortId.selector);
        vm.prank(extra);
        diamond.liquidate(
            asset, sender, Constants.SHORT_STARTING_ID, shortHintArrayStorage
        );
        // Second Exits Wallet
        vm.prank(_diamond);
        token.mint(sender, 1 ether);
        vm.prank(sender);
        token.increaseAllowance(_diamond, 1 ether);
        vm.expectRevert(Errors.InvalidShortId.selector);
        exitShortWallet(Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT, sender);
        vm.expectRevert(Errors.MarginCallSecondaryNoValidShorts.selector);
        liquidateWallet(sender, Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT, receiver);
        // Second Exits Escrowed
        depositUsd(sender, 1 ether);
        vm.expectRevert(Errors.InvalidShortId.selector);
        exitShortErcEscrowed(Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT, sender);
        vm.expectRevert(Errors.MarginCallSecondaryNoValidShorts.selector);
        liquidateErcEscrowed(
            sender, Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT, receiver
        );
        // Combine Short

        vm.expectRevert(Errors.InvalidShortId.selector);
        combineShorts({
            id1: Constants.SHORT_STARTING_ID,
            id2: Constants.SHORT_STARTING_ID + 1
        });
    }

    function testExitBuyBackTooHigh() public {
        makeShorts();
        STypes.ShortRecord memory shortRecord =
            getShortRecord(sender, Constants.SHORT_STARTING_ID + 1);
        //create ask to allow exit short
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(2 ether), receiver);
        assertGt(shortRecord.collateral, 0);
        //have to set here like this because the revert will incorrectly catch the getLastShortId()
        depositEthAndPrank(sender, DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT) * 2);
        vm.expectRevert(Errors.InvalidBuyback.selector);
        diamond.exitShort(
            asset,
            Constants.SHORT_STARTING_ID,
            DEFAULT_AMOUNT.mulU88(2 ether),
            DEFAULT_PRICE,
            shortHintArrayStorage
        );
    }

    function testExitBidEthTooHigh() public {
        makeShorts();
        STypes.ShortRecord memory shortRecord =
            getShortRecord(sender, Constants.SHORT_STARTING_ID + 1);
        //create ask to allow exit short
        fundLimitAskOpt(11 ether, DEFAULT_AMOUNT, receiver);
        assertGt(shortRecord.collateral, 0);
        //have to set here like this because the revert will incorrectly catch the getLastShortId()

        depositEthAndPrank(sender, 13 ether);
        vm.expectRevert(Errors.InsufficientCollateral.selector);
        diamond.exitShort(
            asset,
            Constants.SHORT_STARTING_ID,
            DEFAULT_AMOUNT,
            13 ether,
            shortHintArrayStorage
        );
    }

    //@dev lowestAskKey == Constants.TAIL && startingShortId == Constants.HEAD
    function testExitShortPriceTooLowScenario1() public {
        makeShorts();
        depositEthAndPrank(sender, Constants.MIN_DEPOSIT);
        vm.expectRevert(Errors.ExitShortPriceTooLow.selector);
        diamond.exitShort(
            asset,
            Constants.SHORT_STARTING_ID,
            DEFAULT_AMOUNT,
            1 wei,
            shortHintArrayStorage
        );
    }

    //@dev lowestAskKey == Constants.TAIL && s.shorts[e.asset][startingShortId].price > price
    function testExitShortPriceTooLowScenario2() public {
        makeShorts();
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        depositEthAndPrank(sender, Constants.MIN_DEPOSIT);
        vm.expectRevert(Errors.ExitShortPriceTooLow.selector);
        diamond.exitShort(
            asset,
            Constants.SHORT_STARTING_ID,
            DEFAULT_AMOUNT,
            1 wei,
            shortHintArrayStorage
        );
    }

    //@dev s.asks[e.asset][lowestAskKey].price > price && startingShortId == Constants.HEAD);
    function testExitShortPriceTooLowScenario3() public {
        makeShorts();
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        depositEthAndPrank(sender, Constants.MIN_DEPOSIT);
        vm.expectRevert(Errors.ExitShortPriceTooLow.selector);
        diamond.exitShort(
            asset,
            Constants.SHORT_STARTING_ID,
            DEFAULT_AMOUNT,
            1 wei,
            shortHintArrayStorage
        );
    }

    //dev s.asks[e.asset][lowestAskKey].price > price && s.shorts[e.asset][startingShortId].price > price);
    function testExitShortPriceTooLowScenario4() public {
        makeShorts();
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        depositEthAndPrank(sender, Constants.MIN_DEPOSIT);
        vm.expectRevert(Errors.ExitShortPriceTooLow.selector);
        diamond.exitShort(
            asset,
            Constants.SHORT_STARTING_ID,
            DEFAULT_AMOUNT,
            1 wei,
            shortHintArrayStorage
        );
    }

    //@dev Only allow partial exit if the CR is same or better than before.
    //@dev Even undercollateralized (< minCR) can be partially exitted if this condition is met

    function test_Revert_PostExitCRLtPreExitCR() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        //set price to black swan levels
        setETH(400 ether);
        STypes.ShortRecord memory shortRecord =
            getShortRecord(sender, Constants.SHORT_STARTING_ID);
        uint256 beforeExitCR = diamond.getCollateralRatio(asset, shortRecord);
        assertGt(diamond.getAssetNormalizedStruct(asset).minimumCR, beforeExitCR);

        uint80 price = DEFAULT_PRICE * 10;
        //buyback at a higher lowest Ask price
        fundLimitAskOpt(price, DEFAULT_AMOUNT.mulU88(0.5 ether), receiver);

        //try reverting
        vm.prank(sender);
        vm.expectRevert(Errors.PostExitCRLtPreExitCR.selector);
        diamond.exitShort(
            asset,
            Constants.SHORT_STARTING_ID,
            DEFAULT_AMOUNT.mulU88(0.5 ether),
            price,
            shortHintArrayStorage
        );

        // try passing
        depositEthAndPrank(sender, DEFAULT_AMOUNT.mulU88(5 ether));
        increaseCollateral(
            Constants.SHORT_STARTING_ID, uint80(DEFAULT_AMOUNT.mulU88(0.001 ether))
        );
        vm.prank(sender);
        diamond.exitShort(
            asset,
            Constants.SHORT_STARTING_ID,
            DEFAULT_AMOUNT.mulU88(0.5 ether),
            price,
            shortHintArrayStorage
        );

        shortRecord = getShortRecord(sender, Constants.SHORT_STARTING_ID);
        uint256 afterExitCR = diamond.getCollateralRatio(asset, shortRecord);
        assertGe(afterExitCR, beforeExitCR);
    }

    //wallet tests
    function testExitWalletBuyBackTooHigh() public {
        makeShorts();
        STypes.ShortRecord memory shortRecord =
            getShortRecord(sender, Constants.SHORT_STARTING_ID + 1);
        assertGt(shortRecord.collateral, 0);

        vm.expectRevert(Errors.InvalidBuyback.selector);
        exitShortWallet(
            Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT.mulU88(2 ether), sender
        );
    }

    function testExitWalletNotEnoughInWallet() public {
        makeShorts();
        STypes.ShortRecord memory shortRecord =
            getShortRecord(sender, Constants.SHORT_STARTING_ID + 1);
        assertGt(shortRecord.collateral, 0);

        vm.expectRevert(Errors.InsufficientWalletBalance.selector);
        exitShortWallet(Constants.SHORT_STARTING_ID + 1, DEFAULT_AMOUNT, sender);
    }

    function testNotEnoughEthToIncreaseCollateral() public {
        makeShorts();
        vm.prank(sender);
        vm.expectRevert(Errors.InsufficientETHEscrowed.selector);
        increaseCollateral(Constants.SHORT_STARTING_ID, 1 wei);
    }

    function testIncreaseCollateralTooMuch() public {
        makeShorts();

        depositEthAndPrank(sender, 1 ether);
        vm.expectRevert(Errors.CollateralHigherThanMax.selector);
        increaseCollateral(Constants.SHORT_STARTING_ID, 1 ether);
    }

    function testCantDecreaseCollateralBeyondZero() public {
        makeShorts();

        vm.prank(sender);
        vm.expectRevert(Errors.InsufficientCollateral.selector);
        decreaseCollateral(Constants.SHORT_STARTING_ID, 25000 ether);
    }

    function testCantDecreaseCollateralBelowCRatio() public {
        makeShorts();

        vm.prank(sender);
        vm.expectRevert(Errors.CollateralLowerThanMin.selector);
        decreaseCollateral(Constants.SHORT_STARTING_ID, 23999 ether);
    }

    function testExitShortWithZero() public {
        fundLimitBidOpt(1 ether, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(1 ether, DEFAULT_AMOUNT, sender);
        //have to set here like this because the revert will incorrectly catch the getLastShortId()
        vm.prank(sender);
        vm.expectRevert(Errors.InvalidBuyback.selector);
        diamond.exitShort(
            asset, Constants.SHORT_STARTING_ID, 0, DEFAULT_PRICE, shortHintArrayStorage
        );

        vm.expectRevert(Errors.InvalidBuyback.selector);
        exitShortWallet(Constants.SHORT_STARTING_ID, 0, sender);

        vm.expectRevert(Errors.InvalidBuyback.selector);
        exitShortErcEscrowed(Constants.SHORT_STARTING_ID, 0, sender);
    }

    function testCantexitShortErcEscrowedWhenErcIsTooLow() public {
        fundLimitBidOpt(1 ether, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(1 ether, DEFAULT_AMOUNT, sender);
        vm.expectRevert(Errors.InsufficientERCEscrowed.selector);
        exitShortErcEscrowed(Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT, sender);
    }

    function testCombineShortsOnlyOne() public {
        makeShorts();

        uint8[] memory shortIds = new uint8[](1);
        shortIds[0] = Constants.SHORT_STARTING_ID;
        vm.prank(sender);
        vm.expectRevert(Errors.InsufficientNumberOfShorts.selector);
        diamond.combineShorts(asset, shortIds);
    }

    function testCombineShortsInvalidId() public {
        makeShorts();

        // if non-first element is invalid
        vm.prank(sender);
        vm.expectRevert(Errors.InvalidShortId.selector);
        combineShorts(100, 0);

        // if first element is invalid
        vm.prank(sender);
        vm.expectRevert(Errors.InvalidShortId.selector);
        combineShorts(0, 100);

        // if both are invalid
        vm.prank(sender);
        vm.expectRevert(Errors.InvalidShortId.selector);
        combineShorts(0, 1);
    }

    function testCombineShortsSameId() public {
        makeShorts();

        uint8[] memory shortIds = new uint8[](3);
        shortIds[0] = 100;
        shortIds[1] = 101;
        shortIds[2] = 101;

        vm.prank(sender);
        vm.expectRevert(Errors.InvalidShortId.selector); // same id
        diamond.combineShorts(asset, shortIds);

        shortIds[0] = 100;
        shortIds[1] = 100;
        shortIds[2] = 100;

        vm.prank(sender);
        vm.expectRevert(Errors.InvalidShortId.selector); // same id
        diamond.combineShorts(asset, shortIds);

        shortIds[0] = 101;
        shortIds[1] = 101;
        shortIds[2] = 101;

        vm.prank(sender);
        vm.expectRevert(Errors.InvalidShortId.selector); // same id
        diamond.combineShorts(asset, shortIds);
    }

    function testCannotShortUnderMinimumSize() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        depositEthAndPrank(
            receiver, DEFAULT_PRICE.mulU88(LibOrders.convertCR(initialMargin))
        );
        vm.expectRevert(Errors.OrderUnderMinimumSize.selector);
        diamond.createLimitShort(
            asset,
            DEFAULT_PRICE,
            0.3999 ether,
            badOrderHintArray,
            shortHintArrayStorage,
            initialMargin
        );

        vm.prank(receiver);
        vm.expectRevert(Errors.OrderUnderMinimumSize.selector);
        diamond.createLimitShort(
            asset,
            0.0000001 ether,
            DEFAULT_AMOUNT,
            badOrderHintArray,
            shortHintArrayStorage,
            initialMargin
        );
    }

    //test can't leave behind MIN ETH
    function testCannotExitPrimaryAndLeaveBehindDust() public {
        makeShorts();
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        depositEthAndPrank(sender, DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT) * 2);
        vm.expectRevert(Errors.CannotLeaveDustAmount.selector);
        diamond.exitShort(
            asset,
            Constants.SHORT_STARTING_ID,
            DEFAULT_AMOUNT - 1 wei,
            DEFAULT_PRICE,
            shortHintArrayStorage
        );
    }

    function testCannotExitSecondaryAndLeaveBehindDust() public {
        makeShorts();
        vm.prank(sender);
        vm.expectRevert(Errors.CannotLeaveDustAmount.selector);
        diamond.exitShortWallet(
            asset, Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT - 1 wei
        );
        depositUsdAndPrank(sender, DEFAULT_AMOUNT * 3);
        vm.expectRevert(Errors.CannotLeaveDustAmount.selector);
        diamond.exitShortErcEscrowed(
            asset, Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT - 1 wei
        );
    }

    function test_Revert_AlreadyMinted_PartialFill() public {
        assertEq(diamond.getTokenId(), 1);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT / 2, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        assertEq(diamond.getTokenId(), 1);
        vm.startPrank(sender);
        diamond.mintNFT(asset, Constants.SHORT_STARTING_ID);
        assertEq(diamond.getTokenId(), 2);
        vm.expectRevert(Errors.AlreadyMinted.selector);
        diamond.mintNFT(asset, Constants.SHORT_STARTING_ID);
    }

    function test_Revert_AlreadyMinted_FullyFilled() public {
        assertEq(diamond.getTokenId(), 1);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        assertEq(diamond.getTokenId(), 1);
        vm.startPrank(sender);
        diamond.mintNFT(asset, Constants.SHORT_STARTING_ID);
        assertEq(diamond.getTokenId(), 2);
        vm.expectRevert(Errors.AlreadyMinted.selector);
        diamond.mintNFT(asset, Constants.SHORT_STARTING_ID);
    }

    function test_Revert_InvalidInitialCR_InitialCRLtInitialMargin() public {
        MTypes.OrderHint[] memory orderHintArray =
            diamond.getHintArray(asset, DEFAULT_AMOUNT, O.LimitShort);

        uint16 initialCR = diamond.getAssetStruct(asset).initialMargin - 1 wei;
        vm.expectRevert(Errors.InvalidInitialCR.selector);
        diamond.createLimitShort(
            asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT,
            orderHintArray,
            shortHintArrayStorage,
            initialCR
        );
    }

    function test_Revert_InvalidInitialCR_InitialCRGteCRATIO_MAX() public {
        MTypes.OrderHint[] memory orderHintArray =
            diamond.getHintArray(asset, DEFAULT_AMOUNT, O.LimitShort);

        uint16 initialCR =
            uint16((Constants.CRATIO_MAX * Constants.TWO_DECIMAL_PLACES) / 1 ether);
        vm.expectRevert(Errors.InvalidInitialCR.selector);
        diamond.createLimitShort(
            asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT,
            orderHintArray,
            shortHintArrayStorage,
            initialCR
        );
    }
}
