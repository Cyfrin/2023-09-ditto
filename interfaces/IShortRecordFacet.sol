// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;



interface IShortRecordFacet {

  // functions from contracts/facets/ShortRecordFacet.sol
  function increaseCollateral(address asset, uint8 id, uint88 amount) external;
  function decreaseCollateral(address asset, uint8 id, uint88 amount) external;
  function combineShorts(address asset, uint8[] memory ids) external;
}