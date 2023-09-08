// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;



interface IRocketStorage {

  // functions from contracts/mocks/RocketStorage.sol
  function getAddress(bytes32 _key) external view returns (address r);
  function setReth(address addr) external;
  function setDeposit(address addr) external;
}