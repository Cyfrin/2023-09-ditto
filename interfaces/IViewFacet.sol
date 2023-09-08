// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;


import {STypes,MTypes,O,SR} from "contracts/libraries/DataTypes.sol";

interface IViewFacet {

  // functions from contracts/facets/ViewFacet.sol
  function getZethBalance(uint256 vault, address user) external view returns (uint256);
  function getAssetBalance(address asset, address user) external view returns (uint256);
  function getVault(address asset) external view returns (uint256);
  function getBridgeVault(address bridge) external view returns (uint256);
  function getBids(address asset) external view returns (STypes.Order[] memory);
  function getAsks(address asset) external view returns (STypes.Order[] memory);
  function getShorts(address asset) external view returns (STypes.Order[] memory);
  function getBidHintId(address asset, uint256 price) external view returns (uint16 hintId);
  function getAskHintId(address asset, uint256 price) external view returns (uint16 hintId);
  function getShortHintId(address asset, uint256 price) external view returns (uint16);
  function getShortIdAtOracle(address asset) external view returns (uint16 shortHintId);
  function getHintArray(address asset, uint256 price, O orderType) external view returns (MTypes.OrderHint[] memory orderHintArray);
  function getCollateralRatio(address asset, STypes.ShortRecord memory short) external view returns (uint256 cRatio);
  function getCollateralRatioSpotPrice(address asset, STypes.ShortRecord memory short) external view returns (uint256 cRatio);
  function getAssetPrice(address asset) external view returns (uint256);
  function getProtocolAssetPrice(address asset) external view returns (uint256);
  function getTithe(uint256 vault) external view returns (uint256);
  function getUndistributedYield(uint256 vault) external view returns (uint256);
  function getYield(address asset, address user) external view returns (uint256 shorterYield);
  function getDittoMatchedReward(uint256 vault, address user) external view returns (uint256);
  function getDittoReward(uint256 vault, address user) external view returns (uint256);
  function getAssetCollateralRatio(address asset) external view returns (uint256 cRatio);
  function getShortRecords(address asset, address shorter) external view returns (STypes.ShortRecord[] memory shorts);
  function getShortRecord(address asset, address shorter, uint8 id) external view returns (STypes.ShortRecord memory shortRecord);
  function getShortRecordCount(address asset, address shorter) external view returns (uint256 shortRecordCount);
  function getAssetUserStruct(address asset, address user) external view returns (STypes.AssetUser memory);
  function getVaultUserStruct(uint256 vault, address user) external view returns (STypes.VaultUser memory);
  function getVaultStruct(uint256 vault) external view returns (STypes.Vault memory);
  function getAssetStruct(address asset) external view returns (STypes.Asset memory);
  function getBridgeStruct(address bridge) external view returns (STypes.Bridge memory);
  function getOffsetTimeHours() external view returns (uint256);
  function getOffsetTime() external view returns (uint256);
  function getFlaggerId(address asset, address user) external view returns (uint24 flaggerId);
}