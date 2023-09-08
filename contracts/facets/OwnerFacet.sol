// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256} from "contracts/libraries/PRBMathHelper.sol";

import {Modifiers} from "contracts/libraries/AppStorage.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {Events} from "contracts/libraries/Events.sol";
import {STypes, MTypes, SR} from "contracts/libraries/DataTypes.sol";
import {LibDiamond} from "contracts/libraries/LibDiamond.sol";
import {LibOrders} from "contracts/libraries/LibOrders.sol";
import {LibOracle} from "contracts/libraries/LibOracle.sol";
import {LibShortRecord} from "contracts/libraries/LibShortRecord.sol";
import {LibAsset} from "contracts/libraries/LibAsset.sol";
import {Constants} from "contracts/libraries/Constants.sol";

// import {console} from "contracts/libraries/console.sol";

contract OwnerFacet is Modifiers {
    using U256 for uint256;

    /**
     * @notice Initialize data for newly deployed market
     * @dev Single use only
     *
     * @param asset The market that will be impacted
     * @param a The market settings
     */

    /*
     * @param oracle The oracle for the asset
     * @param initialMargin Initial margin value of the new market
     * @param primaryLiquidationCR Liquidation ratio (Maintenance margin) value of the new market
     * @param secondaryLiquidationCR CRatio threshold for secondary liquidations
     * @param forcedBidPriceBuffer Liquidation limit value of the new market
     * @param minimumCR Lowest threshold for shortRecord to not lose collateral during liquidation
     * @param resetLiquidationTime Time limit for when flagged shorts get reset
     * @param secondLiquidationTime Time limit for when flagged shorts can be liquidated by others, not just flagger
     * @param firstLiquidationTime Time limit for when flagged shorts get be liquidated by flagger
     * @param tappFeePct Primary liquidation fee sent to TAPP out of shorter collateral
     * @param callerFeePct Primary liquidation fee sent to margin caller out of shorter collateral
     * @param minBidEth Minimum bid dust amount
     * @param minAskEth Minimum ask dust amount
     * @param minShortErc Minimum short record debt amount
    */

    function createMarket(address asset, STypes.Asset memory a) external onlyDAO {
        STypes.Asset storage Asset = s.asset[asset];
        // can check non-zero ORDER_ID to prevent creating same asset
        if (Asset.orderId != 0) revert Errors.MarketAlreadyCreated();

        Asset.vault = a.vault;
        _setAssetOracle(asset, a.oracle);

        Asset.assetId = uint8(s.assets.length);
        s.assetMapping[s.assets.length] = asset;
        s.assets.push(asset);

        STypes.Order memory guardOrder;
        guardOrder.prevId = Constants.HEAD;
        guardOrder.id = Constants.HEAD;
        guardOrder.nextId = Constants.TAIL;
        //@dev parts of OB depend on having sell's HEAD's price and creationTime = 0
        s.asks[asset][Constants.HEAD] = s.shorts[asset][Constants.HEAD] = guardOrder;

        //@dev Using Bid's HEAD's order contain oracle data
        guardOrder.creationTime = LibOrders.getOffsetTime();
        guardOrder.ercAmount = uint80(LibOracle.getOraclePrice(asset));
        s.bids[asset][Constants.HEAD] = guardOrder;

        //@dev hardcoded value
        Asset.orderId = Constants.STARTING_ID; // 100
        Asset.startingShortId = Constants.HEAD;

        //@dev comment with initial values
        _setInitialMargin(asset, a.initialMargin); // 500 -> 5 ether
        _setPrimaryLiquidationCR(asset, a.primaryLiquidationCR); // 400 -> 4 ether
        _setSecondaryLiquidationCR(asset, a.secondaryLiquidationCR); // 150 -> 1.5 ether
        _setForcedBidPriceBuffer(asset, a.forcedBidPriceBuffer); // 110 -> 1.1 ether
        _setMinimumCR(asset, a.minimumCR); // 110 -> 1.1 ether
        _setResetLiquidationTime(asset, a.resetLiquidationTime); // 1600 -> 16 hours
        _setSecondLiquidationTime(asset, a.secondLiquidationTime); // 1200 -> 12 hours
        _setFirstLiquidationTime(asset, a.firstLiquidationTime); // 1000 -> 10 hours
        _setTappFeePct(asset, a.tappFeePct); //25 -> .025 ether
        _setCallerFeePct(asset, a.callerFeePct); //5 -> .005 ether
        _setMinBidEth(asset, a.minBidEth); //1 -> 0.001 ether
        _setMinAskEth(asset, a.minAskEth); //1 -> 0.001 ether
        _setMinShortErc(asset, a.minShortErc); //2000 -> 2000 ether

        // Create TAPP short
        LibShortRecord.createShortRecord(
            asset, address(this), SR.FullyFilled, 0, 0, 0, 0, 0
        );
        emit Events.CreateMarket(asset, Asset);
    }

    //@dev does not need read only re-entrancy
    function owner() external view returns (address) {
        return LibDiamond.contractOwner();
    }

    function admin() external view returns (address) {
        return s.admin;
    }

    //@dev does not need read only re-entrancy
    function ownerCandidate() external view returns (address) {
        return s.ownerCandidate;
    }

    function transferOwnership(address newOwner) external onlyDAO {
        s.ownerCandidate = newOwner;
        emit Events.NewOwnerCandidate(newOwner);
    }

    //@dev event emitted in setContractOwner
    function claimOwnership() external {
        if (s.ownerCandidate != msg.sender) revert Errors.NotOwnerCandidate();
        LibDiamond.setContractOwner(msg.sender);
        delete s.ownerCandidate;
    }

    //No need for claim step because DAO can also set admin
    function transferAdminship(address newAdmin) external onlyAdminOrDAO {
        s.admin = newAdmin;
        emit Events.NewAdmin(newAdmin);
    }

    //When deactivating an asset make sure to zero out the oracle.
    function setAssetOracle(address asset, address oracle) external onlyDAO {
        _setAssetOracle(asset, oracle);
        emit Events.UpdateAssetOracle(asset, oracle);
    }

    function createVault(
        address zeth,
        uint256 vault,
        MTypes.CreateVaultParams calldata params
    ) external onlyDAO {
        if (s.zethVault[zeth] != 0) revert Errors.VaultAlreadyCreated();
        s.zethVault[zeth] = vault;
        _setTithe(vault, params.zethTithePercent);
        _setDittoMatchedRate(vault, params.dittoMatchedRate);
        _setDittoShorterRate(vault, params.dittoShorterRate);
        emit Events.CreateVault(zeth, vault);
    }

    // Update eligibility requirements for yield accrual
    function setTithe(uint256 vault, uint16 zethTithePercent) external onlyAdminOrDAO {
        _setTithe(vault, zethTithePercent);
        emit Events.ChangeVaultSetting(vault);
    }

    function setDittoMatchedRate(uint256 vault, uint16 rewardRate)
        external
        onlyAdminOrDAO
    {
        _setDittoMatchedRate(vault, rewardRate);
        emit Events.ChangeVaultSetting(vault);
    }

    function setDittoShorterRate(uint256 vault, uint16 rewardRate)
        external
        onlyAdminOrDAO
    {
        _setDittoShorterRate(vault, rewardRate);
        emit Events.ChangeVaultSetting(vault);
    }

    // For Short Record collateral ratios
    // initialMargin > primaryLiquidationCR > secondaryLiquidationCR > minimumCR
    // After initial market creation. Set CRs from smallest to largest to prevent triggering the require checks

    function setInitialMargin(address asset, uint16 value) external onlyAdminOrDAO {
        require(value > s.asset[asset].primaryLiquidationCR, "below primary liquidation");
        _setInitialMargin(asset, value);
        emit Events.ChangeMarketSetting(asset);
    }

    function setPrimaryLiquidationCR(address asset, uint16 value)
        external
        onlyAdminOrDAO
    {
        require(
            value > s.asset[asset].secondaryLiquidationCR, "below secondary liquidation"
        );
        _setPrimaryLiquidationCR(asset, value);
        emit Events.ChangeMarketSetting(asset);
    }

    function setSecondaryLiquidationCR(address asset, uint16 value)
        external
        onlyAdminOrDAO
    {
        _setSecondaryLiquidationCR(asset, value);
        require(
            LibAsset.secondaryLiquidationCR(asset) > LibAsset.minimumCR(asset),
            "below minimum CR"
        );
        emit Events.ChangeMarketSetting(asset);
    }

    function setForcedBidPriceBuffer(address asset, uint8 value)
        external
        onlyAdminOrDAO
    {
        _setForcedBidPriceBuffer(asset, value);
        emit Events.ChangeMarketSetting(asset);
    }

    function setMinimumCR(address asset, uint8 value) external onlyAdminOrDAO {
        _setMinimumCR(asset, value);
        emit Events.ChangeMarketSetting(asset);
    }

    // Used for Primary Margin Call
    // resetLiquidationTime > secondLiquidationTime > firstLiquidationTime

    function setResetLiquidationTime(address asset, uint16 value)
        external
        onlyAdminOrDAO
    {
        _setResetLiquidationTime(asset, value);
        require(
            value >= s.asset[asset].secondLiquidationTime, "below secondLiquidationTime"
        );
        emit Events.ChangeMarketSetting(asset);
    }

    function setSecondLiquidationTime(address asset, uint16 value)
        external
        onlyAdminOrDAO
    {
        _setSecondLiquidationTime(asset, value);
        require(
            value >= s.asset[asset].firstLiquidationTime, "below firstLiquidationTime"
        );
        emit Events.ChangeMarketSetting(asset);
    }

    function setFirstLiquidationTime(address asset, uint16 value)
        external
        onlyAdminOrDAO
    {
        _setFirstLiquidationTime(asset, value);
        emit Events.ChangeMarketSetting(asset);
    }

    function setTappFeePct(address asset, uint8 value) external onlyAdminOrDAO {
        _setTappFeePct(asset, value);
        emit Events.ChangeMarketSetting(asset);
    }

    function setCallerFeePct(address asset, uint8 value) external onlyAdminOrDAO {
        _setCallerFeePct(asset, value);
        emit Events.ChangeMarketSetting(asset);
    }

    function setMinBidEth(address asset, uint8 value) external onlyAdminOrDAO {
        _setMinBidEth(asset, value);
        emit Events.ChangeMarketSetting(asset);
    }

    function setMinAskEth(address asset, uint8 value) external onlyAdminOrDAO {
        _setMinAskEth(asset, value);
        emit Events.ChangeMarketSetting(asset);
    }

    function setMinShortErc(address asset, uint16 value) external onlyAdminOrDAO {
        _setMinShortErc(asset, value);
        emit Events.ChangeMarketSetting(asset);
    }

    function createBridge(
        address bridge,
        uint256 vault,
        uint16 withdrawalFee,
        uint8 unstakeFee
    ) external onlyDAO {
        s.vaultBridges[vault].push(bridge);
        s.bridge[bridge].vault = uint8(vault);
        _setWithdrawalFee(bridge, withdrawalFee);
        _setUnstakeFee(bridge, unstakeFee);
        emit Events.CreateBridge(bridge, s.bridge[bridge]);
    }

    function deleteBridge(address bridge) external onlyDAO {
        uint256 vault = s.bridge[bridge].vault;
        if (vault == 0) revert Errors.InvalidBridge();

        address[] storage VaultBridges = s.vaultBridges[vault];
        uint256 length = VaultBridges.length;
        for (uint256 i; i < length; i++) {
            if (VaultBridges[i] == bridge) {
                if (i != length - 1) {
                    VaultBridges[i] = VaultBridges[length - 1];
                }
                VaultBridges.pop();
                break;
            }
        }
        delete s.bridge[bridge];
        emit Events.DeleteBridge(bridge);
    }

    function setWithdrawalFee(address bridge, uint16 withdrawalFee)
        external
        onlyAdminOrDAO
    {
        _setWithdrawalFee(bridge, withdrawalFee);
        emit Events.ChangeBridgeSetting(bridge);
    }

    function setUnstakeFee(address bridge, uint8 unstakeFee) external onlyAdminOrDAO {
        _setUnstakeFee(bridge, unstakeFee);
        emit Events.ChangeBridgeSetting(bridge);
    }

    function _setAssetOracle(address asset, address oracle) private {
        if (asset == address(0) || oracle == address(0)) revert Errors.ParameterIsZero();
        s.asset[asset].oracle = oracle;
    }

    function _setTithe(uint256 vault, uint16 zethTithePercent) private {
        if (zethTithePercent > 33_33) revert Errors.InvalidTithe();
        s.vault[vault].zethTithePercent = zethTithePercent;
    }

    function _setDittoMatchedRate(uint256 vault, uint16 rewardRate) private {
        require(rewardRate <= 100, "above 100");
        s.vault[vault].dittoMatchedRate = rewardRate;
    }

    function _setDittoShorterRate(uint256 vault, uint16 rewardRate) private {
        require(rewardRate <= 100, "above 100");
        s.vault[vault].dittoShorterRate = rewardRate;
    }

    function _setInitialMargin(address asset, uint16 value) private {
        require(value > 100, "below 1.0");
        s.asset[asset].initialMargin = value;
        require(LibAsset.initialMargin(asset) < Constants.CRATIO_MAX, "above max CR");
    }

    function _setPrimaryLiquidationCR(address asset, uint16 value) private {
        require(value > 100, "below 1.0");
        require(value <= 500, "above 5.0");
        require(value < s.asset[asset].initialMargin, "above initial margin");
        s.asset[asset].primaryLiquidationCR = value;
    }

    function _setSecondaryLiquidationCR(address asset, uint16 value) private {
        require(value > 100, "below 1.0");
        require(value <= 500, "above 5.0");
        require(value < s.asset[asset].primaryLiquidationCR, "above primary liquidation");
        s.asset[asset].secondaryLiquidationCR = value;
    }

    function _setForcedBidPriceBuffer(address asset, uint8 value) private {
        require(value >= 100, "below 1.0");
        require(value <= 200, "above 2.0");
        s.asset[asset].forcedBidPriceBuffer = value;
    }

    function _setMinimumCR(address asset, uint8 value) private {
        require(value >= 100, "below 1.0");
        require(value <= 200, "above 2.0");
        s.asset[asset].minimumCR = value;
        require(
            LibAsset.minimumCR(asset) < LibAsset.secondaryLiquidationCR(asset),
            "above secondary liquidation"
        );
    }

    // Used for Primary Margin Call
    // resetLiquidationTime > secondLiquidationTime > firstLiquidationTime

    function _setResetLiquidationTime(address asset, uint16 value) private {
        require(value >= 100, "below 1.00");
        require(value <= 4800, "above 48.00");
        s.asset[asset].resetLiquidationTime = value;
    }

    function _setSecondLiquidationTime(address asset, uint16 value) private {
        require(value >= 100, "below 1.00");
        require(
            value <= s.asset[asset].resetLiquidationTime, "above resetLiquidationTime"
        );
        s.asset[asset].secondLiquidationTime = value;
    }

    function _setFirstLiquidationTime(address asset, uint16 value) private {
        require(value >= 100, "below 1.00");
        require(
            value <= s.asset[asset].secondLiquidationTime, "above secondLiquidationTime"
        );
        s.asset[asset].firstLiquidationTime = value;
    }

    function _setTappFeePct(address asset, uint8 value) private {
        require(value > 0, "Can't be zero");
        require(value <= 250, "above 25.0");
        s.asset[asset].tappFeePct = value;
    }

    function _setCallerFeePct(address asset, uint8 value) private {
        require(value > 0, "Can't be zero");
        require(value <= 250, "above 25.0");
        s.asset[asset].callerFeePct = value;
    }

    function _setMinBidEth(address asset, uint8 value) private {
        //no upperboard check because uint8 max - 255
        require(value > 0, "Can't be zero");
        s.asset[asset].minBidEth = value;
    }

    function _setMinAskEth(address asset, uint8 value) private {
        //no upperboard check because uint8 max - 255
        require(value > 0, "Can't be zero");
        s.asset[asset].minAskEth = value;
    }

    function _setMinShortErc(address asset, uint16 value) private {
        //no upperboard check because uint8 max - 65,535
        require(value > 0, "Can't be zero");
        s.asset[asset].minShortErc = value;
    }

    function _setWithdrawalFee(address bridge, uint16 withdrawalFee) private {
        require(withdrawalFee <= 1500, "above 15.00%");
        s.bridge[bridge].withdrawalFee = withdrawalFee;
    }

    function _setUnstakeFee(address bridge, uint8 unstakeFee) private {
        require(unstakeFee <= 250, "above 2.50%");
        s.bridge[bridge].unstakeFee = unstakeFee;
    }
}
