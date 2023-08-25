// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {stdError} from "forge-std/StdError.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {OBFixture} from "test/utils/OBFixture.sol";
import {Constants} from "contracts/libraries/Constants.sol";

contract BridgeRouterRevertTest is OBFixture {
    function setUp() public virtual override {
        super.setUp();
    }

    // wrong bridge

    function test_RevertIf_DepositEthToBadBridge() public {
        vm.startPrank(sender);
        vm.expectRevert(Errors.InvalidBridge.selector);
        diamond.depositEth{value: 0 ether}(address(88));
    }

    function test_RevertIf_DepositToBadBridge() public {
        vm.startPrank(sender);
        vm.expectRevert(Errors.InvalidBridge.selector);
        diamond.deposit(address(88), 0);
    }

    function test_RevertIf_WithdrawToBadBridge() public {
        vm.startPrank(sender);
        vm.expectRevert(Errors.InvalidBridge.selector);
        diamond.withdraw(address(88), 0);
    }

    function test_RevertIf_WithdrawTappToBadBridge() public {
        vm.prank(sender);
        vm.expectRevert("LibDiamond: Must be contract owner");
        diamond.withdrawTapp(address(88), 0);

        vm.prank(owner);
        vm.expectRevert(Errors.InvalidBridge.selector);
        diamond.withdrawTapp(address(88), 0);
    }

    // if zero

    function test_RevertIf_DepositEthUnderMin() public {
        vm.deal(sender, Constants.MIN_DEPOSIT);
        vm.startPrank(sender);
        vm.expectRevert(Errors.UnderMinimumDeposit.selector);
        diamond.depositEth{value: Constants.MIN_DEPOSIT - 1}(_bridgeReth);

        vm.expectRevert(Errors.UnderMinimumDeposit.selector);
        diamond.depositEth{value: Constants.MIN_DEPOSIT - 1}(_bridgeSteth);
    }

    function test_RevertIf_DepositUnderMin() public {
        vm.startPrank(sender);
        vm.expectRevert(Errors.UnderMinimumDeposit.selector);
        diamond.deposit(_bridgeReth, Constants.MIN_DEPOSIT - 1);

        vm.expectRevert(Errors.UnderMinimumDeposit.selector);
        diamond.deposit(_bridgeSteth, Constants.MIN_DEPOSIT - 1);
    }

    function test_RevertIf_WithdrawZero() public {
        vm.startPrank(sender);
        vm.expectRevert(Errors.ParameterIsZero.selector);
        diamond.withdraw(_bridgeReth, 0);

        vm.expectRevert(Errors.ParameterIsZero.selector);
        diamond.withdraw(_bridgeSteth, 0);
    }

    function test_RevertIf_WithdrawTappZero() public {
        vm.startPrank(owner);
        vm.expectRevert(Errors.ParameterIsZero.selector);
        diamond.withdrawTapp(_bridgeReth, 0);

        vm.expectRevert(Errors.ParameterIsZero.selector);
        diamond.withdrawTapp(_bridgeSteth, 0);
    }

    // if not enough token

    function test_RevertIf_DepositEthWithoutToken() public {
        vm.startPrank(sender);
        vm.expectRevert();
        diamond.depositEth{value: 1 ether}(_bridgeReth);

        vm.expectRevert();
        diamond.depositEth{value: 1 ether}(_bridgeSteth);
    }

    function test_RevertIf_DepositWithoutToken() public {
        vm.startPrank(sender);
        vm.expectRevert("ERC20: insufficient allowance");
        diamond.deposit(_bridgeReth, 1 ether);

        vm.expectRevert("ERC20: insufficient allowance");
        diamond.deposit(_bridgeSteth, 1 ether);
    }

    function test_RevertIf_WithdrawWithoutToken() public {
        vm.startPrank(sender);
        vm.expectRevert(stdError.arithmeticError);
        diamond.withdraw(_bridgeReth, 1 ether);

        vm.expectRevert(stdError.arithmeticError);
        diamond.withdraw(_bridgeSteth, 1 ether);
    }

    function test_RevertIf_WithdrawTappWithoutToken() public {
        vm.startPrank(owner);
        vm.expectRevert(stdError.arithmeticError);
        diamond.withdrawTapp(_bridgeReth, 1 ether);

        vm.expectRevert(stdError.arithmeticError);
        diamond.withdrawTapp(_bridgeSteth, 1 ether);
    }

    function test_RevertIf_UnstakeAmountZero() public {
        vm.prank(sender);
        vm.expectRevert(Errors.ParameterIsZero.selector);
        diamond.unstakeEth(_bridgeReth, 0);
    }

    function test_RevertIf_UnstakeBridgeBad() public {
        vm.prank(sender);
        vm.expectRevert(Errors.InvalidBridge.selector);
        diamond.unstakeEth(address(88), 1);
    }

    // if not owner

    function test_RevertIf_WithdrawTappNotOwner() public {
        vm.expectRevert("LibDiamond: Must be contract owner");
        diamond.withdrawTapp(_bridgeReth, 1 ether);

        vm.expectRevert("LibDiamond: Must be contract owner");
        diamond.withdrawTapp(_bridgeSteth, 1 ether);
    }
}
