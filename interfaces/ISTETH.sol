// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;



interface ISTETH {

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

  // functions from node_modules/@openzeppelin/contracts/utils/cryptography/EIP712.sol
  function eip712Domain() external view returns (bytes1 fields, string memory name, string memory version, uint256 chainId, address verifyingContract, bytes32 salt, uint256[] memory extensions);

  // functions from node_modules/@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol
  function permit(
        address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
  function nonces(address owner) external view returns (uint256);
  function DOMAIN_SEPARATOR() external view returns (bytes32);

  // functions from contracts/mocks/STETH.sol
  function mint(address to, uint256 amount) external;
  function burn(uint256 amount) external;
  function transferWithdrawalEth(uint256 amount) external;
  function submit(address ref) external payable returns (uint256);
}