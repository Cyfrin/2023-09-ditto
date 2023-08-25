// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U88} from "contracts/libraries/PRBMathHelper.sol";
import {Vm} from "forge-std/Vm.sol";

import {OBFixture} from "test/utils/OBFixture.sol";
import {Vault} from "contracts/libraries/Constants.sol";
// import {console} from "contracts/libraries/console.sol";

contract BridgeRouterTest is OBFixture {
    using U256 for uint256;
    using U88 for uint88;

    function setUp() public virtual override {
        super.setUp();

        for (uint160 k = 1; k <= 4; k++) {
            vm.startPrank(address(k));
            reth.approve(
                _bridgeReth,
                0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
            );
            steth.approve(
                _bridgeSteth,
                0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
            );
            vm.stopPrank();
        }
    }

    function test_GetBaseCollateral() public {
        assertEq(bridgeSteth.getBaseCollateral(), _steth);
        assertEq(
            bridgeReth.getBaseCollateral(),
            rocketStorage.getAddress(
                keccak256(abi.encodePacked("contract.address", "rocketTokenRETH"))
            )
        );
    }

    function testBridgeDeposit() public {
        assertEq(diamond.getVaultUserStruct(Vault.CARBON, sender).ethEscrowed, 0 ether);
        assertEq(diamond.getVaultUserStruct(Vault.CARBON, receiver).ethEscrowed, 0 ether);
        assertEq(diamond.getVaultStruct(Vault.CARBON).zethTotal, 0 ether);
        assertEq(diamond.getZethTotal(Vault.CARBON), 0 ether);

        deal(sender, 10000 ether);
        deal(_reth, sender, 10000 ether);
        deal(_steth, sender, 10000 ether);

        vm.startPrank(sender);

        uint88 deposit1 = 1000 ether;
        diamond.depositEth{value: deposit1}(_bridgeReth);
        diamond.deposit(_bridgeReth, deposit1);
        diamond.deposit(_bridgeSteth, deposit1);
        assertEq(
            diamond.getVaultUserStruct(Vault.CARBON, sender).ethEscrowed, deposit1 * 3
        );
        assertEq(diamond.getVaultUserStruct(Vault.CARBON, receiver).ethEscrowed, 0 ether);

        assertEq(diamond.getVaultStruct(Vault.CARBON).zethTotal, deposit1 * 3);
        assertEq(diamond.getZethTotal(Vault.CARBON), deposit1 * 3);
        assertEq(bridgeReth.getZethValue(), deposit1 * 2);
        assertEq(bridgeSteth.getZethValue(), deposit1);

        uint88 deposit2 = 1 ether;
        diamond.depositEth{value: deposit2}(_bridgeReth);
        diamond.deposit(_bridgeReth, deposit2);
        diamond.deposit(_bridgeSteth, deposit2);

        vm.stopPrank();

        assertEq(
            diamond.getVaultUserStruct(Vault.CARBON, sender).ethEscrowed,
            deposit1 * 3 + deposit2 * 3
        );
        assertEq(diamond.getVaultUserStruct(Vault.CARBON, receiver).ethEscrowed, 0 ether);

        assertEq(
            diamond.getVaultStruct(Vault.CARBON).zethTotal, deposit1 * 3 + deposit2 * 3
        );
        assertEq(diamond.getZethTotal(Vault.CARBON), deposit1 * 3 + deposit2 * 3);
        assertEq(bridgeReth.getZethValue(), deposit1 * 2 + deposit2 * 2);
        assertEq(bridgeSteth.getZethValue(), deposit1 + deposit2);

        vm.deal(receiver, 10000 ether);
        deal(_reth, receiver, 10000 ether);
        deal(_steth, receiver, 10000 ether);

        vm.startPrank(receiver);

        diamond.depositEth{value: deposit1}(_bridgeReth);
        diamond.deposit(_bridgeReth, deposit1);
        diamond.deposit(_bridgeSteth, deposit1);

        assertEq(
            diamond.getVaultUserStruct(Vault.CARBON, sender).ethEscrowed,
            deposit1 * 3 + deposit2 * 3
        );
        assertEq(
            diamond.getVaultUserStruct(Vault.CARBON, receiver).ethEscrowed, deposit1 * 3
        );

        assertEq(
            diamond.getVaultStruct(Vault.CARBON).zethTotal, deposit1 * 6 + deposit2 * 3
        );
        assertEq(diamond.getZethTotal(Vault.CARBON), deposit1 * 6 + deposit2 * 3);
        assertEq(bridgeReth.getZethValue(), deposit1 * 4 + deposit2 * 2);
        assertEq(bridgeSteth.getZethValue(), deposit1 * 2 + deposit2);
    }

    function testBridgeDepositUpdateYield() public {
        // Fund sender to deposit into bridges
        deal(sender, 1000 ether);
        deal(_reth, sender, 1000 ether);
        deal(_steth, sender, 1000 ether);
        // Seed bridges to set up yield updates
        vm.startPrank(sender);
        diamond.deposit(_bridgeReth, 500 ether);
        diamond.deposit(_bridgeSteth, 500 ether);
        assertEq(diamond.getVaultStruct(Vault.CARBON).zethTotal, 1000 ether);
        assertEq(diamond.getZethTotal(Vault.CARBON), 1000 ether);

        // Update Yield with ETH-RETH deposit
        deal(_steth, _bridgeSteth, 1000 ether); // Mimics 500 ether of yield
        diamond.depositEth{value: 500 ether}(_bridgeReth);
        // With updateYield the totals increase by 1000 instead of just 500
        assertEq(diamond.getVaultStruct(Vault.CARBON).zethTotal, 2000 ether);
        assertEq(diamond.getZethTotal(Vault.CARBON), 2000 ether);

        // Update Yield with ETH-STETH deposit
        deal(_steth, _bridgeSteth, 1500 ether); // Mimics 500 ether of yield
        diamond.depositEth{value: 500 ether}(_bridgeSteth);
        // With updateYield the totals increase by 1000 instead of just 500
        assertEq(diamond.getVaultStruct(Vault.CARBON).zethTotal, 3000 ether);
        assertEq(diamond.getZethTotal(Vault.CARBON), 3000 ether);

        // Update Yield with RETH deposit
        deal(_steth, _bridgeSteth, 2500 ether); // Mimics 500 ether of yield
        diamond.deposit(_bridgeReth, 500 ether);
        // With updateYield the totals increase by 1000 instead of just 500
        assertEq(diamond.getVaultStruct(Vault.CARBON).zethTotal, 4000 ether);
        assertEq(diamond.getZethTotal(Vault.CARBON), 4000 ether);

        // Update Yield with STETH deposit
        deal(_steth, _bridgeSteth, 3000 ether); // Mimics 500 ether of yield
        diamond.deposit(_bridgeSteth, 500 ether);
        // With updateYield the totals increase by 1000 instead of just 500
        assertEq(diamond.getVaultStruct(Vault.CARBON).zethTotal, 5000 ether);
        assertEq(diamond.getZethTotal(Vault.CARBON), 5000 ether);
    }

    function testBridgeDepositNoUpdateYieldPercent() public {
        // Fund sender to deposit into bridges
        deal(sender, 1000 ether);
        deal(_reth, sender, 1000 ether);
        deal(_steth, sender, 1000 ether);
        // Seed bridges to set up yield updates
        vm.startPrank(sender);
        diamond.deposit(_bridgeReth, 500 ether);
        diamond.deposit(_bridgeSteth, 500 ether);
        assertEq(diamond.getVaultStruct(Vault.CARBON).zethTotal, 1000 ether);
        assertEq(diamond.getZethTotal(Vault.CARBON), 1000 ether);

        // Update Yield with ETH-RETH deposit
        deal(_steth, _bridgeSteth, 1000 ether); // Mimics 500 ether of yield
        diamond.depositEth{value: 1 ether}(_bridgeReth);
        // Without updateYield the total only sees the deposit amount
        assertEq(diamond.getVaultStruct(Vault.CARBON).zethTotal, 1001 ether);
        assertEq(diamond.getZethTotal(Vault.CARBON), 1501 ether);

        // Update Yield with ETH-STETH deposit
        deal(_steth, _bridgeSteth, 1500 ether); // Mimics 500 ether of yield
        diamond.depositEth{value: 1 ether}(_bridgeSteth);
        // Without updateYield the total only sees the deposit amount
        assertEq(diamond.getVaultStruct(Vault.CARBON).zethTotal, 1002 ether);
        assertEq(diamond.getZethTotal(Vault.CARBON), 2002 ether);

        // Update Yield with RETH deposit
        deal(_steth, _bridgeSteth, 2001 ether); // Mimics 500 ether of yield
        diamond.deposit(_bridgeReth, 1 ether);
        // Without updateYield the total only sees the deposit amount
        assertEq(diamond.getVaultStruct(Vault.CARBON).zethTotal, 1003 ether);
        assertEq(diamond.getZethTotal(Vault.CARBON), 2503 ether);

        // Update Yield with STETH deposit
        deal(_steth, _bridgeSteth, 2501 ether); // Mimics 500 ether of yield
        diamond.deposit(_bridgeSteth, 1 ether);
        // Without updateYield the total only sees the deposit amount
        assertEq(diamond.getVaultStruct(Vault.CARBON).zethTotal, 1004 ether);
        assertEq(diamond.getZethTotal(Vault.CARBON), 3004 ether);
    }

    function testBridgeDepositNoUpdateYieldAmount() public {
        // Fund sender to deposit into bridges
        deal(sender, 1000 ether);
        deal(_reth, sender, 1000 ether);
        deal(_steth, sender, 1000 ether);
        // Seed bridges to set up yield updates
        vm.startPrank(sender);
        assertEq(diamond.getVaultStruct(Vault.CARBON).zethTotal, 0 ether);
        assertEq(diamond.getZethTotal(Vault.CARBON), 0 ether);

        // Update Yield with ETH-RETH deposit
        deal(_steth, _bridgeSteth, 100 ether); // Mimics 100 ether of yield
        diamond.depositEth{value: 100 ether}(_bridgeReth);
        // Without updateYield the total only sees the deposit amount
        assertEq(diamond.getVaultStruct(Vault.CARBON).zethTotal, 100 ether);
        assertEq(diamond.getZethTotal(Vault.CARBON), 200 ether);

        // Update Yield with ETH-STETH deposit
        deal(_steth, _bridgeSteth, 200 ether); // Mimics 100 ether of yield
        diamond.depositEth{value: 100 ether}(_bridgeSteth);
        // Without updateYield the total only sees the deposit amount
        assertEq(diamond.getVaultStruct(Vault.CARBON).zethTotal, 200 ether);
        assertEq(diamond.getZethTotal(Vault.CARBON), 400 ether);

        // Update Yield with RETH deposit
        deal(_steth, _bridgeSteth, 400 ether); // Mimics 100 ether of yield
        diamond.deposit(_bridgeReth, 100 ether);
        // Without updateYield the total only sees the deposit amount
        assertEq(diamond.getVaultStruct(Vault.CARBON).zethTotal, 300 ether);
        assertEq(diamond.getZethTotal(Vault.CARBON), 600 ether);

        // Update Yield with STETH deposit
        deal(_steth, _bridgeSteth, 500 ether); // Mimics 100 ether of yield
        diamond.deposit(_bridgeSteth, 100 ether);
        // Without updateYield the total only sees the deposit amount
        assertEq(diamond.getVaultStruct(Vault.CARBON).zethTotal, 400 ether);
        assertEq(diamond.getZethTotal(Vault.CARBON), 800 ether);
    }

    function testBridgeWithdraw() public {
        deal(_reth, sender, 100 ether);
        deal(_steth, sender, 100 ether);

        vm.startPrank(sender);

        diamond.deposit(_bridgeReth, 100 ether);
        diamond.deposit(_bridgeSteth, 100 ether);
        assertEq(diamond.getVaultUserStruct(Vault.CARBON, sender).ethEscrowed, 200 ether);
        assertEq(diamond.getVaultStruct(Vault.CARBON).zethTotal, 200 ether);

        uint88 withdrawAmount = 50 ether;
        diamond.withdraw(_bridgeReth, withdrawAmount);
        diamond.withdraw(_bridgeSteth, withdrawAmount);

        uint256 fee = diamond.getBridgeNormalizedStruct(_bridgeReth).withdrawalFee.mul(
            withdrawAmount
        );

        uint256 totalWithdrawn = withdrawAmount * 2;

        assertEq(
            diamond.getVaultUserStruct(Vault.CARBON, sender).ethEscrowed, totalWithdrawn
        );
        assertEq(diamond.getVaultStruct(Vault.CARBON).zethTotal, totalWithdrawn + fee);
        assertEq(bridgeSteth.getZethValue(), withdrawAmount);
        assertEq(steth.balanceOf(sender), withdrawAmount);
        assertEq(bridgeReth.getZethValue(), withdrawAmount + fee);
        assertEq(reth.balanceOf(sender), withdrawAmount - fee);
    }

    function testBridgeWithdrawFeeZero() public {
        deal(_steth, sender, 100 ether);

        vm.startPrank(sender);
        uint88 amount = 100 ether;
        diamond.deposit(_bridgeSteth, amount);

        uint256 stethWithdrawalFee =
            diamond.getBridgeNormalizedStruct(_bridgeSteth).withdrawalFee;
        assertEq(stethWithdrawalFee, 0);

        assertEq(diamond.getVaultUserStruct(Vault.CARBON, sender).ethEscrowed, amount);
        assertEq(diamond.getVaultStruct(Vault.CARBON).zethTotal, amount);

        assertEq(steth.balanceOf(sender), 0);
        diamond.withdraw(_bridgeSteth, amount);
        assertEq(steth.balanceOf(sender), amount);

        assertEq(diamond.getVaultUserStruct(Vault.CARBON, sender).ethEscrowed, 0);
        assertEq(diamond.getVaultStruct(Vault.CARBON).zethTotal, 0);
        vm.stopPrank();
    }

    function testBridgeWithdrawFeeMax() public {
        deal(_steth, sender, 100 ether);
        vm.prank(owner);
        //set withdrawal fee to max (15.00%)
        diamond.setWithdrawalFee(_bridgeSteth, 1500);
        vm.startPrank(sender);
        uint88 amount = 100 ether;
        diamond.deposit(_bridgeSteth, amount);

        uint256 stethWithdrawalFee =
            diamond.getBridgeNormalizedStruct(_bridgeSteth).withdrawalFee;
        assertEq(stethWithdrawalFee, 0.15 ether);

        assertEq(diamond.getVaultUserStruct(Vault.CARBON, sender).ethEscrowed, amount);
        assertEq(diamond.getVaultStruct(Vault.CARBON).zethTotal, amount);

        assertEq(steth.balanceOf(sender), 0);
        diamond.withdraw(_bridgeSteth, amount);
        assertEq(steth.balanceOf(sender), amount.mulU88(1 ether - stethWithdrawalFee));

        assertEq(diamond.getVaultUserStruct(Vault.CARBON, sender).ethEscrowed, 0);

        uint256 fee = amount.mul(stethWithdrawalFee);

        assertEq(diamond.getVaultUserStruct(Vault.CARBON, tapp).ethEscrowed, fee);
        assertEq(diamond.getVaultStruct(Vault.CARBON).zethTotal, fee);
    }

    function testBridgeWithdrawTapp() public {
        deal(_steth, sender, 100 ether);

        vm.prank(sender);
        diamond.deposit(_bridgeSteth, 100 ether);
        assertEq(diamond.getVaultUserStruct(Vault.CARBON, sender).ethEscrowed, 100 ether);
        assertEq(diamond.getVaultStruct(Vault.CARBON).zethTotal, 100 ether);
        assertEq(bridgeSteth.getZethValue(), 100 ether);

        // Generate Yield to TAPP
        deal(_steth, _bridgeSteth, 200 ether); // Mimics 100 ether of yield
        assertEq(diamond.getVaultUserStruct(Vault.CARBON, tapp).ethEscrowed, 0);
        diamond.updateYield(vault); // All yield goes to TAPP bc no shorts
        assertEq(diamond.getVaultUserStruct(Vault.CARBON, tapp).ethEscrowed, 100 ether);

        // DAO withdraws STETH from TAPP balance
        assertEq(steth.balanceOf(owner), 0);
        vm.prank(owner);
        diamond.withdrawTapp(_bridgeSteth, 100 ether);
        assertEq(steth.balanceOf(owner), 100 ether);
    }

    function testBridgeWithdrawNegativeYield() public {
        deal(_reth, sender, 100 ether);
        deal(_steth, sender, 100 ether);

        vm.startPrank(sender);

        diamond.deposit(_bridgeReth, 100 ether);
        diamond.deposit(_bridgeSteth, 100 ether);
        assertEq(diamond.getVaultUserStruct(Vault.CARBON, sender).ethEscrowed, 200 ether);
        assertEq(diamond.getVaultStruct(Vault.CARBON).zethTotal, 200 ether);
        // Negative Yield
        reth.submitBalances(50 ether, 100 ether);
        deal(_steth, _bridgeSteth, 50 ether);
        assertEq(bridgeReth.getZethValue(), 50 ether);
        assertEq(bridgeSteth.getZethValue(), 50 ether);

        uint88 withdrawAmount = 50 ether;
        diamond.withdraw(_bridgeSteth, withdrawAmount);
        diamond.withdraw(_bridgeReth, withdrawAmount);

        // Only rocketpool has fee for withdrawal in our tests
        uint256 rethFee = diamond.getBridgeNormalizedStruct(_bridgeReth).withdrawalFee.mul(
            withdrawAmount
        );
        uint256 rethFeeInZeth = reth.getEthValue(rethFee);

        uint256 totalWithdrawn = withdrawAmount * 2;

        assertEq(
            diamond.getVaultUserStruct(Vault.CARBON, sender).ethEscrowed,
            totalWithdrawn,
            "1"
        );
        assertEq(diamond.getVaultUserStruct(Vault.CARBON, tapp).ethEscrowed, rethFee);
        assertEq(
            diamond.getVaultStruct(Vault.CARBON).zethTotal, totalWithdrawn + rethFee, "2"
        );
        assertEq(bridgeSteth.getZethValue(), 25 ether, "3");
        assertEq(steth.balanceOf(sender), 25 ether, "4");
        assertEq(bridgeReth.getZethValue(), 25 ether + rethFeeInZeth, "5");
        assertEq(reth.balanceOf(sender), 50 ether - rethFee, "6");
    }

    function testDepositToRocketPoolMsgValue() public {
        deal(_reth, sender, 100 ether);
        vm.startPrank(sender);

        uint88 sentAmount = 100 ether;

        uint256 rethBalance1 = reth.balanceOf(_bridgeReth);
        diamond.deposit(_bridgeReth, sentAmount);
        uint256 rethBalance2 = reth.balanceOf(_bridgeReth);
        assertGt(rethBalance2, rethBalance1);
        uint256 zethValue = reth.getEthValue(rethBalance2 - rethBalance1);
        assertEq(sentAmount, zethValue);
    }

    function testUnstakeReth() public {
        assertEq(_reth.balance, 0 ether);
        assertEq(sender.balance, 0);
        deal(sender, 100 ether);
        assertEq(sender.balance, 100 ether);
        vm.startPrank(sender);
        diamond.depositEth{value: 100 ether}(_bridgeReth);
        assertEq(sender.balance, 0);
        assertEq(_reth.balance, 100 ether);
        assertEq(reth.balanceOf(_bridgeReth), 100 ether);
        diamond.unstakeEth(_bridgeReth, 100 ether);
        assertEq(sender.balance, 100 ether);
        assertEq(_reth.balance, 0 ether);
    }

    function testUnstakeSteth() public {
        assertEq(_steth.balance, 0 ether);
        assertEq(sender.balance, 0);
        deal(sender, 100 ether);
        assertEq(sender.balance, 100 ether);
        vm.startPrank(sender);
        diamond.depositEth{value: 100 ether}(_bridgeSteth);
        assertEq(sender.balance, 0);
        assertEq(_steth.balance, 100 ether);
        assertEq(steth.balanceOf(_bridgeSteth), 100 ether);
        vm.recordLogs();
        diamond.unstakeEth(_bridgeSteth, 100 ether);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(
            entries[entries.length - 2].topics[0],
            keccak256("Transfer(address,address,uint256)")
        );
        assertEq(
            entries[entries.length - 2].topics[1], bytes32(uint256(uint160(_bridgeSteth)))
        );
        assertEq(entries[entries.length - 2].topics[2], bytes32(uint256(uint160(sender))));
        assertEq(entries[entries.length - 2].topics[3], bytes32(uint256(1)));
        assertEq(_steth.balance, 100 ether);
        assertEq(_unsteth.balance, 0);
        assertEq(unsteth.ownerOf(1), sender);
        unsteth.processWithdrawals();
        assertEq(_steth.balance, 0);
        assertEq(_unsteth.balance, 100 ether);
        uint256[] memory requestIds = new uint256[](1);
        requestIds[0] = 1;
        uint256[] memory fakeHint;
        unsteth.claimWithdrawals(requestIds, fakeHint);
        assertEq(sender.balance, 100 ether);
        assertEq(_unsteth.balance, 0);
    }

    function testUnstakeFee() public {
        vm.prank(owner);
        diamond.setUnstakeFee(_bridgeReth, 100);
        assertEq(_reth.balance, 0 ether);
        assertEq(sender.balance, 0);
        deal(sender, 100 ether);
        assertEq(sender.balance, 100 ether);
        vm.startPrank(sender);
        diamond.depositEth{value: 100 ether}(_bridgeReth);
        assertEq(sender.balance, 0);
        assertEq(_reth.balance, 100 ether);
        assertEq(reth.balanceOf(_bridgeReth), 100 ether);
        diamond.unstakeEth(_bridgeReth, 100 ether);
        assertEq(sender.balance, 99 ether);
        assertEq(diamond.getVaultUserStruct(Vault.CARBON, tapp).ethEscrowed, 1 ether);
    }
}
