// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;



interface IBidOrdersFacet {

  // functions from contracts/facets/BidOrdersFacet.sol
  function createBid(
        address asset, uint80 price, uint88 ercAmount, bool isMarketOrder, MTypes.OrderHint[] calldata orderHintArray, uint16[] calldata shortHintArray) external returns (uint88 ethFilled, uint88 ercAmountLeft);
  function createForcedBid(
        address sender, address asset, uint80 price, uint88 ercAmount, uint16[] calldata shortHintArray) external returns (uint88 ethFilled, uint88 ercAmountLeft);
}