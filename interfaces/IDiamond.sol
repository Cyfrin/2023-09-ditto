// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {IDiamondLoupe} from "contracts/interfaces/IDiamondLoupe.sol";
import {IDiamondCut} from "contracts/interfaces/IDiamondCut.sol";
import "contracts/libraries/DataTypes.sol";
import "test/utils/TestTypes.sol";

interface IDiamond {

  // functions from contracts/Diamond.sol
  fallback() external payable;
  receive() external payable;
  // functions from contracts/facets/DiamondCutFacet.sol
  function diamondCut(
        IDiamondCut.FacetCut[] calldata _diamondCut, address _init, bytes calldata _calldata) external;
  // functions from contracts/facets/OwnerFacet.sol
  function createMarket(address asset, STypes.Asset memory a) external;
  function owner() external view returns (address);
  function admin() external view returns (address);
  function ownerCandidate() external view returns (address);
  function transferOwnership(address newOwner) external;
  function claimOwnership() external;
  function transferAdminship(address newAdmin) external;
  function setAssetOracle(address asset, address oracle) external;
  function createVault(
        address zeth, uint256 vault, MTypes.CreateVaultParams calldata params) external;
  function setTithe(uint256 vault, uint16 zethTithePercent) external;
  function setDittoMatchedRate(uint256 vault, uint16 rewardRate) external;
  function setDittoShorterRate(uint256 vault, uint16 rewardRate) external;
  function setInitialMargin(address asset, uint16 value) external;
  function setPrimaryLiquidationCR(address asset, uint16 value) external;
  function setSecondaryLiquidationCR(address asset, uint16 value) external;
  function setForcedBidPriceBuffer(address asset, uint8 value) external;
  function setMinimumCR(address asset, uint8 value) external;
  function setResetLiquidationTime(address asset, uint16 value) external;
  function setSecondLiquidationTime(address asset, uint16 value) external;
  function setFirstLiquidationTime(address asset, uint16 value) external;
  function setTappFeePct(address asset, uint8 value) external;
  function setCallerFeePct(address asset, uint8 value) external;
  function setMinBidEth(address asset, uint8 value) external;
  function setMinAskEth(address asset, uint8 value) external;
  function setMinShortErc(address asset, uint16 value) external;
  function createBridge(
        address bridge, uint256 vault, uint16 withdrawalFee, uint8 unstakeFee) external;
  function deleteBridge(address bridge) external;
  function setWithdrawalFee(address bridge, uint16 withdrawalFee) external;
  function setUnstakeFee(address bridge, uint8 unstakeFee) external;
  // functions from contracts/facets/AskOrdersFacet.sol
  function createAsk(
        address asset, uint80 price, uint88 ercAmount, bool isMarketOrder, MTypes.OrderHint[] calldata orderHintArray) external;
  // functions from contracts/facets/MarginCallPrimaryFacet.sol
  function flagShort(address asset, address shorter, uint8 id, uint16 flaggerHint) external;
  function liquidate(
        address asset, address shorter, uint8 id, uint16[] memory shortHintArray) external returns (uint88, uint88);
  // functions from contracts/facets/TWAPFacet.sol
  function estimateWETHInUSDC(uint128 amountIn, uint32 secondsAgo) external view returns (uint256 amountOut);
  // functions from contracts/facets/ViewFacet.sol
  function getZethBalance(uint256 vault, address user) external view returns (uint256);
  function getAssetBalance(address asset, address user) external view returns (uint256);
  function getVault(address asset) external view returns (uint256);
  function getBridgeVault(address bridge) external view returns (uint256);
  function getBids(address asset) external view returns (STypes.Order[] memory);
  function getAsks(address asset) external view returns (STypes.Order[] memory);
  function getShorts(address asset) external view returns (STypes.Order[] memory);
  function getBidHintId(address asset, uint256 price) external view returns (uint16 hintId);
  function getAskHintId(address asset, uint256 price) external view returns (uint16 hintId);
  function getShortHintId(address asset, uint256 price) external view returns (uint16);
  function getShortIdAtOracle(address asset) external view returns (uint16 shortHintId);
  function getHintArray(address asset, uint256 price, O orderType) external view returns (MTypes.OrderHint[] memory orderHintArray);
  function getCollateralRatio(address asset, STypes.ShortRecord memory short) external view returns (uint256 cRatio);
  function getCollateralRatioSpotPrice(address asset, STypes.ShortRecord memory short) external view returns (uint256 cRatio);
  function getAssetPrice(address asset) external view returns (uint256);
  function getProtocolAssetPrice(address asset) external view returns (uint256);
  function getTithe(uint256 vault) external view returns (uint256);
  function getUndistributedYield(uint256 vault) external view returns (uint256);
  function getYield(address asset, address user) external view returns (uint256 shorterYield);
  function getDittoMatchedReward(uint256 vault, address user) external view returns (uint256);
  function getDittoReward(uint256 vault, address user) external view returns (uint256);
  function getAssetCollateralRatio(address asset) external view returns (uint256 cRatio);
  function getShortRecords(address asset, address shorter) external view returns (STypes.ShortRecord[] memory shorts);
  function getShortRecord(address asset, address shorter, uint8 id) external view returns (STypes.ShortRecord memory shortRecord);
  function getShortRecordCount(address asset, address shorter) external view returns (uint256 shortRecordCount);
  function getAssetUserStruct(address asset, address user) external view returns (STypes.AssetUser memory);
  function getVaultUserStruct(uint256 vault, address user) external view returns (STypes.VaultUser memory);
  function getVaultStruct(uint256 vault) external view returns (STypes.Vault memory);
  function getAssetStruct(address asset) external view returns (STypes.Asset memory);
  function getBridgeStruct(address bridge) external view returns (STypes.Bridge memory);
  function getOffsetTimeHours() external view returns (uint256);
  function getOffsetTime() external view returns (uint256);
  function getFlaggerId(address asset, address user) external view returns (uint24 flaggerId);
  // functions from contracts/facets/DiamondLoupeFacet.sol
  function facets() external view returns (IDiamondLoupe.Facet[] memory facets_);
  function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory _facetFunctionSelectors);
  function facetAddresses() external view returns (address[] memory facetAddresses_);
  function facetAddress(bytes4 _functionSelector) external view returns (address facetAddress_);
  // functions from contracts/facets/TestFacet.sol
  function setFrozenT(address asset, F value) external;
  function setprimaryLiquidationCRT(address asset, uint16 value) external;
  function getAskKey(address asset, uint16 id) external view returns (uint16 prevId, uint16 nextId);
  function getBidKey(address asset, uint16 id) external view returns (uint16 prevId, uint16 nextId);
  function getBidOrder(address asset, uint16 id) external view returns (STypes.Order memory bid);
  function getAskOrder(address asset, uint16 id) external view returns (STypes.Order memory ask);
  function getShortOrder(address asset, uint16 id) external view returns (STypes.Order memory short);
  function currentInactiveBids(address asset) external view returns (STypes.Order[] memory);
  function currentInactiveAsks(address asset) external view returns (STypes.Order[] memory);
  function currentInactiveShorts(address asset) external view returns (STypes.Order[] memory);
  function setReentrantStatus(uint8 reentrantStatus) external;
  function getReentrantStatus() external view returns (uint256);
  function getAssetNormalizedStruct(address asset) external view returns (TestTypes.AssetNormalizedStruct memory);
  function getBridgeNormalizedStruct(address bridge) external view returns (TestTypes.BridgeNormalizedStruct memory);
  function setOracleTimeAndPrice(address asset, uint256 price) external;
  function getOracleTimeT(address asset) external view returns (uint256 oracleTime);
  function getOraclePriceT(address asset) external view returns (uint80 oraclePrice);
  function setStartingShortId(address asset, uint16 id) external;
  function nonZeroVaultSlot0(uint256 vault) external;
  function setforcedBidPriceBufferT(address asset, uint8 value) external;
  function setErcDebtRate(address asset, uint64 value) external;
  function setOrderIdT(address asset, uint16 value) external;
  function setEthEscrowed(address addr, uint88 eth) external;
  function setErcEscrowed(address asset, address addr, uint104 erc) external;
  function getUserOrders(address asset, address addr, O orderType) external view returns (STypes.Order[] memory orders);
  function getAssets() external view returns (address[] memory);
  function getAssetsMapping(uint256 assetId) external view returns (address);
  function setTokenId(uint40 tokenId) external;
  function getTokenId() external view returns (uint40 tokenId);
  function getNFT(uint256 tokenId) external view returns (STypes.NFT memory nft);
  function getNFTName() external view returns (string memory);
  function getNFTSymbol() external view returns (string memory);
  function setFlaggerIdCounter(uint24 flaggerIdCounter) external;
  function getFlaggerIdCounter() external view returns (uint24 flaggerId);
  function getFlagger(uint24 flaggerId) external view returns (address flagger);
  function getZethYieldRate(uint256 vault) external view returns (uint80);
  // functions from contracts/facets/BridgeRouterFacet.sol
  function getZethTotal(uint256 vault) external view returns (uint256);
  function getBridges(uint256 vault) external view returns (address[] memory);
  function deposit(address bridge, uint88 amount) external;
  function depositEth(address bridge) external payable;
  function withdraw(address bridge, uint88 zethAmount) external;
  function unstakeEth(address bridge, uint88 zethAmount) external;
  function withdrawTapp(address bridge, uint88 zethAmount) external;
  // functions from contracts/facets/ExitShortFacet.sol
  function exitShortWallet(address asset, uint8 id, uint88 buyBackAmount) external;
  function exitShortErcEscrowed(address asset, uint8 id, uint88 buyBackAmount) external;
  function exitShort(
        address asset, uint8 id, uint88 buyBackAmount, uint80 price, uint16[] memory shortHintArray) external;
  // functions from contracts/facets/ShortRecordFacet.sol
  function increaseCollateral(address asset, uint8 id, uint88 amount) external;
  function decreaseCollateral(address asset, uint8 id, uint88 amount) external;
  function combineShorts(address asset, uint8[] memory ids) external;
  // functions from contracts/facets/OrdersFacet.sol
  function cancelBid(address asset, uint16 id) external;
  function cancelAsk(address asset, uint16 id) external;
  function cancelShort(address asset, uint16 id) external;
  function cancelOrderFarFromOracle(
        address asset, O orderType, uint16 lastOrderId, uint16 numOrdersToCancel) external;
  // functions from contracts/facets/ShortOrdersFacet.sol
  function createLimitShort(
        address asset, uint80 price, uint88 ercAmount, MTypes.OrderHint[] memory orderHintArray, uint16[] memory shortHintArray, uint16 initialCR) external;
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
  // functions from contracts/facets/YieldFacet.sol
  function updateYield(uint256 vault) external;
  function distributeYield(address[] calldata assets) external;
  function claimDittoMatchedReward(uint256 vault) external;
  function withdrawDittoReward(uint256 vault) external;
  // functions from contracts/facets/MarginCallSecondaryFacet.sol
  function liquidateSecondary(
        address asset, MTypes.BatchMC[] memory batches, uint88 liquidateAmount, bool isWallet) external;
  // functions from contracts/facets/VaultFacet.sol
  function depositZETH(address zeth, uint88 amount) external;
  function depositAsset(address asset, uint104 amount) external;
  function withdrawZETH(address zeth, uint88 amount) external;
  function withdrawAsset(address asset, uint104 amount) external;
  // functions from contracts/facets/BidOrdersFacet.sol
  function createBid(
        address asset, uint80 price, uint88 ercAmount, bool isMarketOrder, MTypes.OrderHint[] calldata orderHintArray, uint16[] calldata shortHintArray) external returns (uint88 ethFilled, uint88 ercAmountLeft);
  function createForcedBid(
        address sender, address asset, uint80 price, uint88 ercAmount, uint16[] calldata shortHintArray) external returns (uint88 ethFilled, uint88 ercAmountLeft);
  // functions from contracts/facets/MarketShutdownFacet.sol
  function shutdownMarket(address asset) external;
  function redeemErc(address asset, uint88 amtWallet, uint88 amtEscrow) external;
}