// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.21;

import {U256, Math128, U88} from "contracts/libraries/PRBMathHelper.sol";

import {Constants} from "contracts/libraries/Constants.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {O, F, SR, STypes} from "contracts/libraries/DataTypes.sol";

import {OBFixture} from "test/utils/OBFixture.sol";
import {MarginCallHelper} from "test/utils/MarginCallHelper.sol";

// import {console} from "contracts/libraries/console.sol";

contract MarginCallFlagShortTest is MarginCallHelper {
    using U256 for uint256;
    using Math128 for uint128;
    using U88 for uint88;

    function setUp() public override {
        super.setUp();
    }

    function test_FlagShort16HrsPastReset() public {
        flagShortAndSkipTime(SIXTEEN_HRS_PLUS); //16hrs 1 second
        vm.prank(extra);
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID, Constants.HEAD);
        //reset to time of call. Minus 1 to account for the skip(1) in Obfixture's createMarket
        checkFlaggerAndUpdatedAt({
            _shorter: sender,
            _flaggerId: 1,
            _updatedAt: diamond.getOffsetTimeHours()
        });
    }

    function liquidateAndCheckShortRecordStatus(address caller, uint256 timeToSkip)
        public
    {
        vm.prank(caller);
        diamond.liquidate(
            asset, sender, Constants.SHORT_STARTING_ID, shortHintArrayStorage
        );

        if (timeToSkip == SIXTEEN_HRS_PLUS) {
            //resets - beyond window
            checkFlaggerAndUpdatedAt({
                _shorter: sender,
                _flaggerId: 0,
                _updatedAt: diamond.getOffsetTimeHours()
            });
            assertSR(
                getShortRecord(sender, Constants.SHORT_STARTING_ID).status, SR.FullyFilled
            );
        } else {
            assertSR(
                getShortRecord(sender, Constants.SHORT_STARTING_ID).status, SR.Cancelled
            );
        }
    }

    function test_FlagShortLiquidate10Hrs() public {
        flagShortAndSkipTime({timeToSkip: TEN_HRS_PLUS}); //10hrs 1 second
        liquidateAndCheckShortRecordStatus({caller: receiver, timeToSkip: TEN_HRS_PLUS});
    }

    function test_FlagShortLiquidate12HrsflaggerCalls() public {
        flagShortAndSkipTime({timeToSkip: TWELVE_HRS_PLUS}); //set 12 hrs 1 second
        liquidateAndCheckShortRecordStatus({caller: receiver, timeToSkip: TWELVE_HRS_PLUS});
    }

    function test_FlagShortLiquidate12HrsNonflaggerCalls() public {
        flagShortAndSkipTime({timeToSkip: TWELVE_HRS_PLUS}); //set 12 hrs 1 second
        liquidateAndCheckShortRecordStatus({caller: extra, timeToSkip: TWELVE_HRS_PLUS});
    }

    function test_FlagShortLiquidate16HrsReset() public {
        flagShortAndSkipTime({timeToSkip: SIXTEEN_HRS_PLUS}); //set 16 hrs 1 second
        liquidateAndCheckShortRecordStatus({caller: extra, timeToSkip: SIXTEEN_HRS_PLUS});
    }

    function createAndFlagShort() public {
        //create first short
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        STypes.ShortRecord memory shortRecord =
            diamond.getShortRecord(asset, sender, Constants.SHORT_STARTING_ID);

        assertEq(diamond.getFlaggerIdCounter(), 1);
        assertEq(shortRecord.flaggerId, 0);
        assertEq(diamond.getFlagger(shortRecord.flaggerId), address(0));

        //flag first short
        skip(2 hours);
        setETH(2500 ether);
        vm.prank(extra);
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID, Constants.HEAD);
        shortRecord = diamond.getShortRecord(asset, sender, Constants.SHORT_STARTING_ID);

        assertEq(diamond.getFlaggerIdCounter(), 2);
        assertEq(shortRecord.flaggerId, 1);
        assertEq(diamond.getFlagger(shortRecord.flaggerId), extra);
    }

    function checkShortRecordAfterReset() public {
        STypes.ShortRecord memory shortRecord =
            diamond.getShortRecord(asset, sender, Constants.SHORT_STARTING_ID);

        assertEq(diamond.getFlaggerIdCounter(), 2);
        assertEq(shortRecord.flaggerId, 0);
        assertEq(diamond.getFlagger(shortRecord.flaggerId), address(0));
    }

    function flagShortAgainAfterReset() public {
        setETH(1000 ether);
        vm.prank(extra);
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID, Constants.HEAD);
        STypes.ShortRecord memory shortRecord =
            diamond.getShortRecord(asset, sender, Constants.SHORT_STARTING_ID);

        // @dev check that ids were recycled
        assertEq(diamond.getFlaggerIdCounter(), 2);
        assertEq(shortRecord.flaggerId, 1);
        assertEq(diamond.getFlagger(shortRecord.flaggerId), extra);
    }

    function test_FlagShort_FlaggerId() public {
        //create first short
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        STypes.ShortRecord memory shortRecord =
            diamond.getShortRecord(asset, sender, Constants.SHORT_STARTING_ID);

        assertEq(diamond.getFlaggerIdCounter(), 1);
        assertEq(shortRecord.flaggerId, 0);
        assertEq(diamond.getFlagger(shortRecord.flaggerId), address(0));

        //flag first short
        setETH(2500 ether);
        vm.prank(extra);
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID, Constants.HEAD);
        shortRecord = diamond.getShortRecord(asset, sender, Constants.SHORT_STARTING_ID);

        assertEq(diamond.getFlaggerIdCounter(), 2);
        assertEq(shortRecord.flaggerId, 1);
        assertEq(diamond.getFlagger(shortRecord.flaggerId), extra);

        //reset
        setETH(4000 ether);

        //create another short
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        shortRecord =
            diamond.getShortRecord(asset, sender, Constants.SHORT_STARTING_ID + 1);

        assertEq(diamond.getFlaggerIdCounter(), 2);
        assertEq(shortRecord.flaggerId, 0);
        assertEq(diamond.getFlagger(shortRecord.flaggerId), address(0));

        //flag second short
        setETH(2500 ether);
        vm.prank(extra);
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID + 1, Constants.HEAD);
        shortRecord =
            diamond.getShortRecord(asset, sender, Constants.SHORT_STARTING_ID + 1);

        assertEq(diamond.getFlaggerIdCounter(), 2);
        assertEq(shortRecord.flaggerId, 1);
        assertEq(diamond.getFlagger(shortRecord.flaggerId), extra);
    }

    function test_FlagShort_FlaggerId_Recycling_AfterIncreaseCollateral() public {
        createAndFlagShort();

        depositEthAndPrank(sender, 1 ether);
        increaseCollateral(Constants.SHORT_STARTING_ID, 1 ether);

        checkShortRecordAfterReset();
        flagShortAgainAfterReset();
    }

    function test_FlagShort_FlaggerId_Recycling_AfterPartialExitShortPrimary() public {
        createAndFlagShort();

        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        //@dev re-set eth to prevent stale oracle error
        setETH(2500 ether);
        uint88 partialAmt = DEFAULT_AMOUNT / 2;
        exitShort(Constants.SHORT_STARTING_ID, partialAmt, DEFAULT_PRICE, sender);

        checkShortRecordAfterReset();
        flagShortAgainAfterReset();
    }

    function test_FlagShort_FlaggerId_Recycling_AfterPartialExitShortWallet() public {
        createAndFlagShort();

        uint88 partialAmt = DEFAULT_AMOUNT / 2;
        vm.prank(_diamond);
        token.mint(sender, partialAmt);
        vm.prank(sender);
        token.increaseAllowance(_diamond, partialAmt);
        exitShortWallet(Constants.SHORT_STARTING_ID, partialAmt, sender);

        checkShortRecordAfterReset();
        flagShortAgainAfterReset();
    }

    function test_FlagShort_FlaggerId_Recycling_ResetAfter16HrsPass() public {
        createAndFlagShort();

        skip(SIXTEEN_HRS_PLUS);
        //@dev reset eth to prevent oracle price stale errors when "liquidating"
        setETH(2500 ether);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        //@dev try (and fail) to liquidate in order to reset the flag
        liquidate(sender, Constants.SHORT_STARTING_ID, extra);

        checkShortRecordAfterReset();
        flagShortAgainAfterReset();
    }

    function test_FlagSort_SetFlaggerScenarios_FirstTimeFlagger_Increment() public {
        createAndFlagShort();
        STypes.ShortRecord memory shortRecord =
            diamond.getShortRecord(asset, sender, Constants.SHORT_STARTING_ID);
        assertEq(diamond.getFlaggerIdCounter(), 2);
        assertEq(shortRecord.flaggerId, 1);
        assertEq(diamond.getFlagger(shortRecord.flaggerId), extra);
    }

    function test_FlagSort_SetFlaggerScenarios_FirstTimeFlagger_UseFlaggerHint() public {
        createAndFlagShort();

        STypes.ShortRecord memory shortRecord =
            diamond.getShortRecord(asset, sender, Constants.SHORT_STARTING_ID);
        assertEq(diamond.getFlaggerIdCounter(), 2);
        assertEq(shortRecord.flaggerId, 1);
        assertEq(diamond.getFlagger(shortRecord.flaggerId), extra);

        //@dev reset shortRecord2 via increase collateral
        depositEthAndPrank(sender, 1 ether);
        increaseCollateral(Constants.SHORT_STARTING_ID, 1 ether);
        skip(TEN_HRS_PLUS);

        //@dev make second short and flag as somebody else
        setETH(4000 ether);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        setETH(2500 ether);

        vm.prank(address(100));
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID + 1, 1);

        assertEq(diamond.getFlaggerIdCounter(), 2);
        shortRecord = diamond.getShortRecord(asset, sender, Constants.SHORT_STARTING_ID);
        assertEq(shortRecord.flaggerId, 0);
        assertEq(diamond.getFlagger(shortRecord.flaggerId), address(0));

        STypes.ShortRecord memory shortRecord2 =
            diamond.getShortRecord(asset, sender, Constants.SHORT_STARTING_ID + 1);
        assertEq(shortRecord2.flaggerId, 1);
        assertEq(diamond.getFlagger(shortRecord2.flaggerId), address(100));
    }

    function test_Revert_FlagSort_SetFlaggerScenarios_InvalidFlaggerHint() public {
        createAndFlagShort();
        STypes.ShortRecord memory shortRecord =
            diamond.getShortRecord(asset, sender, Constants.SHORT_STARTING_ID);
        assertEq(diamond.getFlaggerIdCounter(), 2);
        assertEq(shortRecord.flaggerId, 1);
        assertEq(diamond.getFlagger(shortRecord.flaggerId), extra);

        //@dev make second short and flag as somebody else
        setETH(4000 ether);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        setETH(2500 ether);
        diamond.setFlaggerIdCounter(type(uint16).max);

        vm.prank(address(100));
        vm.expectRevert(Errors.InvalidFlaggerHint.selector);
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID + 1, 2);
    }

    function test_Revert_FlagSort_SetFlaggerScenarios_FlaggerHintCounterMax() public {
        diamond.setFlaggerIdCounter(type(uint16).max);

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        setETH(2500 ether);

        vm.prank(address(100));
        vm.expectRevert(Errors.InvalidFlaggerHint.selector);
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID, Constants.HEAD);
    }

    function test_FlagSort_SetFlaggerScenarios_ExistingFlagger() public {
        createAndFlagShort();
        STypes.ShortRecord memory shortRecord =
            diamond.getShortRecord(asset, sender, Constants.SHORT_STARTING_ID);
        assertEq(diamond.getFlaggerIdCounter(), 2);
        assertEq(shortRecord.flaggerId, 1);
        assertEq(diamond.getFlagger(shortRecord.flaggerId), extra);

        //@dev make second short and flag as somebody else
        setETH(4000 ether);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        setETH(2500 ether);

        vm.prank(extra);
        //@dev ignores flaggerHint
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID + 1, 0);
    }

    //Test resetting flag info after increasing collateral
    function test_ResetFlagInfoAfterIncreaseCollateral() public {
        uint256 flagged = diamond.getOffsetTimeHours();
        flagShortAndSkipTime({timeToSkip: TEN_HRS_PLUS});
        checkFlaggerAndUpdatedAt({_shorter: sender, _flaggerId: 1, _updatedAt: flagged});

        depositEthAndPrank(sender, 1 ether);
        increaseCollateral(Constants.SHORT_STARTING_ID, 0.01 ether);

        checkFlaggerAndUpdatedAt({
            _shorter: sender,
            _flaggerId: 0,
            _updatedAt: diamond.getOffsetTimeHours()
        });
    }

    function test_FlagShort_PersistentFlaggerIdForAssetUser() public {
        createAndFlagShort();

        //unflag
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        uint88 partialAmt = DEFAULT_AMOUNT / 2;
        exitShort(Constants.SHORT_STARTING_ID, partialAmt, DEFAULT_PRICE, sender);

        STypes.ShortRecord memory shortRecord =
            diamond.getShortRecord(asset, sender, Constants.SHORT_STARTING_ID);

        //@dev flagger for flaggerId == 1 is still extra
        assertEq(diamond.getFlaggerIdCounter(), 2);
        assertEq(shortRecord.flaggerId, 0);
        assertEq(diamond.getFlagger(1), extra);

        // flag another short
        setETH(4000 ether);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        setETH(2500 ether);
        vm.prank(extra);
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID + 1, Constants.HEAD);
        shortRecord =
            diamond.getShortRecord(asset, sender, Constants.SHORT_STARTING_ID + 1);

        // @dev extra does not get new flaggerId because they flagged before
        assertEq(diamond.getFlaggerIdCounter(), 2);
        assertEq(shortRecord.flaggerId, 1);
        assertEq(diamond.getFlagger(shortRecord.flaggerId), extra);
    }
}
