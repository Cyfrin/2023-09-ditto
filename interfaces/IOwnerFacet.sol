// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;


import {STypes,MTypes,SR} from "contracts/libraries/DataTypes.sol";

interface IOwnerFacet {

  // functions from contracts/facets/OwnerFacet.sol
  function createMarket(address asset, STypes.Asset memory a) external;
  function owner() external view returns (address);
  function admin() external view returns (address);
  function ownerCandidate() external view returns (address);
  function transferOwnership(address newOwner) external;
  function claimOwnership() external;
  function transferAdminship(address newAdmin) external;
  function setAssetOracle(address asset, address oracle) external;
  function createVault(
        address zeth, uint256 vault, MTypes.CreateVaultParams calldata params) external;
  function setTithe(uint256 vault, uint16 zethTithePercent) external;
  function setDittoMatchedRate(uint256 vault, uint16 rewardRate) external;
  function setDittoShorterRate(uint256 vault, uint16 rewardRate) external;
  function setInitialMargin(address asset, uint16 value) external;
  function setPrimaryLiquidationCR(address asset, uint16 value) external;
  function setSecondaryLiquidationCR(address asset, uint16 value) external;
  function setForcedBidPriceBuffer(address asset, uint8 value) external;
  function setMinimumCR(address asset, uint8 value) external;
  function setResetLiquidationTime(address asset, uint16 value) external;
  function setSecondLiquidationTime(address asset, uint16 value) external;
  function setFirstLiquidationTime(address asset, uint16 value) external;
  function setTappFeePct(address asset, uint8 value) external;
  function setCallerFeePct(address asset, uint8 value) external;
  function setMinBidEth(address asset, uint8 value) external;
  function setMinAskEth(address asset, uint8 value) external;
  function setMinShortErc(address asset, uint16 value) external;
  function createBridge(
        address bridge, uint256 vault, uint16 withdrawalFee, uint8 unstakeFee) external;
  function deleteBridge(address bridge) external;
  function setWithdrawalFee(address bridge, uint16 withdrawalFee) external;
  function setUnstakeFee(address bridge, uint8 unstakeFee) external;
}