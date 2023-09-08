// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;



interface IMarketShutdownFacet {

  // functions from contracts/facets/MarketShutdownFacet.sol
  function shutdownMarket(address asset) external;
  function redeemErc(address asset, uint88 amtWallet, uint88 amtEscrow) external;
}