// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256} from "contracts/libraries/PRBMathHelper.sol";

import {Vault} from "contracts/libraries/Constants.sol";

import {GasForkHelper} from "test-gas/GasHelper.sol";

contract GasForkYield is GasForkHelper {
    using U256 for uint256;

    function setUp() public virtual override {
        super.setUp();
        // Simulate a bunch of yield
        deal(_reth, _bridgeReth, 10000 ether);
    }

    function testFork_UpdateYield() public {
        vm.startPrank(sender);
        startMeasuringGas("Yield-UpdateYield");
        diamond.updateYield(Vault.CARBON);
        stopMeasuringGas();
        vm.stopPrank();
    }
}
