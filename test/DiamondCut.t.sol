// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {Errors} from "contracts/libraries/Errors.sol";
import {IDiamondCut} from "contracts/interfaces/IDiamondCut.sol";

import {OBFixture} from "test/utils/OBFixture.sol";

interface ITestingFacet {
    function newFunction() external returns (uint256);
}

contract AddFacet {
    function newFunction() external pure returns (uint256) {
        return 1;
    }
}

contract ReplaceFacet {
    function newFunction() external pure returns (uint256) {
        return 2;
    }
}

contract DiamondTest is OBFixture {
    function setUp() public override {
        super.setUp();
    }

    function test_FacetCutAction_Add() public {
        vm.startPrank(owner);

        // create the facet
        AddFacet addFacet = new AddFacet();

        bytes4[] memory testSelectors = new bytes4[](1);
        testSelectors[0] = ITestingFacet.newFunction.selector;

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = (
            IDiamondCut.FacetCut({
                facetAddress: address(addFacet),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: testSelectors
            })
        );

        // check that no function exists
        vm.expectRevert();
        ITestingFacet(_diamond).newFunction();

        IDiamondCut(_diamond).diamondCut(cut, address(0x0), "");

        assertEq(ITestingFacet(_diamond).newFunction(), 1);
    }

    function test_FacetCutAction_Replace() public {
        vm.startPrank(owner);

        AddFacet addFacet = new AddFacet();

        bytes4[] memory testSelectors = new bytes4[](1);
        testSelectors[0] = ITestingFacet.newFunction.selector;

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = (
            IDiamondCut.FacetCut({
                facetAddress: address(addFacet),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: testSelectors
            })
        );

        // check that function exists
        IDiamondCut(_diamond).diamondCut(cut, address(0x0), "");
        assertEq(ITestingFacet(_diamond).newFunction(), 1);

        // create the facet
        ReplaceFacet replaceFacet = new ReplaceFacet();

        cut[0] = (
            IDiamondCut.FacetCut({
                facetAddress: address(replaceFacet),
                action: IDiamondCut.FacetCutAction.Replace,
                functionSelectors: testSelectors
            })
        );

        IDiamondCut(_diamond).diamondCut(cut, address(0x0), "");
        assertEq(ITestingFacet(_diamond).newFunction(), 2);
    }

    // function test_FacetCutAction_Remove() public {
    //     vm.startPrank(owner);

    //     AddFacet addFacet = new AddFacet();

    //     bytes4[] memory testSelectors = new bytes4[](1);
    //     testSelectors[0] = ITestingFacet.newFunction.selector;

    //     IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
    //     cut[0] = (
    //         IDiamondCut.FacetCut({
    //             facetAddress: address(addFacet),
    //             action: IDiamondCut.FacetCutAction.Add,
    //             functionSelectors: testSelectors
    //         })
    //     );

    //     // check that function exists
    //     IDiamondCut(_diamond).diamondCut(cut, address(0x0), "");
    //     assertEq(ITestingFacet(_diamond).newFunction(), 1);

    //     // remove the facet
    //     IDiamondCut.FacetCut[] memory cut2 = new IDiamondCut.FacetCut[](1);
    //     cut2[0] = (
    //         IDiamondCut.FacetCut({
    //             facetAddress: address(0),
    //             action: IDiamondCut.FacetCutAction.Remove,
    //             functionSelectors: testSelectors
    //         })
    //     );

    //     IDiamondCut(_diamond).diamondCut(cut2, address(0x0), "");
    //     vm.expectRevert();
    //     ITestingFacet(_diamond).newFunction();
    // }
}
