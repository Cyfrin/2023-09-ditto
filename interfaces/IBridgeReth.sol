// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;



interface IBridgeReth {

  // functions from contracts/bridges/BridgeReth.sol
  receive() external payable;
  function getBaseCollateral() external view returns (address);
  function getZethValue() external view returns (uint256);
  function deposit(address from, uint256 amount) external returns (uint256);
  function depositEth() external payable returns (uint256);
  function withdraw(address to, uint256 amount) external returns (uint256);
  function unstake(address to, uint256 amount) external;
}