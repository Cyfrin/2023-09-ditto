// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {Errors} from "contracts/libraries/Errors.sol";

import {OBFixture} from "test/utils/OBFixture.sol";
import {IMockAggregatorV3} from "interfaces/IMockAggregatorV3.sol";
import {Constants} from "contracts/libraries/Constants.sol";
// import {console} from "contracts/libraries/console.sol";

contract OracleRevertTest is OBFixture {
    function setUp() public override {
        super.setUp();
    }

    function test_RevertInvalidAsset() public {
        vm.expectRevert(Errors.InvalidAsset.selector);
        diamond.getAssetPrice(address(1));
    }
}
