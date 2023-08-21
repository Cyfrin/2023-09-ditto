// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U80, U88} from "contracts/libraries/PRBMathHelper.sol";

import {Errors} from "contracts/libraries/Errors.sol";
import {Events} from "contracts/libraries/Events.sol";
import {Modifiers} from "contracts/libraries/AppStorage.sol";
import {STypes, MTypes} from "contracts/libraries/DataTypes.sol";
import {LibAsset} from "contracts/libraries/LibAsset.sol";
import {LibShortRecord} from "contracts/libraries/LibShortRecord.sol";
import {LibOracle} from "contracts/libraries/LibOracle.sol";
import {Constants} from "contracts/libraries/Constants.sol";

// import {console} from "contracts/libraries/console.sol";

contract ShortRecordFacet is Modifiers {
    using LibShortRecord for STypes.ShortRecord;
    using U256 for uint256;
    using U80 for uint80;
    using U88 for uint88;

    address private immutable cusd;

    constructor(address _cusd) {
        cusd = _cusd;
    }

    /**
     * @notice Increases collateral of an active short
     *
     * @param asset The market that will be impacted
     * @param id id of short
     * @param amount eth amount to increase collateral by
     *
     */

    function increaseCollateral(address asset, uint8 id, uint88 amount)
        external
        isNotFrozen(asset)
        nonReentrant
        onlyValidShortRecord(asset, msg.sender, id)
    {
        STypes.Asset storage Asset = s.asset[asset];
        uint256 vault = Asset.vault;
        STypes.Vault storage Vault = s.vault[vault];
        STypes.VaultUser storage VaultUser = s.vaultUser[vault][msg.sender];
        if (VaultUser.ethEscrowed < amount) revert Errors.InsufficientETHEscrowed();

        STypes.ShortRecord storage short = s.shortRecords[asset][msg.sender][id];
        short.updateErcDebt(asset);
        uint256 yield = short.collateral.mul(short.zethYieldRate);
        short.collateral += amount;

        uint256 cRatio = short.getCollateralRatio(asset);
        if (cRatio >= Constants.CRATIO_MAX) revert Errors.CollateralHigherThanMax();

        //@dev reset flag info if new cratio is above primaryLiquidationCR
        if (cRatio >= LibAsset.primaryLiquidationCR(asset)) {
            short.resetFlag();
        }

        yield += amount.mul(Vault.zethYieldRate);
        short.zethYieldRate = yield.divU80(short.collateral);

        VaultUser.ethEscrowed -= amount;
        Vault.zethCollateral += amount;
        Asset.zethCollateral += amount;
        emit Events.IncreaseCollateral(asset, msg.sender, id, amount);
    }

    /**
     * @notice Decrease collateral of an active short
     * @dev Can't decrease below initial margin
     *
     * @param asset The market that will be impacted
     * @param id id of short
     * @param amount eth amount to decrease collateral by
     *
     */

    function decreaseCollateral(address asset, uint8 id, uint88 amount)
        external
        isNotFrozen(asset)
        nonReentrant
        onlyValidShortRecord(asset, msg.sender, id)
    {
        STypes.ShortRecord storage short = s.shortRecords[asset][msg.sender][id];
        short.updateErcDebt(asset);
        if (amount > short.collateral) revert Errors.InsufficientCollateral();

        short.collateral -= amount;

        uint256 cRatio = short.getCollateralRatio(asset);
        if (cRatio < LibAsset.initialMargin(asset)) {
            revert Errors.CollateralLowerThanMin();
        }

        uint256 vault = s.asset[asset].vault;
        s.vaultUser[vault][msg.sender].ethEscrowed += amount;

        LibShortRecord.disburseCollateral(
            asset, msg.sender, amount, short.zethYieldRate, short.updatedAt
        );
        emit Events.DecreaseCollateral(asset, msg.sender, id, amount);
    }

    /**
     * @notice Combine active shorts into one short
     * @dev If any shorts are flagged the resulting short must have c-ratio > primaryLiquidationCR
     *
     * @param asset The market that will be impacted
     * @param ids array of short ids to be combined
     *
     */

    function combineShorts(address asset, uint8[] memory ids)
        external
        isNotFrozen(asset)
        nonReentrant
        onlyValidShortRecord(asset, msg.sender, ids[0])
    {
        if (ids.length < 2) revert Errors.InsufficientNumberOfShorts();
        // First short in the array
        STypes.ShortRecord storage firstShort = s.shortRecords[asset][msg.sender][ids[0]];
        // @dev Load initial short elements in struct to avoid stack too deep
        MTypes.CombineShorts memory c;
        c.shortFlagExists = firstShort.flaggerId != 0;
        c.shortUpdatedAt = firstShort.updatedAt;

        address _asset = asset;
        uint88 collateral;
        uint88 ercDebt;
        uint256 yield;
        uint256 ercDebtSocialized;
        for (uint256 i = ids.length - 1; i > 0; i--) {
            uint8 _id = ids[i];
            _onlyValidShortRecord(_asset, msg.sender, _id);
            STypes.ShortRecord storage currentShort =
                s.shortRecords[_asset][msg.sender][_id];
            // See if there is at least one flagged short
            if (!c.shortFlagExists) {
                if (currentShort.flaggerId != 0) {
                    c.shortFlagExists = true;
                }
            }

            //@dev Take latest time when combining shorts (prevent flash loan)
            if (currentShort.updatedAt > c.shortUpdatedAt) {
                c.shortUpdatedAt = currentShort.updatedAt;
            }

            {
                uint88 currentShortCollateral = currentShort.collateral;
                uint88 currentShortErcDebt = currentShort.ercDebt;
                collateral += currentShortCollateral;
                ercDebt += currentShortErcDebt;
                yield += currentShortCollateral.mul(currentShort.zethYieldRate);
                ercDebtSocialized += currentShortErcDebt.mul(currentShort.ercDebtRate);
            }

            if (currentShort.tokenId != 0) {
                //@dev We require the first short to have NFT so we don't need to burn and re-mint
                if (firstShort.tokenId == 0) {
                    revert Errors.FirstShortMustBeNFT();
                }

                LibShortRecord.burnNFT(currentShort.tokenId);
            }

            // Cancel this short and combine with short in ids[0]
            LibShortRecord.deleteShortRecord(_asset, msg.sender, _id);
        }

        // Merge all short records into the short at position id[0]
        firstShort.merge(ercDebt, ercDebtSocialized, collateral, yield, c.shortUpdatedAt);

        // If at least one short was flagged, ensure resulting c-ratio > primaryLiquidationCR
        if (c.shortFlagExists) {
            if (
                firstShort.getCollateralRatioSpotPrice(
                    LibOracle.getSavedOrSpotOraclePrice(_asset)
                ) < LibAsset.primaryLiquidationCR(_asset)
            ) revert Errors.InsufficientCollateral();
            // Resulting combined short has sufficient c-ratio to remove flag
            firstShort.resetFlag();
        }
        emit Events.CombineShorts(asset, msg.sender, ids);
    }
}
