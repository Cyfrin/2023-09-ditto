// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U88} from "contracts/libraries/PRBMathHelper.sol";
import {Errors} from "contracts/libraries/Errors.sol";

import {IAsset} from "interfaces/IAsset.sol";
import {OBFixture} from "test/utils/OBFixture.sol";
import {console} from "contracts/libraries/console.sol";

contract RegressionTest is OBFixture {
    using U88 for uint88;

    function setUp() public override {
        super.setUp();
    }

    function test_RegressionInv_Deal() public {
        // when dealing RETH, need to deal ETH to RETH contract as well
        deal(_reth, 0x0000000000000000000000000000000000000086, 9999999900000000018095);
        deal(_reth, 9999999900000000018095);
        vm.prank(0x0000000000000000000000000000000000000086);
        reth.approve(_bridgeReth, type(uint88).max);
        vm.prank(0x0000000000000000000000000000000000000086);
        diamond.deposit(_bridgeReth, 9999999900000000018095);
        vm.prank(0x0000000000000000000000000000000000000086);
        diamond.withdraw(_bridgeReth, 1);
        // because RocketTokenRETH.burn assumes depositEth vs deposit
        vm.prank(0x0000000000000000000000000000000000000086);
        diamond.unstakeEth(_bridgeReth, 9115);
    }

    function test_RegressionInv_Deal_TotalSupply() public {
        // function deal(address token, address to, uint256 give, bool adjust) external;
        // deal should adjust totalSupply (true)
        deal(_reth, 0x0000000000000000000000000000000000000003, 100000000000003, true);
        deal(_reth, 100000000000003);
        vm.prank(0x0000000000000000000000000000000000000003);
        reth.approve(_bridgeReth, type(uint88).max);
        vm.prank(0x0000000000000000000000000000000000000003);
        diamond.deposit(_bridgeReth, 100000000000003);
        // bridge=100000000000003 zethTotal=100000000000003
        vm.prank(0x0000000000000000000000000000000000000003);
        diamond.unstakeEth(_bridgeReth, 35784174486415);
        // bridge=64215825513588 zethTotal=64215825513588 ethEscrowed=100000000000003
        deal(0x0000000000000000000000000000000000000013, 9999999900000124739307);
        vm.prank(0x0000000000000000000000000000000000000013);
        diamond.depositEth{value: 9999999900000124739307}(_bridgeReth);
        deal(0x0000000000000000000000000000000000000013, 9999999900000124739307);
        vm.prank(0x0000000000000000000000000000000000000013);
        diamond.depositEth{value: 9999999900000124739307}(_bridgeReth);
    }

    function test_RegressionInv_2() public {
        deal(address(8), 100 ether);
        vm.startPrank(address(8));
        diamond.depositEth{value: 100 ether}(_bridgeReth);
        diamond.unstakeEth(_bridgeReth, 100 ether);
        vm.stopPrank();
    }

    function test_Misc_Error_selector() public {
        // console.logBytes4(bytes4(Errors.BadShortHint.selector));
        // console.logBytes4(bytes4(getSelector("BadShortHint()")));
        assertEq(Errors.BadShortHint.selector, getSelector("BadShortHint()"));
    }

    function test_RegressionInv_MatchBackwardsButNotAllTheWay() public {
        // original
        // fundLimitShortOpt(250000000000003, 9999999999999999997, address(1));
        // fundLimitShortOpt(250000000000002, 6985399747473758833, address(2));
        // fundLimitBidOpt(2250000000010210, 9000000000000001778, address(3));
        // fundLimitBidOpt(2250000000001666, 9000000000000000104, address(4));

        // change updateSellOrdersOnMatch to handle when updating HEAD <-> HEAD
        fundLimitShortOpt(DEFAULT_PRICE + 1 wei, DEFAULT_AMOUNT, address(1)); //100
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(0.5 ether), address(2)); //101
        fundLimitBidOpt(DEFAULT_PRICE * 10, DEFAULT_AMOUNT.mulU88(1.1 ether), address(3));
        assertEq(diamond.getShorts(asset).length, 1); // was 2
            // console.logShorts(asset);
    }
}
