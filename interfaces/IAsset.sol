// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;



interface IAsset {

  // functions from node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol
  function name() external view returns (string memory);
  function symbol() external view returns (string memory);
  function decimals() external view returns (uint8);
  function totalSupply() external view returns (uint256);
  function balanceOf(address account) external view returns (uint256);
  function transfer(address to, uint256 amount) external returns (bool);
  function allowance(address owner, address spender) external view returns (uint256);
  function approve(address spender, uint256 amount) external returns (bool);
  function transferFrom(address from, address to, uint256 amount) external returns (bool);
  function increaseAllowance(address spender, uint256 addedValue) external returns (bool);
  function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);

  // functions from contracts/tokens/Asset.sol
  function mint(address to, uint256 amount) external;
  function burnFrom(address account, uint256 amount) external;
}