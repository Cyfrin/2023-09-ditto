// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {Errors} from "contracts/libraries/Errors.sol";

import {OBFixture} from "test/utils/OBFixture.sol";

contract VaultFacetRevertTest is OBFixture {
    function setUp() public virtual override {
        super.setUp();
    }

    function testCannotDepositOtherTokenType() public {
        vm.expectRevert(Errors.InvalidAsset.selector);
        diamond.depositAsset(address(1), 1 ether);
    }

    function testCannotWithdrawOtherTokenType() public {
        vm.expectRevert(Errors.InvalidAsset.selector);
        diamond.withdrawAsset(address(1), 1 ether);
    }

    function testCannotDepositZero() public {
        vm.expectRevert(Errors.PriceOrAmountIs0.selector);
        diamond.depositAsset(_cusd, 0);
    }

    function testCannotDepositZETHZero() public {
        vm.expectRevert(Errors.PriceOrAmountIs0.selector);
        diamond.depositZETH(_zeth, 0);
    }

    function testCannotWithdrawZero() public {
        vm.expectRevert(Errors.PriceOrAmountIs0.selector);
        diamond.withdrawAsset(asset, 0);
    }

    function testCannotWithdrawZETHZero() public {
        vm.expectRevert(Errors.PriceOrAmountIs0.selector);
        diamond.withdrawZETH(_zeth, 0);
    }

    function testCannotWithdrawMoreETHThanBalance() public {
        vm.expectRevert(Errors.InsufficientETHEscrowed.selector);
        vm.prank(receiver);
        diamond.withdrawZETH(_zeth, 1 wei);
    }

    function testCannotWithdrawMoreERCThanBalance() public {
        vm.expectRevert(Errors.InsufficientERCEscrowed.selector);
        diamond.withdrawAsset(asset, 2 wei);
    }
}
