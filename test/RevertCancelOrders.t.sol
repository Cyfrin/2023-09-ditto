// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256} from "contracts/libraries/PRBMathHelper.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {OBFixture} from "test/utils/OBFixture.sol";
import {Constants} from "contracts/libraries/Constants.sol";

contract RevertCancelOrdersTest is OBFixture {
    using U256 for uint256;

    function setUp() public override {
        super.setUp();
    }

    function test_RevertIf_NoOrders() public {
        vm.startPrank(sender);

        vm.expectRevert(Errors.NotOwner.selector);
        cancelShort(100);

        vm.expectRevert(Errors.NotOwner.selector);
        cancelAsk(100);

        vm.expectRevert(Errors.NotOwner.selector);
        cancelBid(100);
    }

    function test_RevertIf_InvalidId_Short() public {
        fundLimitShortOpt(0.1 ether, DEFAULT_AMOUNT, receiver);

        vm.prank(sender);
        vm.expectRevert(Errors.NotOwner.selector);
        cancelShort(0);
    }

    function test_RevertIf_InvalidId_Ask() public {
        fundLimitAskOpt(0.1 ether, DEFAULT_AMOUNT, receiver);

        vm.prank(sender);
        vm.expectRevert(Errors.NotOwner.selector);
        cancelAsk(0);
    }

    function test_RevertIf_InvalidId_Bid() public {
        fundLimitBidOpt(0.1 ether, DEFAULT_AMOUNT, receiver);

        vm.expectRevert(Errors.NotOwner.selector);
        vm.prank(sender);
        cancelBid(0);
    }

    function test_RevertIf_WrongUser_Short() public {
        fundLimitShortOpt(0.1 ether, DEFAULT_AMOUNT, receiver);

        vm.expectRevert(Errors.NotOwner.selector);
        vm.prank(sender);
        cancelShort(100);
    }

    function test_RevertIf_WrongUser_Ask() public {
        fundLimitAskOpt(0.1 ether, DEFAULT_AMOUNT, receiver);

        vm.expectRevert(Errors.NotOwner.selector);
        vm.prank(sender);
        cancelAsk(100);
    }

    function test_RevertIf_WrongUser_Bid() public {
        fundLimitBidOpt(0.5 ether, DEFAULT_AMOUNT, receiver);

        vm.expectRevert(Errors.NotOwner.selector);
        vm.prank(sender);
        cancelBid(100);
    }

    function test_RevertIf_AlreadyCancelled_Short() public {
        fundLimitShortOpt(1 ether, DEFAULT_AMOUNT, receiver);
        vm.startPrank(receiver);
        cancelShort(100);

        vm.expectRevert(Errors.NotActiveOrder.selector);
        cancelShort(100);
    }

    function test_RevertIf_AlreadyCancelled_Ask() public {
        fundLimitAskOpt(1 ether, DEFAULT_AMOUNT, receiver);
        vm.startPrank(receiver);
        cancelAsk(100);

        vm.expectRevert(Errors.NotActiveOrder.selector);
        cancelAsk(100);
    }

    function test_RevertIf_AlreadyCancelled_Bid() public {
        fundLimitBidOpt(1 ether, DEFAULT_AMOUNT, receiver);
        vm.startPrank(receiver);
        cancelBid(100);

        vm.expectRevert(Errors.NotActiveOrder.selector);
        cancelBid(100);
    }

    function test_RevertIf_AlreadyMatched_Short() public {
        fundLimitBidOpt(1 ether, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(1 ether, DEFAULT_AMOUNT, sender); // not set
        vm.prank(sender);
        vm.expectRevert(Errors.NotOwner.selector);
        cancelShort(100);

        fundLimitShortOpt(1 ether, DEFAULT_AMOUNT, sender); // 101
        fundLimitBidOpt(1 ether, DEFAULT_AMOUNT, receiver); // not set
        vm.prank(sender);
        vm.expectRevert(Errors.NotActiveOrder.selector);
        cancelShort(101);
    }

    function test_RevertIf_AlreadyMatched_Ask() public {
        fundLimitBidOpt(1 ether, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(1 ether, DEFAULT_AMOUNT, sender); // not set
        vm.prank(sender);
        vm.expectRevert(Errors.NotOwner.selector);
        cancelAsk(101);

        fundLimitAskOpt(1 ether, DEFAULT_AMOUNT, sender); // 101
        fundLimitBidOpt(1 ether, DEFAULT_AMOUNT, receiver); // not set
        vm.prank(sender);
        vm.expectRevert(Errors.NotActiveOrder.selector);
        cancelAsk(101);
    }

    function test_RevertIf_AlreadyMatched_Bid() public {
        fundLimitBidOpt(1 ether, DEFAULT_AMOUNT, receiver); // 100
        fundLimitAskOpt(1 ether, DEFAULT_AMOUNT, sender); // not set
        vm.prank(receiver);
        vm.expectRevert(Errors.NotActiveOrder.selector);
        cancelBid(100);

        vm.prank(receiver);
        vm.expectRevert(Errors.NotOwner.selector);
        cancelBid(101);
    }
}
