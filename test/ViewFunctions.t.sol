// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256} from "contracts/libraries/PRBMathHelper.sol";
import {Errors} from "contracts/libraries/Errors.sol";

import {Constants} from "contracts/libraries/Constants.sol";
// import {console} from "contracts/libraries/console.sol";
import {STypes} from "contracts/libraries/DataTypes.sol";

import {OBFixture} from "test/utils/OBFixture.sol";

contract ViewFunctionsTest is OBFixture {
    using U256 for uint256;

    function setUp() public virtual override {
        super.setUp();
    }

    // OracleFacet
    function test_view_getProtocolAssetPrice() public {
        uint256 price = 4000 ether;
        assertEq(diamond.getProtocolAssetPrice(asset), price.inv());
    }

    // ShortRecordFacet
    function test_view_getShortRecords() public {
        assertEq(getShortRecordCount(sender), 0);
        assertEq(diamond.getShortRecords(asset, sender).length, 0);

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        assertEq(getShortRecordCount(sender), 1);

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        assertEq(getShortRecordCount(sender), 2);

        STypes.ShortRecord memory short =
            getShortRecord(sender, Constants.SHORT_STARTING_ID);
        STypes.ShortRecord memory short2 =
            getShortRecord(sender, Constants.SHORT_STARTING_ID + 1);
        assertEqShort(diamond.getShortRecords(asset, sender)[0], short2);
        assertEqShort(diamond.getShortRecords(asset, sender)[1], short);
    }

    // VaultFacet
    function test_view_getZethBalance() public {
        assertEq(diamond.getZethBalance(vault, sender), 0);

        vm.deal(sender, 10000 ether);
        uint256 deposit1 = 1000 ether;
        vm.prank(sender);
        diamond.depositEth{value: deposit1}(_bridgeReth);
        assertEq(diamond.getZethBalance(vault, sender), deposit1);
    }

    function test_view_getAssetBalance() public {
        assertEq(diamond.getAssetBalance(asset, sender), 0);
        depositUsd(sender, DEFAULT_AMOUNT);
        assertEq(diamond.getAssetBalance(asset, sender), DEFAULT_AMOUNT);
    }

    function test_view_getVault() public {
        assertEq(diamond.getVault(asset), vault);
    }

    // OrdersFacet
    function test_view_getXHintId() public {
        assertEq(diamond.getBidHintId(asset, DEFAULT_PRICE), 1);
        assertEq(diamond.getShortHintId(asset, DEFAULT_PRICE), 1);
        assertEq(diamond.getAskHintId(asset, DEFAULT_PRICE), 1);

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(DEFAULT_PRICE + 1, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(DEFAULT_PRICE + 2, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE + 1, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE + 2, DEFAULT_AMOUNT, receiver);

        assertEq(diamond.getBidHintId(asset, DEFAULT_PRICE), 101);
        assertEq(diamond.getAskHintId(asset, DEFAULT_PRICE + 2), 103);
        assertEq(diamond.getShortHintId(asset, DEFAULT_PRICE + 2), 105);
    }

    function test_view_getShortIdAtOracle() public {
        assertEq(diamond.getShortIdAtOracle(asset), 1);

        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE - 1, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE + 1, DEFAULT_AMOUNT, receiver);

        assertEq(diamond.getShortIdAtOracle(asset), 100);
    }
}
