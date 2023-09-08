// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;



interface IOrdersFacet {

  // functions from contracts/facets/OrdersFacet.sol
  function cancelBid(address asset, uint16 id) external;
  function cancelAsk(address asset, uint16 id) external;
  function cancelShort(address asset, uint16 id) external;
  function cancelOrderFarFromOracle(
        address asset, O orderType, uint16 lastOrderId, uint16 numOrdersToCancel) external;
}