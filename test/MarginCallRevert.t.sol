// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.21;

import {stdError} from "forge-std/StdError.sol";
import {F} from "contracts/libraries/DataTypes.sol";

import {U256, Math128, U88} from "contracts/libraries/PRBMathHelper.sol";

import {Errors} from "contracts/libraries/Errors.sol";
import {STypes, MTypes, O} from "contracts/libraries/DataTypes.sol";

import {OBFixture} from "test/utils/OBFixture.sol";
import {Constants} from "contracts/libraries/Constants.sol";
import {MarginCallHelper} from "test/utils/MarginCallHelper.sol";
// import {console} from "contracts/libraries/console.sol";

contract MarginCallRevertTest is MarginCallHelper {
    using U256 for uint256;
    using Math128 for uint128;
    using U88 for uint88;

    function setUp() public override {
        super.setUp();
    }

    ///General///
    function testRevertCRatioNotLowEnoughToFlag() public {
        prepareAsk({askPrice: DEFAULT_PRICE, askAmount: DEFAULT_AMOUNT});
        vm.startPrank(receiver);
        vm.expectRevert(Errors.SufficientCollateral.selector);
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID, Constants.HEAD);
    }

    // @dev Testing MarginCall window
    function testRevertCantflagShortSufficientCollateral() public {
        prepareAsk({askPrice: DEFAULT_PRICE, askAmount: DEFAULT_AMOUNT});
        vm.expectRevert(Errors.SufficientCollateral.selector);
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID, Constants.HEAD);
        //No change
        checkFlaggerAndUpdatedAt({_shorter: sender, _flaggerId: 0, _updatedAt: 0});
    }

    function testRevertCantflagShortWhenAlreadyMarked() public {
        flagShortAndSkipTime({timeToSkip: 1 seconds});

        vm.expectRevert(Errors.MarginCallAlreadyFlagged.selector);
        vm.prank(receiver);
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID, Constants.HEAD);

        skipTimeAndSetEth({skipTime: SIXTEEN_HRS_PLUS, ethPrice: 2666 ether});

        vm.startPrank(receiver);
        diamond.liquidate(
            asset, sender, Constants.SHORT_STARTING_ID, shortHintArrayStorage
        ); //reset
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID, Constants.HEAD);
    }

    function testRevertCantFlagSelf() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        _setETH(2666 ether);
        skip(TEN_HRS_PLUS);
        vm.prank(sender);
        vm.expectRevert(Errors.CannotFlagSelf.selector);
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID, Constants.HEAD);
    }

    ///Primary///
    function testRevertCantLiquidateSelf() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        _setETH(2666 ether);
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID, Constants.HEAD);
        skip(TWELVE_HRS_PLUS);
        vm.prank(sender);
        vm.expectRevert(Errors.CannotLiquidateSelf.selector);
        diamond.liquidate(
            asset, sender, Constants.SHORT_STARTING_ID, shortHintArrayStorage
        );
    }

    function testRevertNotFlaggedCantLiquidate() public {
        prepareAsk({askPrice: DEFAULT_PRICE, askAmount: DEFAULT_AMOUNT});
        _setETH(2666 ether);
        vm.startPrank(receiver);
        vm.expectRevert(Errors.ShortNotFlagged.selector);
        diamond.liquidate(
            asset, sender, Constants.SHORT_STARTING_ID, shortHintArrayStorage
        );
    }

    function testRevertNot10HrsAfterMark() public {
        prepareAsk({askPrice: DEFAULT_PRICE, askAmount: DEFAULT_AMOUNT});
        _setETH(2666 ether);
        vm.startPrank(receiver);
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID, Constants.HEAD);
        vm.expectRevert(Errors.MarginCallIneligibleWindow.selector);
        diamond.liquidate(
            asset, sender, Constants.SHORT_STARTING_ID, shortHintArrayStorage
        );
    }

    function testRevert10HrsNotflagger() public {
        prepareAsk({askPrice: DEFAULT_PRICE, askAmount: DEFAULT_AMOUNT});
        _setETH(2666 ether);
        vm.prank(receiver);
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID, Constants.HEAD);
        skipTimeAndSetEth({skipTime: TEN_HRS_PLUS, ethPrice: 2666 ether});
        vm.prank(extra);
        vm.expectRevert(Errors.MarginCallIneligibleWindow.selector);
        diamond.liquidate(
            asset, sender, Constants.SHORT_STARTING_ID, shortHintArrayStorage
        );
        //hits (uint32(block.timestamp) - short.updatedAt > 10 hours && uint32(block.timestamp) - short.updatedAt <= 12 hours)
        skip(7200); //+ 2 more hrs
        diamond.liquidate(
            asset, sender, Constants.SHORT_STARTING_ID, shortHintArrayStorage
        );
    }

    function testRevertCRatioNotLowEnoughToLiquidate() public {
        prepareAsk({askPrice: DEFAULT_PRICE, askAmount: DEFAULT_AMOUNT});
        vm.startPrank(receiver);
        _setETH(666.66 ether); //set to black swan levels
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID, Constants.HEAD);
        _setETH(4000 ether); //reset eth
        skipTimeAndSetEth({skipTime: TEN_HRS_PLUS, ethPrice: 4000 ether});
        vm.expectRevert(Errors.SufficientCollateral.selector);
        diamond.liquidate(
            asset, sender, Constants.SHORT_STARTING_ID, shortHintArrayStorage
        );
    }

    function testRevertNoSellsAtAllToLiquidate() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        _setETH(2666 ether); //price in USD (min eth for liquidation ratio Formula: .0015P = 4 => P = 2666.67
        vm.expectRevert(Errors.NoSells.selector);
        vm.prank(receiver);
        diamond.liquidate(
            asset, sender, Constants.SHORT_STARTING_ID, shortHintArrayStorage
        );
    }

    function testRevertNoSellsToLiquidateShortsUnderOracle() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        //@dev create short that can't be matched
        fundLimitShortOpt(DEFAULT_PRICE - 1 wei, DEFAULT_AMOUNT, sender);
        _setETH(2666 ether); //price in USD (min eth for liquidation ratio Formula: .0015P = 4 => P = 2666.67
        vm.expectRevert(Errors.NoSells.selector);
        vm.prank(receiver);
        diamond.liquidate(
            asset, sender, Constants.SHORT_STARTING_ID, shortHintArrayStorage
        );
    }

    function testRevertlowestSellPriceTooHigh() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        _setETH(2666 ether); //price in USD (min eth for liquidation ratio Formula: .0015P = 4 => P = 2666.67
        fundLimitAskOpt(
            uint80((diamond.getAssetPrice(asset).mul(1.1 ether)) + 1 wei),
            DEFAULT_AMOUNT,
            receiver
        );
        vm.expectRevert(Errors.NoSells.selector);
        vm.prank(receiver);
        diamond.liquidate(
            asset, sender, Constants.SHORT_STARTING_ID, shortHintArrayStorage
        );
    }

    function testRevertlowestSellPriceTooHighShort() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        _setETH(2666 ether); //price in USD (min eth for liquidation ratio Formula: .0015P = 4 => P = 2666.67
        fundLimitShortOpt(
            uint80((diamond.getAssetPrice(asset).mul(1.1 ether)) + 1 wei),
            DEFAULT_AMOUNT,
            receiver
        );
        assertEq(diamond.getAssetStruct(asset).startingShortId, 101);
        vm.expectRevert(Errors.NoSells.selector);
        vm.prank(receiver);
        diamond.liquidate(
            asset, sender, Constants.SHORT_STARTING_ID, shortHintArrayStorage
        );
    }

    function testRevertCantMarginCallTwice() public {
        prepareAsk({askPrice: DEFAULT_PRICE, askAmount: DEFAULT_AMOUNT});
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        depositEth(tapp, DEFAULT_TAPP);
        _setETH(2666 ether);

        vm.startPrank(receiver);
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID, Constants.HEAD);
        skipTimeAndSetEth({skipTime: TEN_HRS_PLUS, ethPrice: 2666 ether});
        diamond.liquidate(
            asset, sender, Constants.SHORT_STARTING_ID, shortHintArrayStorage
        );
        vm.expectRevert(Errors.InvalidShortId.selector);
        diamond.liquidate(
            asset, sender, Constants.SHORT_STARTING_ID, shortHintArrayStorage
        );
    }

    function testRevertBlackSwan() public {
        prepareAsk({askPrice: DEFAULT_PRICE, askAmount: DEFAULT_AMOUNT});
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        _setETH(730 ether); // c-ratio 1.095

        vm.prank(receiver);
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID, Constants.HEAD);
        skipTimeAndSetEth(TEN_HRS_PLUS, 730 ether); //10hrs 1 second
        vm.prank(receiver);
        vm.expectRevert(Errors.CannotSocializeDebt.selector);
        diamond.liquidate(
            asset, sender, Constants.SHORT_STARTING_ID, shortHintArrayStorage
        );
    }

    ///Secondary///
    //ErcEscrowed
    function testRevertCantLiquidateErcEscrowedSelf() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        _setETH(2666 ether);
        vm.expectRevert(Errors.MarginCallSecondaryNoValidShorts.selector);
        liquidateErcEscrowed(sender, Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT, sender);
    }

    function testRevertCantliquidateErcEscrowedCratioTooLow() public {
        prepareAsk({askPrice: DEFAULT_PRICE, askAmount: DEFAULT_AMOUNT});

        _setETH(2666 ether);
        vm.expectRevert(Errors.MarginCallSecondaryNoValidShorts.selector);
        liquidateErcEscrowed(
            sender, Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT, receiver
        );
    }

    function testRevertCantliquidateErcEscrowedNotEnoughERC() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        assertEq(getShortRecordCount(sender), 1);
        //lock up erc for receiver
        createAsk(
            DEFAULT_PRICE,
            DEFAULT_AMOUNT,
            Constants.LIMIT_ORDER,
            badOrderHintArray,
            receiver
        );

        _setETH(999 ether);
        vm.expectRevert(Errors.MarginCallSecondaryNoValidShorts.selector);
        liquidateErcEscrowed(
            sender, Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT, receiver
        );
    }

    //liquidateWallet
    function testRevertCantLiquidateWalletSelf() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        _setETH(2666 ether);
        vm.expectRevert(Errors.MarginCallSecondaryNoValidShorts.selector);
        liquidateWallet(sender, Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT, sender);
    }

    function testRevertCantliquidateWalletCratioTooLow() public {
        prepareAsk({askPrice: DEFAULT_PRICE, askAmount: DEFAULT_AMOUNT});

        _setETH(2666 ether);
        vm.expectRevert(Errors.MarginCallSecondaryNoValidShorts.selector);
        liquidateWallet(sender, Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT, receiver);
    }

    function testLiquidateWalletNotEnoughInWallet() public {
        prepareAsk({askPrice: DEFAULT_PRICE, askAmount: DEFAULT_AMOUNT});
        _setETH(999 ether);

        STypes.ShortRecord memory shortRecord =
            getShortRecord(sender, Constants.SHORT_STARTING_ID);
        assertGt(shortRecord.collateral, 0);

        vm.expectRevert(Errors.MarginCallSecondaryNoValidShorts.selector);
        liquidateWallet(sender, Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT, receiver);
    }

    ///Market Shutdown///
    function shutdownMarket() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        _setETH(700 ether); // c-ratio 1.05
        diamond.shutdownMarket(asset);
    }

    function testShutdownMarketEmpty() public {
        vm.expectRevert(stdError.divisionError);
        diamond.shutdownMarket(asset);
    }

    function testShutdownMarketSufficientCollateral() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        vm.expectRevert(Errors.SufficientCollateral.selector);
        diamond.shutdownMarket(asset);
    }

    function testShutdownMarketAlreadyFrozen() public {
        shutdownMarket();

        vm.expectRevert(Errors.AssetIsFrozen.selector);
        diamond.shutdownMarket(asset);
    }

    function testRedeemErcMarketUnfrozen() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        vm.expectRevert(Errors.AssetIsNotPermanentlyFrozen.selector);
        redeemErc(DEFAULT_AMOUNT, 0, receiver);
        vm.expectRevert(Errors.AssetIsNotPermanentlyFrozen.selector);
        redeemErc(0, DEFAULT_AMOUNT, receiver);
        vm.expectRevert(Errors.AssetIsNotPermanentlyFrozen.selector);
        redeemErc(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
    }

    function testRedeemErcEmptyWallet() public {
        shutdownMarket();

        vm.expectRevert(Errors.InsufficientWalletBalance.selector);
        redeemErc(DEFAULT_AMOUNT, 0, receiver);
    }

    function testRedeemErcEmptyEscrow() public {
        shutdownMarket();

        vm.prank(receiver);
        diamond.withdrawAsset(asset, DEFAULT_AMOUNT);
        vm.expectRevert(stdError.arithmeticError);
        redeemErc(0, DEFAULT_AMOUNT, receiver);
    }
}
