// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256} from "contracts/libraries/PRBMathHelper.sol";

import {IAsset} from "interfaces/IAsset.sol";
import {IAsset} from "interfaces/IAsset.sol";

import {GasHelper} from "test-gas/GasHelper.sol";

contract GasVaultFixture is GasHelper {
    function setUp() public virtual override {
        super.setUp();
    }
}

contract GasVaultTest is GasVaultFixture {
    using U256 for uint256;

    function setUp() public override {
        super.setUp();
        uint88 amount = 1000 ether;
        uint256 preBal = cusd.balanceOf(sender);
        // transfer remainder balance
        vm.prank(sender);
        cusd.transfer(receiver, preBal);

        vm.prank(_diamond);
        zeth.mint(sender, amount);
        vm.prank(_diamond);
        cusd.mint(sender, amount);

        assertEq(zeth.balanceOf(sender), amount);
        assertEq(cusd.balanceOf(sender), amount);

        //for withdraw
        ob.depositEth(sender, amount);
        ob.depositUsd(sender, amount);
    }

    function testGasDepositAssetZETH() public {
        address _zeth = address(zeth);
        vm.startPrank(sender);
        startMeasuringGas("Vault-DepositZETH");
        diamond.depositZETH(_zeth, 500 ether);
        stopMeasuringGas();
        vm.stopPrank();
    }

    function testGasDepositAssetCUSD() public {
        address _cusd = address(cusd);
        vm.startPrank(sender);
        startMeasuringGas("Vault-DepositAsset-CUSD");
        diamond.depositAsset(_cusd, 500 ether);
        stopMeasuringGas();
        vm.stopPrank();
    }

    function testGasWithdrawAssetZETH() public {
        address _zeth = address(zeth);
        vm.startPrank(sender);
        startMeasuringGas("Vault-WithdrawZETH");
        diamond.withdrawZETH(_zeth, 500 ether);
        stopMeasuringGas();
        vm.stopPrank();
    }

    function testGasWithdrawAssetCUSD() public {
        address _cusd = address(cusd);
        vm.startPrank(sender);
        startMeasuringGas("Vault-WithdrawAsset-CUSD");
        diamond.withdrawAsset(_cusd, 500 ether);
        stopMeasuringGas();
        vm.stopPrank();
    }
}
