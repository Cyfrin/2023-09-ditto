// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {stdError} from "forge-std/StdError.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {Events} from "contracts/libraries/Events.sol";
import {STypes, MTypes, O} from "contracts/libraries/DataTypes.sol";
import {Constants} from "contracts/libraries/Constants.sol";

import {OBFixture} from "test/utils/OBFixture.sol";
// import {console} from "contracts/libraries/console.sol";

abstract contract ERC721TokenReceiver {
    function onERC721Received(address, address, uint256, bytes calldata)
        external
        virtual
        returns (bytes4)
    {
        return ERC721TokenReceiver.onERC721Received.selector;
    }
}

contract ERC721Recipient is ERC721TokenReceiver {
    address public operator;
    address public from;
    uint256 public id;
    bytes public data;

    function onERC721Received(
        address _operator,
        address _from,
        uint256 _id,
        bytes calldata _data
    ) public virtual override returns (bytes4) {
        operator = _operator;
        from = _from;
        id = _id;
        data = _data;

        return ERC721TokenReceiver.onERC721Received.selector;
    }
}

contract RevertingERC721Recipient is ERC721TokenReceiver {
    function onERC721Received(address, address, uint256, bytes calldata)
        public
        virtual
        override
        returns (bytes4)
    {
        revert(string(abi.encodePacked(ERC721TokenReceiver.onERC721Received.selector)));
    }
}

contract WrongReturnDataERC721Recipient is ERC721TokenReceiver {
    function onERC721Received(address, address, uint256, bytes calldata)
        public
        virtual
        override
        returns (bytes4)
    {
        return 0xCAFEBEEF;
    }
}

contract NonERC721Recipient {}

