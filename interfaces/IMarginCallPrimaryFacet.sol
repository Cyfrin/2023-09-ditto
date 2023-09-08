// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;



interface IMarginCallPrimaryFacet {

  // functions from contracts/facets/MarginCallPrimaryFacet.sol
  function flagShort(address asset, address shorter, uint8 id, uint16 flaggerHint) external;
  function liquidate(
        address asset, address shorter, uint8 id, uint16[] memory shortHintArray) external returns (uint88, uint88);
}