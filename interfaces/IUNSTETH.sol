// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;



interface IUNSTETH {

  // functions from node_modules/@openzeppelin/contracts/utils/introspection/ERC165.sol
  function supportsInterface(bytes4 interfaceId) external view returns (bool);

  // functions from node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol
  function balanceOf(address owner) external view returns (uint256);
  function ownerOf(uint256 tokenId) external view returns (address);
  function name() external view returns (string memory);
  function symbol() external view returns (string memory);
  function tokenURI(uint256 tokenId) external view returns (string memory);
  function approve(address to, uint256 tokenId) external;
  function getApproved(uint256 tokenId) external view returns (address);
  function setApprovalForAll(address operator, bool approved) external;
  function isApprovedForAll(address owner, address operator) external view returns (bool);
  function transferFrom(address from, address to, uint256 tokenId) external;
  function safeTransferFrom(address from, address to, uint256 tokenId) external;
  function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) external;

  // functions from contracts/mocks/UNSTETH.sol
  receive() external payable;
  function claimWithdrawals(
        uint256[] calldata _requestIds, uint256[] calldata) external;
  function requestWithdrawals(uint256[] calldata _amounts, address _owner) external returns (uint256[] memory requestIds);
  function processWithdrawals() external;
}