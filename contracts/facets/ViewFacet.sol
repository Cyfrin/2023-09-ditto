// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U96, U88, U80} from "contracts/libraries/PRBMathHelper.sol";

import {Constants} from "contracts/libraries/Constants.sol";
import {Modifiers} from "contracts/libraries/AppStorage.sol";
import {STypes, MTypes, O, SR} from "contracts/libraries/DataTypes.sol";
import {LibOrders} from "contracts/libraries/LibOrders.sol";
import {LibOracle} from "contracts/libraries/LibOracle.sol";
import {LibVault} from "contracts/libraries/LibVault.sol";
import {LibShortRecord} from "contracts/libraries/LibShortRecord.sol";

// import {console} from "contracts/libraries/console.sol";

contract ViewFacet is Modifiers {
    using LibOrders for mapping(address => mapping(uint16 => STypes.Order));
    using LibShortRecord for STypes.ShortRecord;
    using U256 for uint256;
    using U96 for uint96;
    using U88 for uint88;
    using U80 for uint80;
    using LibVault for uint256;

    /// Vault View Functions
    function getZethBalance(uint256 vault, address user)
        external
        view
        nonReentrantView
        returns (uint256)
    {
        return s.vaultUser[vault][user].ethEscrowed;
    }

    function getAssetBalance(address asset, address user)
        external
        view
        nonReentrantView
        returns (uint256)
    {
        return s.assetUser[asset][user].ercEscrowed;
    }

    // @dev does not need read only re-entrancy
    function getVault(address asset) external view returns (uint256) {
        return s.asset[asset].vault;
    }

    // @dev does not need read only re-entrancy
    // @dev vault of bridge is stored separately from asset vault
    function getBridgeVault(address bridge) external view returns (uint256) {
        return s.bridge[bridge].vault;
    }

    /// Order View Functions
    /**
     * @notice See all sorted bids on market
     *
     * @param asset The market that will be impacted
     *
     * @return orders List of Orders
     */

    function getBids(address asset)
        external
        view
        nonReentrantView
        returns (STypes.Order[] memory)
    {
        return s.bids.currentOrders(asset);
    }

    /**
     * @notice See all sorted asks on market
     *
     * @param asset The market that will be impacted
     *
     * @return orders List of Orders
     */

    function getAsks(address asset)
        external
        view
        nonReentrantView
        returns (STypes.Order[] memory)
    {
        return s.asks.currentOrders(asset);
    }

    /**
     * @notice See all sorted shorts on market
     *
     * @param asset The market that will be impacted
     *
     * @return orders List of Orders
     */

    function getShorts(address asset)
        external
        view
        nonReentrantView
        returns (STypes.Order[] memory)
    {
        return s.shorts.currentOrders(asset);
    }

    /**
     * @notice Returns correct Id of bid based on its price
     * @dev does not need read only re-entrancy
     *
     * @param asset The market that will be impacted
     * @param price price of bid
     *
     * @return hintId Exact bid ID in sorted Bid Orders
     */
    function getBidHintId(address asset, uint256 price)
        external
        view
        returns (uint16 hintId)
    {
        return LibOrders.getOrderId(
            s.bids, asset, Constants.NEXT, Constants.HEAD, price, O.LimitBid
        );
    }

    /**
     * @notice Returns correct Id of ask based on its price
     * @dev does not need read only re-entrancy
     *
     * @param asset The market that will be impacted
     * @param price price of ask
     *
     * @return hintId Exact ask ID in sorted Ask Orders
     */

    function getAskHintId(address asset, uint256 price)
        external
        view
        returns (uint16 hintId)
    {
        return LibOrders.getOrderId(
            s.asks, asset, Constants.NEXT, Constants.HEAD, price, O.LimitAsk
        );
    }

    /**
     * @notice Returns correct Id of short based on its price
     * @dev does not need read only re-entrancy
     *
     * @param asset The market that will be impacted
     * @param price price of short
     *
     * @return hintId Exact short ID in sorted Short Orders
     */

    function getShortHintId(address asset, uint256 price)
        external
        view
        returns (uint16)
    {
        return LibOrders.getOrderId(
            s.shorts, asset, Constants.NEXT, Constants.HEAD, price, O.LimitShort
        );
    }

    /**
     * @notice Returns correct Id of short >= oracle price
     *
     * @param asset The market that will be impacted
     *
     * @return shortHintId Exact short ID in sorted Short Orders
     */
    function getShortIdAtOracle(address asset)
        external
        view
        nonReentrantView
        returns (uint16 shortHintId)
    {
        // if 5 is oracle price
        // .. 3 4 [5] 5 5..
        // price is 5-1=4, gets last o with price of 4, get o.next to get [5]
        uint16 idBeforeOracle = LibOrders.getOrderId(
            s.shorts,
            asset,
            Constants.NEXT,
            Constants.HEAD,
            LibOracle.getOraclePrice(asset) - 1 wei,
            O.LimitShort
        );

        //@dev If id is the last item, return the last item
        if (s.shorts[asset][idBeforeOracle].nextId == Constants.TAIL) {
            return idBeforeOracle;
        } else {
            return s.shorts[asset][idBeforeOracle].nextId;
        }
    }

    //@dev does not need read only re-entrancy
    function getHintArray(address asset, uint256 price, O orderType)
        external
        view
        returns (MTypes.OrderHint[] memory orderHintArray)
    {
        //@dev Currently set to length == 1. Can be adjusted to n length
        orderHintArray = new MTypes.OrderHint[](1);
        uint16 _hintId;
        uint32 _creationTime;

        if (orderType == O.LimitBid) {
            _hintId = LibOrders.getOrderId(
                s.bids, asset, Constants.NEXT, Constants.HEAD, price, orderType
            );
            _creationTime = s.bids[asset][_hintId].creationTime;
        } else if (orderType == O.LimitAsk) {
            _hintId = LibOrders.getOrderId(
                s.asks, asset, Constants.NEXT, Constants.HEAD, price, orderType
            );
            _creationTime = s.asks[asset][_hintId].creationTime;
        } else if (orderType == O.LimitShort) {
            _hintId = LibOrders.getOrderId(
                s.shorts, asset, Constants.NEXT, Constants.HEAD, price, orderType
            );
            _creationTime = s.shorts[asset][_hintId].creationTime;
        }

        orderHintArray[0] =
            MTypes.OrderHint({hintId: _hintId, creationTime: _creationTime});
        return orderHintArray;
    }

    /// Margin Call View Functions
    /**
     * @notice computes the c-ratio of a specific short at protocol price
     *
     * @param short Short
     *
     * @return cRatio
     */

    function getCollateralRatio(address asset, STypes.ShortRecord memory short)
        external
        view
        nonReentrantView
        returns (uint256 cRatio)
    {
        return short.getCollateralRatio(asset);
    }

    /**
     * @notice computes the c-ratio of a specific short at oracle price
     *
     * @param short Short
     *
     * @return cRatio
     */

    function getCollateralRatioSpotPrice(address asset, STypes.ShortRecord memory short)
        external
        view
        nonReentrantView
        returns (uint256 cRatio)
    {
        return short.getCollateralRatioSpotPrice(LibOracle.getOraclePrice(asset));
    }

    /// Oracle View Functions
    //@dev does not need read only re-entrancy
    function getAssetPrice(address asset) external view returns (uint256) {
        return LibOracle.getOraclePrice(asset);
    }

    //@dev does not need read only re-entrancy
    function getProtocolAssetPrice(address asset) external view returns (uint256) {
        return LibOracle.getSavedOrSpotOraclePrice(asset);
    }

    /// Yield View Functions
    //@dev does not need read only re-entrancy
    function getTithe(uint256 vault) external view returns (uint256) {
        return (uint256(s.vault[vault].zethTithePercent) * 1 ether)
            / Constants.FOUR_DECIMAL_PLACES;
    }

    function getUndistributedYield(uint256 vault)
        external
        view
        nonReentrantView
        returns (uint256)
    {
        return vault.getZethTotal() - s.vault[vault].zethTotal;
    }

    function getYield(address asset, address user)
        external
        view
        nonReentrantView
        returns (uint256 shorterYield)
    {
        uint256 vault = s.asset[asset].vault;
        uint256 zethYieldRate = s.vault[vault].zethYieldRate;
        uint8 id = s.shortRecords[asset][user][Constants.HEAD].nextId;

        while (true) {
            // One short of one shorter in this order book
            STypes.ShortRecord storage currentShort = s.shortRecords[asset][user][id];
            //@dev: isNotRecentlyModified is mainly for flash loans or loans where they want to deposit to claim yield immediately
            bool isNotRecentlyModified = LibOrders.getOffsetTimeHours()
                - currentShort.updatedAt > Constants.YIELD_DELAY_HOURS;

            if (currentShort.status != SR.Cancelled && isNotRecentlyModified) {
                // Yield earned by this short
                shorterYield += currentShort.collateral.mul(
                    zethYieldRate - currentShort.zethYieldRate
                );
            }
            // Move to next short unless this is the last one
            if (currentShort.nextId > Constants.HEAD) {
                id = currentShort.nextId;
            } else {
                break;
            }
        }
        return shorterYield;
    }

    function getDittoMatchedReward(uint256 vault, address user)
        external
        view
        nonReentrantView
        returns (uint256)
    {
        uint256 shares = s.vaultUser[vault][user].dittoMatchedShares;
        if (shares <= 1) {
            return 0;
        }
        shares -= 1;

        STypes.Vault storage Vault = s.vault[vault];
        // Total token reward amount for limit orders
        uint256 protocolTime = LibOrders.getOffsetTime() / 1 days;
        uint256 elapsedTime = protocolTime - Vault.dittoMatchedTime;
        uint256 totalReward =
            Vault.dittoMatchedReward + elapsedTime * 1 days * Vault.dittoMatchedRate;
        // User's proportion of the total token reward
        uint256 sharesTotal = Vault.dittoMatchedShares;
        return shares.mul(totalReward).div(sharesTotal);
    }

    function getDittoReward(uint256 vault, address user)
        external
        view
        nonReentrantView
        returns (uint256)
    {
        if (s.vaultUser[vault][user].dittoReward <= 1) {
            return 0;
        } else {
            return s.vaultUser[vault][user].dittoReward - 1;
        }
    }

    /// Market Shutdown View Functions
    /**
     * @notice Computes the c-ratio of an asset class
     *
     * @param asset The market that will be impacted
     *
     * @return cRatio
     */

    function getAssetCollateralRatio(address asset)
        external
        view
        nonReentrantView
        returns (uint256 cRatio)
    {
        STypes.Asset storage Asset = s.asset[asset];
        return Asset.zethCollateral.div(LibOracle.getPrice(asset).mul(Asset.ercDebt));
    }

    /// ShortRecord View Functions
    /**
     * @notice Returns shortRecords for an asset of a given address
     *
     * @param asset The market that will be impacted
     * @param shorter Shorter address
     *
     * @return shorts
     */
    function getShortRecords(address asset, address shorter)
        external
        view
        nonReentrantView
        returns (STypes.ShortRecord[] memory shorts)
    {
        uint256 length = LibShortRecord.getShortRecordCount(asset, shorter);
        STypes.ShortRecord[] memory shortRecords = new STypes.ShortRecord[](length);

        uint8 id = s.shortRecords[asset][shorter][Constants.HEAD].nextId;
        if (id <= Constants.HEAD) {
            return shorts;
        }

        uint256 i;
        while (true) {
            STypes.ShortRecord storage currentShort = s.shortRecords[asset][shorter][id];

            if (currentShort.status != SR.Cancelled) {
                shortRecords[i] = currentShort;
            }

            if (currentShort.nextId > Constants.HEAD) {
                id = currentShort.nextId;
                i++;
            } else {
                return shortRecords;
            }
        }
    }

    /**
     * @notice Returns shortRecord
     *
     * @param asset The market that will be impacted
     * @param shorter Shorter address
     * @param id id of short
     *
     * @return shortRecord
     */
    function getShortRecord(address asset, address shorter, uint8 id)
        external
        view
        nonReentrantView
        returns (STypes.ShortRecord memory shortRecord)
    {
        return s.shortRecords[asset][shorter][id];
    }

    /**
     * @notice Returns number of active shorts of a shorter
     *
     * @param asset The market that will be impacted
     * @param shorter Shorter address
     *
     * @return shortRecordCount Number of active shortRecords
     */
    function getShortRecordCount(address asset, address shorter)
        external
        view
        nonReentrantView
        returns (uint256 shortRecordCount)
    {
        return LibShortRecord.getShortRecordCount(asset, shorter);
    }

    /**
     * @notice Returns AssetUser struct
     *
     * @param asset The market asset being queried
     * @param user User address
     *
     * @return assetUser
     */
    function getAssetUserStruct(address asset, address user)
        external
        view
        nonReentrantView
        returns (STypes.AssetUser memory)
    {
        return s.assetUser[asset][user];
    }

    /**
     * @notice Returns VaultUser struct
     *
     * @param vault The vault being queried
     * @param user User address
     *
     * @return vaultUser
     */
    function getVaultUserStruct(uint256 vault, address user)
        external
        view
        nonReentrantView
        returns (STypes.VaultUser memory)
    {
        return s.vaultUser[vault][user];
    }

    /**
     * @notice Returns Vault struct
     *
     * @param vault The vault being queried
     *
     * @return vault
     */
    function getVaultStruct(uint256 vault)
        external
        view
        nonReentrantView
        returns (STypes.Vault memory)
    {
        return s.vault[vault];
    }

    /**
     * @notice Returns Asset struct
     *
     * @param asset The market asset being queried
     *
     * @return asset
     */
    function getAssetStruct(address asset)
        external
        view
        nonReentrantView
        returns (STypes.Asset memory)
    {
        return s.asset[asset];
    }

    /**
     * @notice Returns Bridge struct
     *
     * @param bridge The bridge address being queried
     *
     * @return bridge
     */
    function getBridgeStruct(address bridge)
        external
        view
        nonReentrantView
        returns (STypes.Bridge memory)
    {
        return s.bridge[bridge];
    }

    /**
     * @notice Returns offset time in hours
     *
     * @return offsetTimeHours
     */
    function getOffsetTimeHours() external view returns (uint256) {
        return LibOrders.getOffsetTimeHours();
    }

    /**
     * @notice Returns offset time
     *
     * @return offsetTime
     */
    function getOffsetTime() external view returns (uint256) {
        return LibOrders.getOffsetTime();
    }

    function getFlaggerId(address asset, address user)
        external
        view
        returns (uint24 flaggerId)
    {
        return s.assetUser[asset][user].g_flaggerId;
    }
}
