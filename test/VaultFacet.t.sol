// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {Constants, Vault} from "contracts/libraries/Constants.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {OBFixture} from "test/utils/OBFixture.sol";

interface ProcessWithdrawal {
    function processWithdrawal() external;
}

contract VaultFacetTest is OBFixture {
    function setUp() public override {
        super.setUp();
    }

    function testCanDepositSteth() public {
        assertEq(diamond.getVaultStruct(vault).zethTotal, 0);
        assertEq(diamond.getVaultUserStruct(vault, receiver).ethEscrowed, 0);
        depositEth(receiver, DEFAULT_AMOUNT);
        assertEq(zeth.balanceOf(receiver), 0);
        assertEq(diamond.getVaultStruct(vault).zethTotal, DEFAULT_AMOUNT);
        assertEq(diamond.getVaultUserStruct(vault, receiver).ethEscrowed, DEFAULT_AMOUNT);
    }

    function testCanDepositZeth() public {
        assertEq(diamond.getVaultStruct(vault).zethTotal, 0);
        assertEq(diamond.getVaultUserStruct(vault, receiver).ethEscrowed, 0);

        vm.prank(_diamond);
        zeth.mint(receiver, DEFAULT_AMOUNT);
        vm.prank(receiver);

        diamond.depositZETH(_zeth, DEFAULT_AMOUNT);

        assertEq(zeth.balanceOf(receiver), 0);
        assertEq(diamond.getVaultStruct(vault).zethTotal, 0);
        assertEq(diamond.getVaultUserStruct(vault, receiver).ethEscrowed, DEFAULT_AMOUNT);
    }

    function testCanWithdrawZETH() public {
        testCanDepositZeth();
        assertEq(diamond.getVaultStruct(Vault.CARBON).zethTotal, 0);
        assertEq(
            diamond.getVaultUserStruct(Vault.CARBON, receiver).ethEscrowed, DEFAULT_AMOUNT
        );
        vm.prank(receiver);
        diamond.withdrawZETH(_zeth, DEFAULT_AMOUNT);
        assertEq(diamond.getVaultStruct(Vault.CARBON).zethTotal, 0);
        assertEq(diamond.getVaultUserStruct(Vault.CARBON, receiver).ethEscrowed, 0);
        assertEq(zeth.balanceOf(receiver), DEFAULT_AMOUNT);
    }

    function testCanDepositUsd() public {
        assertEq(getTotalErc(), 0 ether);
        assertEq(diamond.getAssetUserStruct(asset, receiver).ercEscrowed, 0);
        depositUsd(receiver, DEFAULT_AMOUNT);
        assertEq(token.balanceOf(receiver), 0);
        assertEq(getTotalErc(), DEFAULT_AMOUNT);
        assertEq(diamond.getAssetUserStruct(asset, receiver).ercEscrowed, DEFAULT_AMOUNT);
    }

    function testCanWithdrawZETHFromSteth() public {
        testCanDepositSteth();
        assertEq(diamond.getVaultStruct(Vault.CARBON).zethTotal, DEFAULT_AMOUNT);
        assertEq(
            diamond.getVaultUserStruct(Vault.CARBON, receiver).ethEscrowed, DEFAULT_AMOUNT
        );
        vm.prank(receiver);
        diamond.withdrawZETH(_zeth, DEFAULT_AMOUNT);
        assertEq(diamond.getVaultStruct(Vault.CARBON).zethTotal, DEFAULT_AMOUNT);
        assertEq(diamond.getVaultUserStruct(Vault.CARBON, receiver).ethEscrowed, 0);
        assertEq(zeth.balanceOf(receiver), DEFAULT_AMOUNT);
    }

    function testCanWithdrawUsd() public {
        testCanDepositUsd();
        vm.prank(receiver);
        diamond.withdrawAsset(asset, DEFAULT_AMOUNT);
        assertEq(token.balanceOf(receiver), DEFAULT_AMOUNT);
        assertEq(getTotalErc(), 0);
        assertEq(diamond.getAssetUserStruct(asset, receiver).ercEscrowed, 0);
    }

    function test_Revert_OnlyValidZeth() public {
        vm.expectRevert(Errors.InvalidZeth.selector);
        diamond.depositZETH(address(100), DEFAULT_AMOUNT);
        vm.expectRevert(Errors.InvalidZeth.selector);
        diamond.withdrawZETH(address(100), DEFAULT_AMOUNT);
    }
}
