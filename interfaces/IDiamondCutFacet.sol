// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import "contracts/interfaces/IDiamondCut.sol";

interface IDiamondCutFacet {

  // functions from contracts/facets/DiamondCutFacet.sol
  function diamondCut(
        IDiamondCut.FacetCut[] calldata _diamondCut, address _init, bytes calldata _calldata) external;
}