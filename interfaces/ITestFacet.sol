// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;


import {STypes,O,F} from "contracts/libraries/DataTypes.sol";
import {TestTypes} from "test/utils/TestTypes.sol";

interface ITestFacet {

  // functions from contracts/facets/TestFacet.sol
  function setFrozenT(address asset, F value) external;
  function setprimaryLiquidationCRT(address asset, uint16 value) external;
  function getAskKey(address asset, uint16 id) external view returns (uint16 prevId, uint16 nextId);
  function getBidKey(address asset, uint16 id) external view returns (uint16 prevId, uint16 nextId);
  function getBidOrder(address asset, uint16 id) external view returns (STypes.Order memory bid);
  function getAskOrder(address asset, uint16 id) external view returns (STypes.Order memory ask);
  function getShortOrder(address asset, uint16 id) external view returns (STypes.Order memory short);
  function currentInactiveBids(address asset) external view returns (STypes.Order[] memory);
  function currentInactiveAsks(address asset) external view returns (STypes.Order[] memory);
  function currentInactiveShorts(address asset) external view returns (STypes.Order[] memory);
  function setReentrantStatus(uint8 reentrantStatus) external;
  function getReentrantStatus() external view returns (uint256);
  function getAssetNormalizedStruct(address asset) external view returns (TestTypes.AssetNormalizedStruct memory);
  function getBridgeNormalizedStruct(address bridge) external view returns (TestTypes.BridgeNormalizedStruct memory);
  function setOracleTimeAndPrice(address asset, uint256 price) external;
  function getOracleTimeT(address asset) external view returns (uint256 oracleTime);
  function getOraclePriceT(address asset) external view returns (uint80 oraclePrice);
  function setStartingShortId(address asset, uint16 id) external;
  function nonZeroVaultSlot0(uint256 vault) external;
  function setforcedBidPriceBufferT(address asset, uint8 value) external;
  function setErcDebtRate(address asset, uint64 value) external;
  function setOrderIdT(address asset, uint16 value) external;
  function setEthEscrowed(address addr, uint88 eth) external;
  function setErcEscrowed(address asset, address addr, uint104 erc) external;
  function getUserOrders(address asset, address addr, O orderType) external view returns (STypes.Order[] memory orders);
  function getAssets() external view returns (address[] memory);
  function getAssetsMapping(uint256 assetId) external view returns (address);
  function setTokenId(uint40 tokenId) external;
  function getTokenId() external view returns (uint40 tokenId);
  function getNFT(uint256 tokenId) external view returns (STypes.NFT memory nft);
  function getNFTName() external view returns (string memory);
  function getNFTSymbol() external view returns (string memory);
  function setFlaggerIdCounter(uint24 flaggerIdCounter) external;
  function getFlaggerIdCounter() external view returns (uint24 flaggerId);
  function getFlagger(uint24 flaggerId) external view returns (address flagger);
  function getZethYieldRate(uint256 vault) external view returns (uint80);
}