contract ERC721Test is OBFixture {
    function setUp() public override {
        super.setUp();
    }

    function createShortAndMintNFT() public {
        assertEq(diamond.balanceOf(sender), 0);
        assertEq(diamond.getTokenId(), 1);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        assertEq(diamond.balanceOf(sender), 0);
        vm.prank(sender);
        diamond.mintNFT(asset, Constants.SHORT_STARTING_ID);
        assertEq(diamond.getTokenId(), 2);
        assertEq(diamond.balanceOf(sender), 1);
        assertEq(diamond.ownerOf(1), sender);

        //@dev give extra an initial short to test that shortRecordId changes appropriately when
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, extra);
    }

    function checkNFTBeforeTransfer() public {
        STypes.NFT memory nft = diamond.getNFT(1);
        assertEq(nft.owner, sender);
        assertEq(nft.assetId, diamond.getAssetNormalizedStruct(asset).assetId);
        assertEq(nft.shortRecordId, Constants.SHORT_STARTING_ID);

        assertEq(diamond.getShortRecordCount(asset, sender), 1);
        assertEq(diamond.getShortRecordCount(asset, extra), 1);
    }

    function checkNFTAfterTransfer() public {
        STypes.NFT memory nft = diamond.getNFT(1);
        assertEq(nft.owner, extra);
        assertEq(nft.assetId, diamond.getAssetNormalizedStruct(asset).assetId);
        //@dev id = 3 because extra already has shortRecordId = Constants.SHORT_STARTING_ID (2)
        assertEq(nft.shortRecordId, Constants.SHORT_STARTING_ID + 1);

        assertEq(diamond.getShortRecordCount(asset, sender), 0);
        assertEq(diamond.getShortRecordCount(asset, extra), 2);
        assertEq(diamond.getApproved(1), address(0));
    }

    ///REVERT

    function test_Revert_BalanceOf_ERC721InvalidOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.ERC721InvalidOwner.selector, 0));
        diamond.balanceOf(address(0));
    }

    function test_Revert_InvalidTokenId() public {
        vm.expectRevert(Errors.InvalidTokenId.selector);
        diamond.transferFrom(sender, receiver, uint256(type(uint40).max) + 1 wei);
        vm.expectRevert(Errors.InvalidTokenId.selector);
        diamond.approve(sender, uint256(type(uint40).max) + 1 wei);
    }

    //Mint

    function test_Revert_Mint_CannotMintLastShortRecord() public {
        for (uint256 i = 0; i < 255; i++) {
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
            fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        }

        vm.prank(sender);
        vm.expectRevert(Errors.CannotMintLastShortRecord.selector);

        diamond.mintNFT(asset, 254);
    }

    function test_Revert_Mint_OnlyValidShortRecord_MaxId() public {
        vm.prank(sender);
        vm.expectRevert(Errors.InvalidShortId.selector);
        diamond.mintNFT(asset, Constants.SHORT_STARTING_ID);
    }

    function test_Revert_Mint_OnlyValidShortRecord_LtShortStartingId() public {
        vm.prank(sender);
        vm.expectRevert(Errors.InvalidShortId.selector);
        diamond.mintNFT(asset, 1);
    }

    function test_Revert_Mint_OnlyValidShortRecord_MintingCancelledShort() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        exitShort(Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT, DEFAULT_PRICE, sender);

        vm.prank(sender);
        vm.expectRevert(Errors.InvalidShortId.selector);
        diamond.mintNFT(asset, Constants.SHORT_STARTING_ID);
    }

    function test_Revert_Mint_CannotMintAnymoreNFTs() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        diamond.setTokenId(type(uint40).max);
        vm.prank(sender);
        vm.expectRevert(stdError.arithmeticError);
        diamond.mintNFT(asset, Constants.SHORT_STARTING_ID);
    }

    //TransferFrom
    function test_Revert_TransferFrom_ReceiverExceededShortRecordLimit() public {
        for (uint256 i = 0; i < 255; i++) {
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
            fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, extra);
        }

        createShortAndMintNFT();
        vm.prank(sender);
        vm.expectRevert(Errors.ReceiverExceededShortRecordLimit.selector);
        diamond.transferFrom(sender, extra, 1);
    }

    function test_Revert_TransferFrom_CannotTransferFlaggedShort() public {
        createShortAndMintNFT();

        setETH(2666 ether);
        vm.prank(receiver);
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID, Constants.HEAD);

        vm.prank(sender);
        vm.expectRevert(Errors.CannotTransferFlaggedShort.selector);
        diamond.transferFrom(sender, extra, 1);
    }

    function test_Revert_TransferFrom_ERC721InsufficientApproval() public {
        createShortAndMintNFT();
        vm.prank(extra);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.ERC721InsufficientApproval.selector, extra, 0)
        );
        diamond.transferFrom(sender, extra, 0);
    }

    function test_Revert_TransferFrom_ERC721IncorrectOwner() public {
        createShortAndMintNFT();
        vm.prank(extra);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.ERC721IncorrectOwner.selector, extra, 1, sender)
        );
        diamond.transferFrom(extra, receiver, 1);
    }

    function test_Revert_TransferFrom_ERC721InvalidReceiver() public {
        createShortAndMintNFT();
        vm.prank(sender);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.ERC721InvalidReceiver.selector, address(0))
        );
        diamond.transferFrom(sender, address(0), 1);
    }

    function test_Revert_TransferFrom_OriginalShortRecordCancelled() public {
        createShortAndMintNFT();

        //@dev exit short so the minted NFT points to a "cancelled" short
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        exitShort(Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT, DEFAULT_PRICE, sender);

        STypes.NFT memory nft = diamond.getNFT(1);
        assertEq(nft.owner, sender);

        vm.prank(sender);
        vm.expectRevert(Errors.OriginalShortRecordCancelled.selector);
        diamond.transferFrom(sender, extra, 1);
    }

    function test_Revert_TransferFrom_ERC721NonexistentToken() public {
        createShortAndMintNFT();

        vm.prank(sender);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.ERC721NonexistentToken.selector, 999)
        );
        diamond.transferFrom(sender, extra, 999);
    }

    //Approve
    function test_Revert_Approve_ERC721InvalidOperator() public {
        createShortAndMintNFT();
        vm.prank(sender);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.ERC721InvalidOperator.selector, sender)
        );
        diamond.approve(sender, 1);
    }

    function test_Revert_Approve_ERC721InvalidApprover() public {
        createShortAndMintNFT();
        vm.prank(receiver);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.ERC721InvalidApprover.selector, receiver)
        );
        diamond.approve(extra, 0);
    }

    //Combine Short
    function test_Revert_CombineShort_FirstShortMustBeNFT() public {
        //@dev first short has nft, second does not
        createShortAndMintNFT();
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        vm.prank(sender);
        vm.expectRevert(Errors.FirstShortMustBeNFT.selector);
        combineShorts({
            id1: Constants.SHORT_STARTING_ID + 1,
            id2: Constants.SHORT_STARTING_ID
        });
    }

    //Safe Transfer
    function test_Revert_SafeTransferFromToNonERC721Recipient() public {
        createShortAndMintNFT();
        address nonRecipient = address(new NonERC721Recipient());
        vm.prank(sender);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.ERC721InvalidReceiver.selector, nonRecipient)
        );
        diamond.safeTransferFrom(sender, nonRecipient, 1);
    }

    function test_Revert_SafeTransferFromToNonERC721Recipient_WithData() public {
        createShortAndMintNFT();
        address nonRecipient = address(new NonERC721Recipient());
        vm.prank(sender);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.ERC721InvalidReceiver.selector, nonRecipient)
        );
        diamond.safeTransferFrom(sender, nonRecipient, 1, "testorino");
    }

    function testFailSafeTransferFromToRevertingERC721Recipient() public {
        createShortAndMintNFT();
        address revertingRecipient = address(new RevertingERC721Recipient());
        vm.prank(sender);
        diamond.safeTransferFrom(sender, revertingRecipient, 1);
    }

    function testFailSafeTransferFromToRevertingERC721Recipient_WithData() public {
        createShortAndMintNFT();
        address revertingRecipient = address(new RevertingERC721Recipient());
        vm.prank(sender);
        diamond.safeTransferFrom(sender, revertingRecipient, 1, "testorino");
    }

    function test_Revert_SafeTransferFromToERC721RecipientWithWrongReturnData() public {
        address wrongReturnRecipient = address(new WrongReturnDataERC721Recipient());
        createShortAndMintNFT();
        vm.prank(sender);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.ERC721InvalidReceiver.selector, wrongReturnRecipient
            )
        );
        diamond.safeTransferFrom(sender, wrongReturnRecipient, 1);
    }

    function test_Revert_SafeTransferFromToERC721RecipientWithWrongReturnData_WithData()
        public
    {
        address wrongReturnRecipient = address(new WrongReturnDataERC721Recipient());
        createShortAndMintNFT();
        vm.prank(sender);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.ERC721InvalidReceiver.selector, wrongReturnRecipient
            )
        );
        diamond.safeTransferFrom(sender, wrongReturnRecipient, 1, "testorino");
    }

    ///NON-REVERT
    //Mint
    function test_BalanceOf_Mint2NFT() public {
        createShortAndMintNFT();

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        vm.prank(sender);
        diamond.mintNFT(asset, Constants.SHORT_STARTING_ID + 1);
        assertEq(getShortRecordCount(sender), 2);
        assertEq(diamond.balanceOf(sender), 2);
    }

    function test_BalanceOf_Mint2NFT_b() public {
        createShortAndMintNFT();

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        assertEq(getShortRecordCount(sender), 2);
        assertEq(diamond.balanceOf(sender), 1);

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        vm.prank(sender);
        diamond.mintNFT(asset, Constants.SHORT_STARTING_ID + 2);

        assertEq(getShortRecordCount(sender), 3);
        assertEq(diamond.balanceOf(sender), 2);
    }

    function test_BalanceOf_Mint1NFT() public {
        createShortAndMintNFT();

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        assertEq(getShortRecordCount(sender), 2);
        assertEq(diamond.balanceOf(sender), 1);
    }

    //TransferFrom
    function test_TransferFrom() public {
        createShortAndMintNFT();
        checkNFTBeforeTransfer();

        // @dev transfer short NFT
        vm.prank(sender);
        diamond.transferFrom(sender, extra, 1);
        assertEq(diamond.getTokenId(), 2);

        checkNFTAfterTransfer();

        vm.prank(extra);
        vm.expectRevert(Errors.AlreadyMinted.selector);
        diamond.mintNFT(asset, Constants.SHORT_STARTING_ID + 1);
    }

    function test_Approve_TransferFrom() public {
        createShortAndMintNFT();
        checkNFTBeforeTransfer();

        assertEq(diamond.getApproved(1), address(0));
        vm.prank(sender);
        diamond.approve(receiver, 1);
        assertEq(diamond.getApproved(1), receiver);

        vm.prank(receiver);
        diamond.transferFrom(sender, extra, 1);
        assertEq(diamond.getTokenId(), 2);

        checkNFTAfterTransfer();

        vm.prank(extra);
        vm.expectRevert(Errors.AlreadyMinted.selector);
        diamond.mintNFT(asset, Constants.SHORT_STARTING_ID + 1);
    }

    //CombineShort
    function test_CombineShort_TwoShortsTwoNFTs() public {
        //@dev both shorts have nfts
        createShortAndMintNFT();
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        vm.prank(sender);
        diamond.mintNFT(asset, Constants.SHORT_STARTING_ID + 1);

        assertEq(getShortRecordCount(sender), 2);
        assertEq(diamond.ownerOf(1), sender);
        assertEq(diamond.ownerOf(2), sender);

        vm.prank(sender);
        combineShorts({
            id1: Constants.SHORT_STARTING_ID,
            id2: Constants.SHORT_STARTING_ID + 1
        });

        assertEq(getShortRecordCount(sender), 1);
        assertEq(diamond.ownerOf(1), sender);
        //@dev token1 no longer has an owner
        //@dev tokenIds don't get re-used. Once it is burned, it will never be used again
        vm.expectRevert(abi.encodeWithSelector(Errors.ERC721NonexistentToken.selector, 2));
        diamond.ownerOf(2);
    }

    function test_CombineShort_TwoShortsOneNFT() public {
        //@dev first short has nft, second does not
        createShortAndMintNFT();
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        assertEq(getShortRecordCount(sender), 2);
        assertEq(diamond.ownerOf(1), sender);
        vm.expectRevert(abi.encodeWithSelector(Errors.ERC721NonexistentToken.selector, 2));
        diamond.ownerOf(2);

        vm.prank(sender);
        combineShorts({
            id1: Constants.SHORT_STARTING_ID,
            id2: Constants.SHORT_STARTING_ID + 1
        });

        assertEq(getShortRecordCount(sender), 1);
        assertEq(diamond.ownerOf(1), sender);
        vm.expectRevert(abi.encodeWithSelector(Errors.ERC721NonexistentToken.selector, 2));
        diamond.ownerOf(2);
    }

    function test_NFTMetadata() public {
        assertEq(diamond.getNFTName(), "DITTO_NFT");
        assertEq(diamond.getNFTSymbol(), "DNFT");
    }

    //Safe Transfer tests
    function test_SafeTransferFromToEOA() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        vm.startPrank(sender);

        diamond.mintNFT(asset, Constants.SHORT_STARTING_ID);
        diamond.setApprovalForAll(address(this), true);
        diamond.safeTransferFrom(sender, address(0xBEEF), 1, "");

        assertEq(diamond.getApproved(1), address(0));
        assertEq(diamond.ownerOf(1), address(0xBEEF));
        assertEq(diamond.balanceOf(address(0xBEEF)), 1);
        assertEq(diamond.balanceOf(sender), 0);
    }

    function test_SafeTransferFromToEOA_b() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        vm.startPrank(sender);
        diamond.mintNFT(asset, Constants.SHORT_STARTING_ID);

        diamond.setApprovalForAll(address(this), true);
        diamond.safeTransferFrom(sender, address(0xBEEF), 1);

        assertEq(diamond.getApproved(1), address(0));
        assertEq(diamond.ownerOf(1), address(0xBEEF));
        assertEq(diamond.balanceOf(address(0xBEEF)), 1);
        assertEq(diamond.balanceOf(sender), 0);
    }

    function test_SafeTransferFromToERC721Recipient() public {
        ERC721Recipient recipient = new ERC721Recipient();

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        vm.startPrank(sender);
        diamond.mintNFT(asset, Constants.SHORT_STARTING_ID);

        diamond.setApprovalForAll(address(this), true);
        diamond.safeTransferFrom(sender, address(recipient), 1);

        assertEq(diamond.getApproved(1), address(0));
        assertEq(diamond.ownerOf(1), address(recipient));
        assertEq(diamond.balanceOf(address(recipient)), 1);
        assertEq(diamond.balanceOf(sender), 0);

        assertEq(recipient.operator(), sender);
        assertEq(recipient.from(), sender);
        assertEq(recipient.id(), 1);
        assertEq(recipient.data(), "");
    }

    function test_SafeTransferFromToERC721Recipient_WithData() public {
        ERC721Recipient recipient = new ERC721Recipient();

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        vm.startPrank(sender);
        diamond.mintNFT(asset, Constants.SHORT_STARTING_ID);

        diamond.setApprovalForAll(address(this), true);
        diamond.safeTransferFrom(sender, address(recipient), 1, "testerino");

        assertEq(diamond.getApproved(1), address(0));
        assertEq(diamond.ownerOf(1), address(recipient));
        assertEq(diamond.balanceOf(address(recipient)), 1);
        assertEq(diamond.balanceOf(sender), 0);

        assertEq(recipient.operator(), sender);
        assertEq(recipient.from(), sender);
        assertEq(recipient.id(), 1);
        assertEq(recipient.data(), "testerino");
    }

    function test_SafeTransferFromToERC721RecipientSendBack() public {
        ERC721Recipient recipient = new ERC721Recipient();

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        vm.startPrank(sender);
        diamond.mintNFT(asset, Constants.SHORT_STARTING_ID);

        diamond.setApprovalForAll(address(this), true);
        diamond.safeTransferFrom(sender, address(recipient), 1);
        vm.stopPrank();

        assertEq(diamond.getApproved(1), address(0));
        assertEq(diamond.ownerOf(1), address(recipient));
        assertEq(diamond.balanceOf(address(recipient)), 1);
        assertEq(diamond.balanceOf(sender), 0);

        assertEq(recipient.operator(), sender);
        assertEq(recipient.from(), sender);
        assertEq(recipient.id(), 1);
        assertEq(recipient.data(), "");

        // Send it again
        ERC721Recipient recipient2 = new ERC721Recipient();

        vm.prank(address(recipient));
        diamond.safeTransferFrom(address(recipient), address(recipient2), 1);

        assertEq(diamond.getApproved(1), address(0));
        assertEq(diamond.ownerOf(1), address(recipient2));
        assertEq(diamond.balanceOf(address(recipient2)), 1);
        assertEq(diamond.balanceOf(address(recipient)), 0);

        assertEq(recipient2.operator(), address(recipient));
        assertEq(recipient2.from(), address(recipient));
        assertEq(recipient2.id(), 1);
        assertEq(recipient2.data(), "");
    }
}
