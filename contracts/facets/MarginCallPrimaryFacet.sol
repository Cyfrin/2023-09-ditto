// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U96, U88, U80} from "contracts/libraries/PRBMathHelper.sol";

import {IDiamond} from "interfaces/IDiamond.sol";

import {Errors} from "contracts/libraries/Errors.sol";
import {Events} from "contracts/libraries/Events.sol";
import {STypes, MTypes, SR, OF} from "contracts/libraries/DataTypes.sol";
import {Modifiers} from "contracts/libraries/AppStorage.sol";
import {LibAsset} from "contracts/libraries/LibAsset.sol";
import {LibOrders} from "contracts/libraries/LibOrders.sol";
import {LibOracle} from "contracts/libraries/LibOracle.sol";
import {LibShortRecord} from "contracts/libraries/LibShortRecord.sol";
import {Constants} from "contracts/libraries/Constants.sol";

// import {console} from "contracts/libraries/console.sol";

contract MarginCallPrimaryFacet is Modifiers {
    using LibShortRecord for STypes.ShortRecord;
    using U256 for uint256;
    using U96 for uint96;
    using U88 for uint88;
    using U80 for uint80;

    address private immutable cusd;

    constructor(address _cusd) {
        cusd = _cusd;
    }

    /**
     * @notice Flags short under primaryLiquidationCR to be eligible for liquidation after time has passed
     * @dev Used to flag for primary liquidation method
     *
     * @param asset The market that will be impacted
     * @param shorter Shorter getting liquidated
     * @param id id of short getting liquidated
     * @param flaggerHint Hint ID for gas-optimized update of short flagger
     *
     */
    function flagShort(address asset, address shorter, uint8 id, uint16 flaggerHint)
        external
        isNotFrozen(asset)
        nonReentrant
        onlyValidShortRecord(asset, shorter, id)
    {
        if (msg.sender == shorter) revert Errors.CannotFlagSelf();
        STypes.ShortRecord storage short = s.shortRecords[asset][shorter][id];
        short.updateErcDebt(asset);

        if (
            short.getCollateralRatioSpotPrice(LibOracle.getSavedOrSpotOraclePrice(asset))
                >= LibAsset.primaryLiquidationCR(asset)
        ) {
            revert Errors.SufficientCollateral();
        }

        uint256 adjustedTimestamp = LibOrders.getOffsetTimeHours();

        // check if already flagged
        if (short.flaggerId != 0) {
            uint256 timeDiff = adjustedTimestamp - short.updatedAt;
            uint256 resetLiquidationTime = LibAsset.resetLiquidationTime(asset);

            if (timeDiff <= resetLiquidationTime) {
                revert Errors.MarginCallAlreadyFlagged();
            }
        }

        short.setFlagger(cusd, flaggerHint);
        emit Events.FlagShort(asset, shorter, id, msg.sender, adjustedTimestamp);
    }

    /**
     * @notice Liquidates short by forcing shorter to place bid on market
     * @dev Primary liquidation method. Requires flag
     * @dev Shorter will bear the cost of forcedBid on market
     *
     * @param asset The market that will be impacted
     * @param shorter Shorter getting liquidated
     * @param id Id of short getting liquidated
     * @param shortHintArray Array of hintId for the id to start matching against shorts since you can't match a short < oracle price
     *
     * @return gasFee Estimated cost of gas for the forcedBid
     * @return ethFilled Amount of eth filled in forcedBid
     */
    function liquidate(
        address asset,
        address shorter,
        uint8 id,
        uint16[] memory shortHintArray
    )
        external
        isNotFrozen(asset)
        nonReentrant
        onlyValidShortRecord(asset, shorter, id)
        returns (uint88, uint88)
    {
        if (msg.sender == shorter) revert Errors.CannotLiquidateSelf();

        //@dev marginCall requires more up-to-date oraclePrice (15 min vs createLimitBid's 1 hour)
        LibOrders.updateOracleAndStartingShortViaTimeBidOnly(
            asset, OF.FifteenMinutes, shortHintArray
        );

        MTypes.MarginCallPrimary memory m = _setMarginCallStruct(asset, shorter, id);

        if (m.cRatio >= LibAsset.primaryLiquidationCR(m.asset)) {
            revert Errors.SufficientCollateral();
        }

        // revert if no asks, or price too high
        _checklowestSell(m);

        // check if within margin call time window
        if (!_canLiquidate(m)) {
            STypes.ShortRecord storage shortRecord = s.shortRecords[asset][shorter][id];
            shortRecord.resetFlag();
            return (0, 0);
        }

        _performForcedBid(m, shortHintArray);

        _marginFeeHandler(m);

        _fullorPartialLiquidation(m);
        emit Events.Liquidate(asset, shorter, id, msg.sender, m.ercDebtMatched);

        return (m.gasFee, m.ethFilled);
    }

    //PRIVATE FUNCTIONS

    // Reverts if no eligible sells, or if lowest sell price is too high
    // @dev startingShortId is updated via updateOracleAndStartingShortViaTimeBidOnly() prior to call
    function _checklowestSell(MTypes.MarginCallPrimary memory m) private view {
        uint16 lowestAskKey = s.asks[m.asset][Constants.HEAD].nextId;
        uint16 startingShortId = s.asset[m.asset].startingShortId;
        uint256 bufferPrice = m.oraclePrice.mul(m.forcedBidPriceBuffer);
        if (
            // Checks for no eligible asks
            (
                lowestAskKey == Constants.TAIL
                    || s.asks[m.asset][lowestAskKey].price > bufferPrice
            )
            // Checks for no eligible shorts
            && (
                startingShortId == Constants.HEAD // means no short >= oracleprice
                    || s.shorts[m.asset][startingShortId].price > bufferPrice
            )
        ) {
            revert Errors.NoSells();
        }
    }

    /**
     * @notice Sets the memory struct m with initial data
     *
     * @param asset The market that will be impacted
     * @param shorter Shorter getting liquidated
     * @param id Id of short getting liquidated
     *
     * @return m Memory struct used throughout MarginCallPrimaryFacet.sol
     */

    function _setMarginCallStruct(address asset, address shorter, uint8 id)
        private
        returns (MTypes.MarginCallPrimary memory)
    {
        LibShortRecord.updateErcDebt(asset, shorter, id);
        {
            MTypes.MarginCallPrimary memory m;
            m.asset = asset;
            m.short = s.shortRecords[asset][shorter][id];
            m.vault = s.asset[asset].vault;
            m.shorter = shorter;
            m.minimumCR = LibAsset.minimumCR(asset);
            m.oraclePrice = LibOracle.getPrice(asset);
            m.cRatio = m.short.getCollateralRatio(asset);
            m.forcedBidPriceBuffer = LibAsset.forcedBidPriceBuffer(asset);
            m.callerFeePct = LibAsset.callerFeePct(m.asset);
            m.tappFeePct = LibAsset.tappFeePct(m.asset);
            m.ethDebt = m.short.ercDebt.mul(m.oraclePrice).mul(m.forcedBidPriceBuffer).mul(
                1 ether + m.tappFeePct + m.callerFeePct
            ); // ethDebt accounts for forcedBidPriceBuffer and potential fees
            return m;
        }
    }

    /**
     * @notice Handles the set up and execution of making a forcedBid
     * @dev Shorter will bear the cost of forcedBid on market
     * @dev Depending on shorter's cRatio, the TAPP can attempt to fund bid
     *
     * @param m Memory struct used throughout MarginCallPrimaryFacet.sol
     * @param shortHintArray Array of hintId for the id to start matching against shorts since you can't match a short < oracle price
     *
     */

    function _performForcedBid(
        MTypes.MarginCallPrimary memory m,
        uint16[] memory shortHintArray
    ) private {
        uint256 startGas = gasleft();
        uint88 ercAmountLeft;

        //@dev Provide higher price to better ensure it can fully fill the margin call
        uint80 _bidPrice = m.oraclePrice.mulU80(m.forcedBidPriceBuffer);

        // Shorter loses leftover collateral to TAPP when unable to maintain CR above the minimum
        m.loseCollateral = m.cRatio <= m.minimumCR;

        //@dev Increase ethEscrowed by shorter's full collateral for forced bid
        s.vaultUser[m.vault][address(this)].ethEscrowed += m.short.collateral;

        // Check ability of TAPP plus short collateral to pay back ethDebt
        if (s.vaultUser[m.vault][address(this)].ethEscrowed < m.ethDebt) {
            uint96 ercDebtPrev = m.short.ercDebt;
            if (s.asset[m.asset].ercDebt <= ercDebtPrev) {
                // Occurs when only one shortRecord in the asset (market)
                revert Errors.CannotSocializeDebt();
            }
            m.loseCollateral = true;
            // @dev Max ethDebt can only be the ethEscrowed in the TAPP
            m.ethDebt = s.vaultUser[m.vault][address(this)].ethEscrowed;
            // Reduce ercDebt proportional to ethDebt
            m.short.ercDebt = uint88(
                m.ethDebt.div(_bidPrice.mul(1 ether + m.callerFeePct + m.tappFeePct))
            ); // @dev(safe-cast)
            uint96 ercDebtSocialized = ercDebtPrev - m.short.ercDebt;
            // Update ercDebtRate to socialize loss (increase debt) to other shorts
            s.asset[m.asset].ercDebtRate +=
                ercDebtSocialized.divU64(s.asset[m.asset].ercDebt - ercDebtPrev);
        }

        // @dev MarginCall contract will be the caller. Virtual accounting done later for shorter or TAPP
        (m.ethFilled, ercAmountLeft) = IDiamond(payable(address(this))).createForcedBid(
            address(this), m.asset, _bidPrice, m.short.ercDebt, shortHintArray
        );

        m.ercDebtMatched = m.short.ercDebt - ercAmountLeft;

        //@dev virtually burning the repurchased debt
        s.assetUser[m.asset][address(this)].ercEscrowed -= m.ercDebtMatched;
        s.asset[m.asset].ercDebt -= m.ercDebtMatched;

        uint256 gasUsed = startGas - gasleft();
        //@dev manually setting basefee to 1,000,000 in foundry.toml;
        //@dev By basing gasFee off of baseFee instead of priority, adversaries are prevent from draining the TAPP
        m.gasFee = uint88(gasUsed * block.basefee); // @dev(safe-cast)
    }

    /**
     * @notice Handles the distribution of marginFee
     * @dev MarginFee is taken into consideration when determining black swan
     *
     * @param m Memory struct used throughout MarginCallPrimaryFacet.sol
     *
     */
    function _marginFeeHandler(MTypes.MarginCallPrimary memory m) private {
        STypes.VaultUser storage VaultUser = s.vaultUser[m.vault][msg.sender];
        STypes.VaultUser storage TAPP = s.vaultUser[m.vault][address(this)];
        // distribute fees to TAPP and caller
        uint88 tappFee = m.ethFilled.mulU88(m.tappFeePct);
        uint88 callerFee = m.ethFilled.mulU88(m.callerFeePct) + m.gasFee;

        m.totalFee += tappFee + callerFee;
        //@dev TAPP already received the gasFee for being the forcedBid caller. tappFee nets out.
        if (TAPP.ethEscrowed >= callerFee) {
            TAPP.ethEscrowed -= callerFee;
            VaultUser.ethEscrowed += callerFee;
        } else {
            // Give caller (portion of?) tappFee instead of gasFee
            VaultUser.ethEscrowed += callerFee - m.gasFee + tappFee;
            m.totalFee -= m.gasFee;
            TAPP.ethEscrowed -= m.totalFee;
        }
    }

    function min88(uint256 a, uint88 b) private pure returns (uint88) {
        if (a > type(uint88).max) revert Errors.InvalidAmount();
        return a < b ? uint88(a) : b;
    }

    /**
     * @notice Handles accounting in event of full or partial liquidations
     *
     * @param m Memory struct used throughout MarginCallPrimaryFacet.sol
     *
     */
    function _fullorPartialLiquidation(MTypes.MarginCallPrimary memory m) private {
        uint88 decreaseCol = min88(m.totalFee + m.ethFilled, m.short.collateral);

        if (m.short.ercDebt == m.ercDebtMatched) {
            // Full liquidation
            LibShortRecord.disburseCollateral(
                m.asset,
                m.shorter,
                m.short.collateral,
                m.short.zethYieldRate,
                m.short.updatedAt
            );
            LibShortRecord.deleteShortRecord(m.asset, m.shorter, m.short.id);
            if (!m.loseCollateral) {
                m.short.collateral -= decreaseCol;
                s.vaultUser[m.vault][m.shorter].ethEscrowed += m.short.collateral;
                s.vaultUser[m.vault][address(this)].ethEscrowed -= m.short.collateral;
            }
        } else {
            // Partial liquidation
            m.short.ercDebt -= m.ercDebtMatched;
            m.short.collateral -= decreaseCol;
            s.shortRecords[m.asset][m.shorter][m.short.id] = m.short;

            s.vaultUser[m.vault][address(this)].ethEscrowed -= m.short.collateral;
            LibShortRecord.disburseCollateral(
                m.asset, m.shorter, decreaseCol, m.short.zethYieldRate, m.short.updatedAt
            );

            // TAPP absorbs leftover short, unless it already owns the short
            if (m.loseCollateral && m.shorter != address(this)) {
                // Delete partially liquidated short
                LibShortRecord.deleteShortRecord(m.asset, m.shorter, m.short.id);
                // Absorb leftovers into TAPP short
                LibShortRecord.fillShortRecord(
                    m.asset,
                    address(this),
                    Constants.SHORT_STARTING_ID,
                    SR.FullyFilled,
                    m.short.collateral,
                    m.short.ercDebt,
                    s.asset[m.asset].ercDebtRate,
                    m.short.zethYieldRate
                );
            }
        }
    }

    /**
     * @notice Helper that evaluates if a short is eligible for liquidation (i.e. flagged and within appropriate time frame)
     * @dev Shorter has 10 hours after initial flag to bring cRatio up above maintainence margin...
     * @dev ...After that, the flagger has 2 hours to liquidate the shorter. If short is not liquidated by shorter within that time, ANYBODY can then liquidate...
     * @dev ...After 16 total hours have passed and the short has not been liquidated, the flag gets reset and the flagging process begins anew
     *
     * @param m Memory struct used throughout MarginCallPrimaryFacet.sol
     *
     */
    // check if within margin call time window
    function _canLiquidate(MTypes.MarginCallPrimary memory m)
        private
        view
        returns (bool)
    {
        //@dev if cRatio is below the minimumCR, allow liquidation regardless of flagging
        if (m.cRatio < m.minimumCR) return true;

        //@dev Only check if flagger is empty, not updatedAt
        if (m.short.flaggerId == 0) {
            revert Errors.ShortNotFlagged();
        }

        /*
         * Timeline: 
         * 
         * updatedAt (~0 hrs)
         * ..
         * [Errors.MarginCallIneligibleWindow]
         * ..
         * firstLiquidationTime (~10hrs, +10 hrs)
         * ..
         * [return msg.sender == short.flagger]
         * ..
         * secondLiquidationTime (~12hrs, +2 hrs)
         * ..
         * [return true (msg.sender is anyone)]
         * ..
         * resetLiquidationTime (~16hrs, +4 hrs)
         * ..
         * [return false (reset flag)]
        */

        uint256 timeDiff = LibOrders.getOffsetTimeHours() - m.short.updatedAt;
        uint256 resetLiquidationTime = LibAsset.resetLiquidationTime(m.asset);

        if (timeDiff >= resetLiquidationTime) {
            return false;
        } else {
            uint256 secondLiquidationTime = LibAsset.secondLiquidationTime(m.asset);
            bool isBetweenFirstAndSecondLiquidationTime = timeDiff
                > LibAsset.firstLiquidationTime(m.asset) && timeDiff <= secondLiquidationTime
                && s.flagMapping[m.short.flaggerId] == msg.sender;
            bool isBetweenSecondAndResetLiquidationTime =
                timeDiff > secondLiquidationTime && timeDiff <= resetLiquidationTime;
            if (
                !(
                    (isBetweenFirstAndSecondLiquidationTime)
                        || (isBetweenSecondAndResetLiquidationTime)
                )
            ) {
                revert Errors.MarginCallIneligibleWindow();
            }

            return true;
        }
    }
}
