// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;



interface IERC721Facet {

  // functions from contracts/facets/ERC721Facet.sol
  function balanceOf(address owner) external view returns (uint256 balance);
  function ownerOf(uint256 tokenId) external view returns (address);
  function safeTransferFrom(address from, address to, uint256 tokenId) external;
  function safeTransferFrom(
        address from, address to, uint256 tokenId, bytes memory data) external;
  function transferFrom(address from, address to, uint256 tokenId) external;
  function isApprovedForAll(address owner, address operator) external view returns (bool);
  function approve(address to, uint256 tokenId) external;
  function setApprovalForAll(address operator, bool approved) external;
  function getApproved(uint256 tokenId) external view returns (address operator);
  function mintNFT(address asset, uint8 shortRecordId) external;
  function tokenURI(uint256 id) external view returns (string memory);
  function supportsInterface(bytes4 _interfaceId) external view returns (bool);
}