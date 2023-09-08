// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import "contracts/interfaces/IDiamondLoupe.sol";

interface IDiamondLoupeFacet {

  // functions from contracts/facets/DiamondLoupeFacet.sol
  function facets() external view returns (IDiamondLoupe.Facet[] memory facets_);
  function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory _facetFunctionSelectors);
  function facetAddresses() external view returns (address[] memory facetAddresses_);
  function facetAddress(bytes4 _functionSelector) external view returns (address facetAddress_);
}