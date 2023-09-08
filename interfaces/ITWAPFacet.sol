// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;



interface ITWAPFacet {

  // functions from contracts/facets/TWAPFacet.sol
  function estimateWETHInUSDC(uint128 amountIn, uint32 secondsAgo) external view returns (uint256 amountOut);
}