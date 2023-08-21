// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

library Errors {
    error AlreadyMinted();
    error AssetIsFrozen();
    error AssetIsNotPermanentlyFrozen();
    error BadHintIdArray();
    error BadShortHint();
    error CannotCancelMoreThan1000Orders();
    error CannotLeaveDustAmount();
    error CannotFlagSelf();
    error CannotLiquidateSelf();
    error CannotMintAnymoreNFTs();
    error CannotMintLastShortRecord();
    error CannotSocializeDebt();
    error CannotTransferFlaggedShort();
    error CollateralHigherThanMax();
    error CollateralLowerThanMin();
    error DifferentVaults();
    error ExitShortPriceTooLow();
    error FirstShortMustBeNFT();
    error FunctionNotFound(bytes4 _functionSelector);
    error InvalidAmount();
    error InvalidAsset();
    error InvalidBridge();
    error InvalidBuyback();
    error InvalidFlaggerHint();
    error InvalidInitialCR();
    error InvalidMsgValue();
    error InvalidPrice();
    error InvalidTithe();
    error InvalidTokenId();
    error InvalidTwapPrice();
    error InvalidTWAPSecondsAgo();
    error InvalidZeth();
    error InsufficientWalletBalance();
    error InsufficientCollateral();
    error InsufficientERCEscrowed();
    error InsufficientETHEscrowed();
    error InsufficientEthInLiquidityPool();
    error InsufficientNumberOfShorts();
    error InvalidShortId();
    error IsNotNFT();
    error MarginCallAlreadyFlagged();
    error MarginCallIneligibleWindow();
    error MarginCallSecondaryNoValidShorts();
    error MarketAlreadyCreated();
    error NoDittoReward();
    error NoSells();
    error NoShares();
    error NotActiveOrder();
    error NotBridgeForBaseCollateral();
    error NotDiamond();
    error NotLastOrder();
    error NotMinted();
    error NotOwner();
    error NotOwnerCandidate();
    error NoYield();
    error OrderIdCountTooLow();
    error OrderUnderMinimumSize();
    error OriginalShortRecordCancelled();
    error ParameterIsZero();
    error PostExitCRLtPreExitCR();
    error PriceOrAmountIs0();
    error ReceiverExceededShortRecordLimit();
    error ReentrantCall();
    error ReentrantCallView();
    error ShortNotFlagged();
    error ShortRecordIdOverflow();
    error ShortRecordIdsNotSorted();
    error SufficientCollateral();
    error UnderMinimum();
    error UnderMinimumDeposit();
    error VaultAlreadyCreated();

    /**
     * @dev Indicates that an address can't be an owner. For example, `address(0)` is a forbidden owner in EIP-20.
     * Used in balance queries.
     * @param owner Address of the current owner of a token.
     */
    error ERC721InvalidOwner(address owner);
    /**
     * @dev Indicates a `tokenId` whose `owner` is the zero address.
     * @param tokenId Identifier number of a token.
     */
    error ERC721NonexistentToken(uint256 tokenId);
    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC721InvalidOperator(address operator);
    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param tokenId Identifier number of a token.
     */
    error ERC721InsufficientApproval(address operator, uint256 tokenId);
    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC721InvalidApprover(address approver);
    /**
     * @dev Indicates an error related to the ownership over a particular token. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param tokenId Identifier number of a token.
     * @param owner Address of the current owner of a token.
     */
    error ERC721IncorrectOwner(address sender, uint256 tokenId, address owner);
    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC721InvalidReceiver(address receiver);
}
