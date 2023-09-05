// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U88, U80} from "contracts/libraries/PRBMathHelper.sol";

import {IAsset} from "interfaces/IAsset.sol";

import {Errors} from "contracts/libraries/Errors.sol";
import {Events} from "contracts/libraries/Events.sol";
import {STypes, MTypes, SR} from "contracts/libraries/DataTypes.sol";
import {Modifiers} from "contracts/libraries/AppStorage.sol";
import {LibAsset} from "contracts/libraries/LibAsset.sol";
import {LibOracle} from "contracts/libraries/LibOracle.sol";
import {LibShortRecord} from "contracts/libraries/LibShortRecord.sol";
import {Constants} from "contracts/libraries/Constants.sol";

// import {console} from "contracts/libraries/console.sol";

contract MarginCallSecondaryFacet is Modifiers {
    using LibShortRecord for STypes.ShortRecord;
    using U256 for uint256;
    using U88 for uint88;
    using U80 for uint80;

    /**
     * @notice Liquidates short using liquidator's ercEscrowed or wallet
     * @dev Secondary liquidation function. Doesn't need flag
     * @dev Must liquidate all of the debt. No partial (unless TAPP short)
     *
     * @param asset The market that will be impacted
     * @param batches Array of shorters and shortRecordIds to liquidate
     * @param liquidateAmount Amount of ercDebt to liquidate
     * @param isWallet Liquidate using wallet balance when true, ercEscrowed when false
     *
     */

    //@dev If you want to liquidated more than uint88.max worth of erc in shorts, you must call liquidateSecondary multiple times
    function liquidateSecondary(
        address asset,
        MTypes.BatchMC[] memory batches,
        uint88 liquidateAmount,
        bool isWallet
    ) external onlyValidAsset(asset) isNotFrozen(asset) nonReentrant {
        STypes.AssetUser storage AssetUser = s.assetUser[asset][msg.sender];
        MTypes.MarginCallSecondary memory m;
        uint256 minimumCR = LibAsset.minimumCR(asset);
        uint256 oraclePrice = LibOracle.getSavedOrSpotOraclePrice(asset);
        uint256 secondaryLiquidationCR = LibAsset.secondaryLiquidationCR(asset);

        uint88 liquidatorCollateral;
        uint88 liquidateAmountLeft = liquidateAmount;
        for (uint256 i; i < batches.length;) {
            m = _setMarginCallStruct(
                asset, batches[i].shorter, batches[i].shortId, minimumCR, oraclePrice
            );

            unchecked {
                ++i;
            }

            // If ineligible, skip to the next shortrecord instead of reverting
            if (
                m.shorter == msg.sender || m.cRatio > secondaryLiquidationCR
                    || m.short.status == SR.Cancelled
                    || m.short.id >= s.assetUser[asset][m.shorter].shortRecordId
                    || m.short.id < Constants.SHORT_STARTING_ID
                    || (m.shorter != address(this) && liquidateAmountLeft < m.short.ercDebt)
            ) {
                continue;
            }

            bool partialTappLiquidation;
            // Setup partial liquidation of TAPP short
            if (m.shorter == address(this)) {
                partialTappLiquidation = liquidateAmountLeft < m.short.ercDebt;
                if (partialTappLiquidation) {
                    m.short.ercDebt = liquidateAmountLeft;
                }
            }

            // Determine which secondary liquidation method to use
            if (isWallet) {
                IAsset tokenContract = IAsset(asset);
                uint256 walletBalance = tokenContract.balanceOf(msg.sender);
                if (walletBalance < m.short.ercDebt) continue;
                tokenContract.burnFrom(msg.sender, m.short.ercDebt);
                assert(tokenContract.balanceOf(msg.sender) < walletBalance);
            } else {
                if (AssetUser.ercEscrowed < m.short.ercDebt) {
                    continue;
                }
                AssetUser.ercEscrowed -= m.short.ercDebt;
            }

            if (partialTappLiquidation) {
                // Partial liquidation of TAPP short
                _secondaryLiquidationHelperPartialTapp(m);
            } else {
                // Full liquidation
                _secondaryLiquidationHelper(m);
            }

            // Update in memory for final state change after loops
            liquidatorCollateral += m.liquidatorCollateral;
            liquidateAmountLeft -= m.short.ercDebt;
            if (liquidateAmountLeft == 0) break;
        }

        if (liquidateAmount == liquidateAmountLeft) {
            revert Errors.MarginCallSecondaryNoValidShorts();
        }

        // Update finalized state changes
        s.asset[asset].ercDebt -= liquidateAmount - liquidateAmountLeft;
        s.vaultUser[m.vault][msg.sender].ethEscrowed += liquidatorCollateral;
        emit Events.LiquidateSecondary(asset, batches, msg.sender, isWallet);
    }

    /**
     * @notice Sets the memory struct m with initial data
     *
     * @param asset The market that will be impacted
     * @param shorter Shorter getting liquidated
     * @param id id of short getting liquidated
     *
     * @return m Memory struct used throughout MarginCallPrimaryFacet.sol
     */

    function _setMarginCallStruct(
        address asset,
        address shorter,
        uint8 id,
        uint256 minimumCR,
        uint256 oraclePrice
    ) private returns (MTypes.MarginCallSecondary memory) {
        LibShortRecord.updateErcDebt(asset, shorter, id);

        MTypes.MarginCallSecondary memory m;
        m.asset = asset;
        m.short = s.shortRecords[asset][shorter][id];
        m.vault = s.asset[asset].vault;
        m.shorter = shorter;
        m.minimumCR = minimumCR;
        m.cRatio = m.short.getCollateralRatioSpotPrice(oraclePrice);
        return m;
    }

    /**
     * @notice Handles accounting for secondary liquidation methods (wallet and ercEscrowed)
     *
     * @param m Memory struct used throughout MarginCallPrimaryFacet.sol
     *
     */
    // +----------------+---------------+---------+-------+
    // |     Cratio     |  Liquidator   | Shorter | Pool  |
    // +----------------+---------------+---------+-------+
    // | >= 1.5         | (cannot call) | n/a     | n/a   |
    // | 1.1 <= c < 1.5 | 1             | c - 1   | 0     |
    // | 1.0 < c 1.1    | 1             | 0       | c - 1 |
    // | c <= 1         | c             | 0       | 0     |
    // +----------------+---------------+---------+-------+
    function _secondaryLiquidationHelper(MTypes.MarginCallSecondary memory m) private {
        // @dev when cRatio <= 1 liquidator eats loss, so it's expected that only TAPP would call
        m.liquidatorCollateral = m.short.collateral;

        if (m.cRatio > 1 ether) {
            uint88 ercDebtAtOraclePrice =
                m.short.ercDebt.mulU88(LibOracle.getPrice(m.asset)); // eth
            m.liquidatorCollateral = ercDebtAtOraclePrice;

            // if cRatio > 110%, shorter gets remaining collateral
            // Otherwise they take a penalty, and remaining goes to the pool
            address remainingCollateralAddress =
                m.cRatio > m.minimumCR ? m.shorter : address(this);

            s.vaultUser[m.vault][remainingCollateralAddress].ethEscrowed +=
                m.short.collateral - ercDebtAtOraclePrice;
        }

        LibShortRecord.disburseCollateral(
            m.asset,
            m.shorter,
            m.short.collateral,
            m.short.zethYieldRate,
            m.short.updatedAt
        );
        LibShortRecord.deleteShortRecord(m.asset, m.shorter, m.short.id);
    }

    function min88(uint256 a, uint88 b) private pure returns (uint88) {
        if (a > type(uint88).max) revert Errors.InvalidAmount();
        return a < b ? uint88(a) : b;
    }

    function _secondaryLiquidationHelperPartialTapp(MTypes.MarginCallSecondary memory m)
        private
    {
        STypes.ShortRecord storage short =
            s.shortRecords[m.asset][address(this)][m.short.id];
        // Update erc balance
        short.ercDebt -= m.short.ercDebt; // @dev m.short.ercDebt was updated earlier to equal erc filled
        // Update eth balance
        // If c-ratio < 1 then it's possible to lose eth owed over short collateral
        m.liquidatorCollateral =
            min88(m.short.ercDebt.mul(LibOracle.getPrice(m.asset)), m.short.collateral);
        short.collateral -= m.liquidatorCollateral;
        LibShortRecord.disburseCollateral(
            m.asset,
            m.shorter,
            m.liquidatorCollateral,
            m.short.zethYieldRate,
            m.short.updatedAt
        );
    }
}
