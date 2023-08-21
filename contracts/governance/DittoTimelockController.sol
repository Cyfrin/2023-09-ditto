// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {TimelockController} from
    "@openzeppelin/contracts/governance/TimelockController.sol";

contract DittoTimelockController is TimelockController {
    constructor(address[] memory proposers, address[] memory executors, address admin)
        // arg[0] - min delay - set to 2 day after bootstrap
        // arg[1] - propser - set to deployer
        // arg[2] - executor - set to deployer
        // arg[3] - admin - remember to revoke
        TimelockController(0, proposers, executors, admin)
    {}
}
