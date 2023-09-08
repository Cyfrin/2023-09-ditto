// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256} from "contracts/libraries/PRBMathHelper.sol";

import {GasForkHelper} from "test-gas/GasHelper.sol";

contract GasForkBridge is GasForkHelper {
    using U256 for uint256;

    function setUp() public virtual override {
        super.setUp();
    }

    function testFork_GasDepositTokenETHtoRETH() public {
        address bridgeReth = _bridgeReth;
        vm.startPrank(sender);
        startMeasuringGas("Bridge-DepositToken-ETHtoRETH");
        diamond.depositEth{value: 1 ether}(bridgeReth);
        stopMeasuringGas();
        vm.stopPrank();
    }

    function testFork_GasDepositTokenETHtoRETHLarge() public {
        address bridgeReth = _bridgeReth;
        vm.startPrank(sender);
        startMeasuringGas("Bridge-DepositToken-ETHtoRETH-Large");
        diamond.depositEth{value: 100 ether}(bridgeReth);
        stopMeasuringGas();
        vm.stopPrank();
    }

    function testFork_GasDepositTokenETHtoSTETH() public {
        address bridgeSteth = _bridgeSteth;
        vm.startPrank(sender);
        startMeasuringGas("Bridge-DepositToken-ETHtoSTETH");
        diamond.depositEth{value: 1 ether}(bridgeSteth);
        stopMeasuringGas();
        vm.stopPrank();
    }

    function testFork_GasDepositTokenETHtoSTETHLarge() public {
        address bridgeSteth = _bridgeSteth;
        vm.startPrank(sender);
        startMeasuringGas("Bridge-DepositToken-ETHtoSTETH-Large");
        diamond.depositEth{value: 100 ether}(bridgeSteth);
        stopMeasuringGas();
        vm.stopPrank();
    }

    function testFork_GasDepositTokenRETH() public {
        address bridgeReth = _bridgeReth;
        vm.startPrank(sender);
        startMeasuringGas("Bridge-DepositToken-RETH");
        diamond.deposit(bridgeReth, 1 ether);
        stopMeasuringGas();
        vm.stopPrank();
    }

    function testFork_GasDepositTokenRETHLarge() public {
        address bridgeReth = _bridgeReth;
        vm.startPrank(sender);
        startMeasuringGas("Bridge-DepositToken-RETH-Large");
        diamond.deposit(bridgeReth, 100 ether);
        stopMeasuringGas();
        vm.stopPrank();
    }

    function testFork_GasDepositTokenSTETH() public {
        address bridgeSteth = _bridgeSteth;
        vm.startPrank(sender);
        startMeasuringGas("Bridge-DepositToken-STETH");
        diamond.deposit(bridgeSteth, 1 ether);
        stopMeasuringGas();
        vm.stopPrank();
    }

    function testFork_GasDepositTokenSTETHLarge() public {
        address bridgeSteth = _bridgeSteth;
        vm.startPrank(sender);
        startMeasuringGas("Bridge-DepositToken-STETH-Large");
        diamond.deposit(bridgeSteth, 100 ether);
        stopMeasuringGas();
        vm.stopPrank();
    }
}

contract GasForkBridgeWithdrawTest is GasForkBridge {
    using U256 for uint256;

    function testFork_GasWithdrawRETH() public {
        address bridgeReth = _bridgeReth;
        vm.startPrank(sender);
        startMeasuringGas("Bridge-Withdraw-RETH");
        diamond.withdraw(bridgeReth, 1 ether);
        stopMeasuringGas();
        vm.stopPrank();
    }

    function testFork_GasWithdrawSTETH() public {
        address bridgeSteth = _bridgeSteth;
        vm.startPrank(sender);
        startMeasuringGas("Bridge-Withdraw-STETH");
        diamond.withdraw(bridgeSteth, 1 ether);
        stopMeasuringGas();
        vm.stopPrank();
    }
}

contract GasForkBridgeWithdrawTappTest is GasForkBridge {
    using U256 for uint256;

    function setUp() public virtual override {
        super.setUp();
        diamond.setEthEscrowed(_diamond, 1 ether);
        // Seed TAPP with nonzero to get steady state gas cost
        deal(_reth, owner, 1 ether);
        deal(owner, 1 ether);
        vm.prank(owner);
        steth.submit{value: 1 ether}(address(0));
    }

    function testFork_GasWithdrawTappRETH() public {
        address bridgeReth = _bridgeReth;
        vm.startPrank(owner);
        startMeasuringGas("Bridge-WithdrawTapp-RETH");
        diamond.withdrawTapp(bridgeReth, 1 ether);
        stopMeasuringGas();
        vm.stopPrank();
    }

    function testFork_GasWithdrawTappSTETH() public {
        address bridgeSteth = _bridgeSteth;
        vm.startPrank(owner);
        startMeasuringGas("Bridge-WithdrawTapp-STETH");
        diamond.withdrawTapp(bridgeSteth, 1 ether);
        stopMeasuringGas();
        vm.stopPrank();
    }
}

contract GasForkBridgeUnstakeTest is GasForkBridge {
    using U256 for uint256;

    function testFork_GasUnstakeRETH() public {
        address bridgeReth = _bridgeReth;
        vm.startPrank(sender);
        startMeasuringGas("Bridge-Unstake-RETH");
        diamond.unstakeEth(bridgeReth, 1 ether);
        stopMeasuringGas();
        vm.stopPrank();
    }

    function testFork_GasUnstakeSTETH() public {
        address bridgeSteth = _bridgeSteth;
        vm.startPrank(sender);
        startMeasuringGas("Bridge-Unstake-STETH");
        diamond.unstakeEth(bridgeSteth, 1 ether);
        stopMeasuringGas();
        vm.stopPrank();
    }
}
