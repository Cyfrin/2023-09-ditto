// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U88} from "contracts/libraries/PRBMathHelper.sol";

import {ForkHelper} from "test/fork/ForkHelper.sol";
import {Vault} from "contracts/libraries/Constants.sol";

// import {console} from "contracts/libraries/console.sol";

contract BridgeForkTest is ForkHelper {
    using U256 for uint256;
    using U88 for uint88;

    function setUp() public virtual override {
        forkBlock = bridgeBlock;
        super.setUp();
        deal(sender, 1000 ether);
        assertEq(sender.balance, 1000 ether);
        assertEq(diamond.getVaultUserStruct(Vault.CARBON, sender).ethEscrowed, 0);
    }

    function testFork_RethIntegration_Eth() public {
        uint256 initialDeposit = 100 ether;

        vm.startPrank(sender);
        assertEq(reth.balanceOf(_bridgeReth), 0);

        diamond.depositEth{value: initialDeposit}(_bridgeReth);

        //rocketpool reth deposit fee = 5 bps
        uint256 rethDepositFee = initialDeposit.mul(0.0005 ether);
        uint256 zethMinted = initialDeposit - rethDepositFee;

        assertEq(reth.balanceOf(_bridgeReth), reth.getRethValue(zethMinted));
        assertEq(sender.balance, 1000 ether - initialDeposit);

        uint88 currentEthEscrowed =
            diamond.getVaultUserStruct(Vault.CARBON, sender).ethEscrowed;

        assertApproxEqAbs(currentEthEscrowed, zethMinted, MAX_DELTA_SMALL);

        diamond.unstakeEth(_bridgeReth, currentEthEscrowed);

        assertEq(diamond.getVaultUserStruct(Vault.CARBON, sender).ethEscrowed, 0);
        assertApproxEqAbs(sender.balance, 1000 ether - rethDepositFee, MAX_DELTA_SMALL);
        assertApproxEqAbs(reth.balanceOf(_bridgeReth), 0, MAX_DELTA_SMALL);
    }

    function testFork_RethIntegration_Reth() public {
        uint88 initialDeposit = 100 ether;
        deal(_reth, sender, initialDeposit);

        vm.startPrank(sender);
        assertEq(reth.balanceOf(_bridgeReth), 0);
        assertEq(reth.balanceOf(sender), initialDeposit);

        reth.approve(
            _bridgeReth,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        diamond.deposit(_bridgeReth, initialDeposit);

        uint256 zethMinted = reth.getEthValue(initialDeposit);

        assertEq(reth.balanceOf(_bridgeReth), initialDeposit);
        assertEq(reth.balanceOf(sender), 0);

        uint88 currentEthEscrowed =
            diamond.getVaultUserStruct(Vault.CARBON, sender).ethEscrowed;
        assertEq(currentEthEscrowed, zethMinted);

        diamond.withdraw(_bridgeReth, currentEthEscrowed);
        uint256 fee = reth.getRethValue(
            currentEthEscrowed.mul(
                diamond.getBridgeNormalizedStruct(_bridgeReth).withdrawalFee
            )
        );

        assertEq(diamond.getVaultUserStruct(Vault.CARBON, sender).ethEscrowed, 0);
        assertApproxEqAbs(reth.balanceOf(sender), initialDeposit - fee, MAX_DELTA_SMALL);
        assertApproxEqAbs(reth.balanceOf(_bridgeReth), fee, MAX_DELTA_SMALL);
    }

    function testFork_StethIntegration_Eth() public {
        uint256 initialDeposit = 100 ether;
        vm.startPrank(sender);
        assertEq(steth.balanceOf(_bridgeSteth), 0);
        diamond.depositEth{value: initialDeposit}(_bridgeSteth);
        assertApproxEqAbs(steth.balanceOf(_bridgeSteth), initialDeposit, MAX_DELTA_SMALL);
        assertEq(sender.balance, 1000 ether - initialDeposit);

        uint88 currentEthEscrowed =
            diamond.getVaultUserStruct(Vault.CARBON, sender).ethEscrowed;
        assertApproxEqAbs(currentEthEscrowed, initialDeposit, MAX_DELTA_SMALL);
        assertEq(unsteth.balanceOf(sender), 0);

        diamond.unstakeEth(_bridgeSteth, currentEthEscrowed);
        assertEq(diamond.getVaultUserStruct(Vault.CARBON, sender).ethEscrowed, 0);
        assertApproxEqAbs(steth.balanceOf(_bridgeSteth), 0, MAX_DELTA_SMALL);
        assertEq(unsteth.balanceOf(sender), 1);
    }

    function testFork_StethIntegration_Steth() public {
        uint88 initialDeposit = 100 ether;
        vm.startPrank(sender);

        steth.submit{value: initialDeposit}(address(0));
        steth.approve(
            _bridgeSteth,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        assertEq(sender.balance, 1000 ether - initialDeposit);
        assertApproxEqAbs(steth.balanceOf(sender), initialDeposit, MAX_DELTA_SMALL);
        assertEq(steth.balanceOf(_bridgeSteth), 0);

        diamond.deposit(_bridgeSteth, initialDeposit);
        assertEq(steth.balanceOf(sender), 0);
        assertApproxEqAbs(steth.balanceOf(_bridgeSteth), initialDeposit, MAX_DELTA_SMALL);

        uint88 currentEthEscrowed =
            diamond.getVaultUserStruct(Vault.CARBON, sender).ethEscrowed;
        assertApproxEqAbs(currentEthEscrowed, initialDeposit, MAX_DELTA_SMALL);
        assertEq(unsteth.balanceOf(sender), 0);

        diamond.withdraw(_bridgeSteth, currentEthEscrowed);
        uint256 fee = currentEthEscrowed.mul(
            diamond.getBridgeNormalizedStruct(_bridgeSteth).withdrawalFee
        );

        assertEq(diamond.getVaultUserStruct(Vault.CARBON, sender).ethEscrowed, 0);
        assertApproxEqAbs(steth.balanceOf(sender), initialDeposit - fee, MAX_DELTA_SMALL);
        assertApproxEqAbs(steth.balanceOf(_bridgeSteth), fee, MAX_DELTA_SMALL);
    }
}
