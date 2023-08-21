// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {STypes, O, F} from "contracts/libraries/DataTypes.sol";
import {Modifiers} from "contracts/libraries/AppStorage.sol";
import {LibOracle} from "contracts/libraries/LibOracle.sol";
import {LibOrders} from "contracts/libraries/LibOrders.sol";
import {LibAsset} from "contracts/libraries/LibAsset.sol";
import {LibBridge} from "contracts/libraries/LibBridge.sol";
import {Constants, Vault} from "contracts/libraries/Constants.sol";

import {TestTypes} from "test/utils/TestTypes.sol";
// import {console} from "contracts/libraries/console.sol";

// @dev dev-only
contract TestFacet is Modifiers {
    using LibOrders for mapping(address => mapping(uint16 => STypes.Order));

    address private immutable baseAsset;

    constructor(address asset) {
        baseAsset = asset;
    }

    function setFrozen(address asset, F value) external onlyOwner {
        s.asset[asset].frozen = value;
    }

    // @dev same as OwnerFacet.setPrimaryLiquidationCR without requires for testing
    function setprimaryLiquidationCRT(address asset, uint16 value) external onlyOwner {
        s.asset[asset].primaryLiquidationCR = value;
    }

    function getAskKey(address asset, uint16 id)
        external
        view
        returns (uint16 prevId, uint16 nextId)
    {
        return (s.asks[asset][id].prevId, s.asks[asset][id].nextId);
    }

    function getBidKey(address asset, uint16 id)
        external
        view
        returns (uint16 prevId, uint16 nextId)
    {
        return (s.bids[asset][id].prevId, s.bids[asset][id].nextId);
    }

    function getBidOrder(address asset, uint16 id)
        external
        view
        returns (STypes.Order memory bid)
    {
        return s.bids[asset][id];
    }

    function getAskOrder(address asset, uint16 id)
        external
        view
        returns (STypes.Order memory ask)
    {
        return s.asks[asset][id];
    }

    function getShortOrder(address asset, uint16 id)
        external
        view
        returns (STypes.Order memory short)
    {
        return s.shorts[asset][id];
    }

    function currentInactiveBids(address asset)
        external
        view
        returns (STypes.Order[] memory)
    {
        uint16 currentId = s.bids[asset][Constants.HEAD].prevId;
        uint256 orderSize;

        while (currentId != Constants.HEAD) {
            orderSize++;
            currentId = s.bids[asset][currentId].prevId;
        }

        STypes.Order[] memory orderArr = new STypes.Order[](orderSize);
        currentId = s.bids[asset][Constants.HEAD].prevId; // reset currentId

        for (uint256 i = 0; i < orderSize; i++) {
            orderArr[i] = s.bids[asset][currentId];
            currentId = orderArr[i].prevId;
        }
        return orderArr;
    }

    function currentInactiveAsks(address asset)
        external
        view
        returns (STypes.Order[] memory)
    {
        uint16 currentId = s.asks[asset][Constants.HEAD].prevId;
        uint256 orderSize;

        while (currentId != Constants.HEAD) {
            orderSize++;
            currentId = s.asks[asset][currentId].prevId;
        }

        STypes.Order[] memory orderArr = new STypes.Order[](orderSize);
        currentId = s.asks[asset][Constants.HEAD].prevId; // reset currentId

        for (uint256 i = 0; i < orderSize; i++) {
            orderArr[i] = s.asks[asset][currentId];
            currentId = orderArr[i].prevId;
        }
        return orderArr;
    }

    function currentInactiveShorts(address asset)
        external
        view
        returns (STypes.Order[] memory)
    {
        uint16 currentId = s.shorts[asset][Constants.HEAD].prevId;
        uint256 orderSize;

        while (currentId != Constants.HEAD) {
            orderSize++;
            currentId = s.shorts[asset][currentId].prevId;
        }

        STypes.Order[] memory orderArr = new STypes.Order[](orderSize);
        currentId = s.shorts[asset][Constants.HEAD].prevId; // reset currentId

        for (uint256 i = 0; i < orderSize; i++) {
            orderArr[i] = s.shorts[asset][currentId];
            currentId = orderArr[i].prevId;
        }
        return orderArr;
    }

    function setReentrantStatus(uint8 reentrantStatus) external {
        s.reentrantStatus = reentrantStatus;
    }

    function getReentrantStatus() external view returns (uint256) {
        return s.reentrantStatus;
    }

    function getAssetNormalizedStruct(address asset)
        external
        view
        returns (TestTypes.AssetNormalizedStruct memory)
    {
        return TestTypes.AssetNormalizedStruct({
            frozen: s.asset[asset].frozen,
            orderId: s.asset[asset].orderId,
            initialMargin: LibAsset.initialMargin(asset),
            primaryLiquidationCR: LibAsset.primaryLiquidationCR(asset),
            secondaryLiquidationCR: LibAsset.secondaryLiquidationCR(asset),
            forcedBidPriceBuffer: LibAsset.forcedBidPriceBuffer(asset),
            minimumCR: LibAsset.minimumCR(asset),
            tappFeePct: LibAsset.tappFeePct(asset),
            callerFeePct: LibAsset.callerFeePct(asset),
            resetLiquidationTime: LibAsset.resetLiquidationTime(asset),
            secondLiquidationTime: LibAsset.secondLiquidationTime(asset),
            firstLiquidationTime: LibAsset.firstLiquidationTime(asset),
            startingShortId: s.asset[asset].startingShortId,
            minBidEth: LibAsset.minBidEth(asset),
            minAskEth: LibAsset.minAskEth(asset),
            minShortErc: LibAsset.minShortErc(asset),
            assetId: s.asset[asset].assetId
        });
    }

    function getBridgeNormalizedStruct(address bridge)
        external
        view
        returns (TestTypes.BridgeNormalizedStruct memory)
    {
        return TestTypes.BridgeNormalizedStruct({
            withdrawalFee: LibBridge.withdrawalFee(bridge),
            unstakeFee: LibBridge.unstakeFee(bridge)
        });
    }

    // @dev used for gas testing
    function setOracleTimeAndPrice(address asset, uint256 price) external {
        LibOracle.setPriceAndTime(asset, price, LibOrders.getOffsetTime());
    }

    function getOracleTimeT(address asset) external view returns (uint256 oracleTime) {
        return LibOracle.getTime(asset);
    }

    function getOraclePriceT(address asset) external view returns (uint80 oraclePrice) {
        return LibOracle.getPrice(asset);
    }

    // @dev used to test shortHintId
    function setStartingShortId(address asset, uint16 id) external {
        s.asset[asset].startingShortId = id;
    }

    // @dev used to test shortHintId
    function nonZeroVaultSlot0(uint256 vault) external {
        s.vault[vault].zethYieldRate += 1;
    }

    function setforcedBidPriceBufferT(address asset, uint8 value) external onlyOwner {
        s.asset[asset].forcedBidPriceBuffer = value;
    }

    function setErcDebtRate(address asset, uint64 value) external {
        s.asset[asset].ercDebtRate = value;
    }

    function setOrderIdT(address asset, uint16 value) external onlyOwner {
        s.asset[asset].orderId = value;
    }

    function setEthEscrowed(address addr, uint88 eth) external {
        s.vaultUser[Vault.CARBON][addr].ethEscrowed = eth;
    }

    function setErcEscrowed(address asset, address addr, uint104 erc) external {
        s.assetUser[asset][addr].ercEscrowed = erc;
    }

    function getUserOrders(address asset, address addr, O orderType)
        external
        view
        returns (STypes.Order[] memory orders)
    {
        STypes.Order[] memory allOrders;

        if (orderType == O.LimitBid) {
            allOrders = s.bids.currentOrders(asset);
        } else if (orderType == O.LimitAsk) {
            allOrders = s.asks.currentOrders(asset);
        } else if (orderType == O.LimitShort) {
            allOrders = s.shorts.currentOrders(asset);
        }
        uint256 counter = 0;

        for (uint256 i = 0; i < allOrders.length; i++) {
            if (allOrders[i].addr == addr) counter++;
        }

        orders = new STypes.Order[](counter);
        counter = 0;

        for (uint256 i = 0; i < allOrders.length; i++) {
            if (allOrders[i].addr == addr) {
                orders[counter] = allOrders[i];
                counter++;
            }
        }
        return orders;
    }

    function getAssets() external view returns (address[] memory) {
        return s.assets;
    }

    function getAssetsMapping(uint256 assetId) external view returns (address) {
        return s.assetMapping[assetId];
    }

    function setTokenId(uint40 tokenId) external {
        s.tokenIdCounter = tokenId;
    }

    function getTokenId() external view returns (uint40 tokenId) {
        return s.tokenIdCounter;
    }

    function getNFT(uint256 tokenId) external view returns (STypes.NFT memory nft) {
        return s.nftMapping[tokenId];
    }

    function getNFTName() external view returns (string memory) {
        return s.name;
    }

    function getNFTSymbol() external view returns (string memory) {
        return s.symbol;
    }

    function setFlaggerIdCounter(uint24 flaggerIdCounter) external {
        s.flaggerIdCounter = flaggerIdCounter;
    }

    function getFlaggerIdCounter() external view returns (uint24 flaggerId) {
        return s.flaggerIdCounter;
    }

    function getFlagger(uint24 flaggerId) external view returns (address flagger) {
        return s.flagMapping[flaggerId];
    }

    function getZethYieldRate(uint256 vault) external view returns (uint80) {
        return s.vault[vault].zethYieldRate;
    }
}
