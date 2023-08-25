// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {OBFixture} from "test/utils/OBFixture.sol";

contract DeployTest is OBFixture {
    function setUp() public override {
        super.setUp();
    }

    function testDittoGovernorRoles() public {
        assertTrue(dittoTimelockController.hasRole(PROPOSER_ROLE, _dittoGovernor));
        assertTrue(dittoTimelockController.hasRole(CANCELLER_ROLE, _dittoGovernor));
        assertTrue(dittoTimelockController.hasRole(EXECUTOR_ROLE, _dittoGovernor));
    }

    // function testRenounceTimelockAdmin() public {
    //     assertFalse(dittoTimelockController.hasRole(TIMELOCK_ADMIN_ROLE, owner));
    // }

    // function testTimelockMinDelay() public {
    //     assertEq(dittoTimelockController.getMinDelay(), 172800);
    // }
}
