// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;



interface IShortOrdersFacet {

  // functions from contracts/facets/ShortOrdersFacet.sol
  function createLimitShort(
        address asset, uint80 price, uint88 ercAmount, MTypes.OrderHint[] memory orderHintArray, uint16[] memory shortHintArray, uint16 initialCR) external;
}