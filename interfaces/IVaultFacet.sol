// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;



interface IVaultFacet {

  // functions from contracts/facets/VaultFacet.sol
  function depositZETH(address zeth, uint88 amount) external;
  function depositAsset(address asset, uint104 amount) external;
  function withdrawZETH(address zeth, uint88 amount) external;
  function withdrawAsset(address asset, uint104 amount) external;
}