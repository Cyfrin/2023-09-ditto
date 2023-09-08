// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {OBFixture} from "test/utils/OBFixture.sol";

contract DiamondTest is OBFixture {
    error NotDiamond();

    function setUp() public override {
        super.setUp();
    }

    function test_RevertIfNotDiamondForDITTO() public {
        // works for diamond
        vm.prank(_diamond);
        ditto.mint(sender, 1);

        vm.expectRevert(NotDiamond.selector);
        ditto.mint(sender, 1);

        vm.expectRevert(NotDiamond.selector);
        ditto.burnFrom(sender, 1);
    }

    function test_Asset() public {
        vm.startPrank(_diamond);
        zeth.mint(sender, 1);
        zeth.burnFrom(sender, 1);

        ditto.mint(sender, 1);
        ditto.burnFrom(sender, 1);

        cusd.mint(sender, 1);
        cusd.burnFrom(sender, 1);
    }

    function test_RevertIfNotDiamondForZETH() public {
        // works for diamond
        vm.prank(_diamond);
        zeth.mint(sender, 1);

        vm.expectRevert(NotDiamond.selector);
        zeth.mint(sender, 1);

        vm.expectRevert(NotDiamond.selector);
        zeth.burnFrom(sender, 1);
    }

    function test_RevertIfNotDiamondForCUSD() public {
        // works for diamond
        vm.prank(_diamond);
        cusd.mint(sender, 1);

        vm.expectRevert(NotDiamond.selector);
        cusd.mint(sender, 1);

        vm.expectRevert(NotDiamond.selector);
        cusd.burnFrom(sender, 1);
    }
}
