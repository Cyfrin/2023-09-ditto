// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {STypes, F, SR} from "contracts/libraries/DataTypes.sol";
import {LibDiamond} from "contracts/libraries/LibDiamond.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {Constants} from "contracts/libraries/Constants.sol";

// import {console} from "contracts/libraries/console.sol";

struct AppStorage {
    address ownerCandidate;
    address oracle; // base oracle
    uint24 flaggerIdCounter;
    uint40 tokenIdCounter; //NFT - As of 2023, Ethereum had ~2B total tx. Uint40 max value is 1T, which is more than enough
    uint8 reentrantStatus;
    // ZETH
    mapping(address zeth => uint256 vault) zethVault;
    // Bridge
    mapping(address bridge => STypes.Bridge) bridge;
    // Vault
    mapping(uint256 vault => STypes.Vault) vault;
    mapping(uint256 vault => address[]) vaultBridges;
    mapping(uint256 vault => mapping(address account => STypes.VaultUser)) vaultUser;
    // Assets
    mapping(address asset => STypes.Asset) asset;
    mapping(address asset => mapping(address account => STypes.AssetUser)) assetUser;
    // Assets - Orderbook
    mapping(address asset => mapping(uint16 id => STypes.Order)) bids;
    mapping(address asset => mapping(uint16 id => STypes.Order)) asks;
    mapping(address asset => mapping(uint16 id => STypes.Order)) shorts;
    mapping(
        address asset
            => mapping(address account => mapping(uint8 id => STypes.ShortRecord))
        ) shortRecords;
    mapping(uint24 flaggerId => address flagger) flagMapping;
    // ERC721
    mapping(uint256 tokenId => STypes.NFT) nftMapping;
    mapping(uint256 tokenId => address) getApproved;
    mapping(address owner => mapping(address operator => bool)) isApprovedForAll;
    // ERC721 - Assets
    address[] assets;
    mapping(uint256 assetId => address) assetMapping;
    // ERC721 - METADATA STORAGE/LOGIC
    string name;
    string symbol;
}

function appStorage() pure returns (AppStorage storage s) {
    // solhint-disable-next-line no-inline-assembly
    assembly {
        s.slot := 0
    }
}

contract Modifiers {
    AppStorage internal s;

    modifier onlyOwner() {
        LibDiamond.enforceIsContractOwner();
        _;
    }

    modifier onlyDiamond() {
        if (msg.sender != address(this)) revert Errors.NotDiamond();
        _;
    }

    modifier onlyValidAsset(address asset) {
        if (s.asset[asset].vault == 0) revert Errors.InvalidAsset();
        _;
    }

    modifier isNotFrozen(address asset) {
        if (s.asset[asset].frozen != F.Unfrozen) revert Errors.AssetIsFrozen();
        _;
    }

    modifier isPermanentlyFrozen(address asset) {
        if (s.asset[asset].frozen != F.Permanent) {
            revert Errors.AssetIsNotPermanentlyFrozen();
        }
        _;
    }

    function _onlyValidShortRecord(address asset, address shorter, uint8 id)
        internal
        view
    {
        uint8 maxId = s.assetUser[asset][shorter].shortRecordId;
        if (id >= maxId) revert Errors.InvalidShortId();
        if (id < Constants.SHORT_STARTING_ID) revert Errors.InvalidShortId();
        if (s.shortRecords[asset][shorter][id].status == SR.Cancelled) {
            revert Errors.InvalidShortId();
        }
    }

    modifier onlyValidShortRecord(address asset, address shorter, uint8 id) {
        _onlyValidShortRecord(asset, shorter, id);
        _;
    }

    modifier nonReentrant() {
        if (s.reentrantStatus == Constants.ENTERED) revert Errors.ReentrantCall();
        s.reentrantStatus = Constants.ENTERED;
        _;
        s.reentrantStatus = Constants.NOT_ENTERED;
    }

    modifier nonReentrantView() {
        if (s.reentrantStatus == Constants.ENTERED) revert Errors.ReentrantCallView();
        _;
    }

    modifier onlyValidBridge(address bridge) {
        if (s.bridge[bridge].vault == 0) revert Errors.InvalidBridge();
        _;
    }
}
