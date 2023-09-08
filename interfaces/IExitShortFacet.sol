// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;



interface IExitShortFacet {

  // functions from contracts/facets/ExitShortFacet.sol
  function exitShortWallet(address asset, uint8 id, uint88 buyBackAmount) external;
  function exitShortErcEscrowed(address asset, uint8 id, uint88 buyBackAmount) external;
  function exitShort(
        address asset, uint8 id, uint88 buyBackAmount, uint80 price, uint16[] memory shortHintArray) external;
}