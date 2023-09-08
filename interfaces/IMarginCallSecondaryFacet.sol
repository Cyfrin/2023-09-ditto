// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;



interface IMarginCallSecondaryFacet {

  // functions from contracts/facets/MarginCallSecondaryFacet.sol
  function liquidateSecondary(
        address asset, MTypes.BatchMC[] memory batches, uint88 liquidateAmount, bool isWallet) external;
}