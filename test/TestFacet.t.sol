// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256} from "contracts/libraries/PRBMathHelper.sol";
import {Errors} from "contracts/libraries/Errors.sol";

import {Constants} from "contracts/libraries/Constants.sol";
// import {console} from "contracts/libraries/console.sol";
import {STypes, MTypes, O} from "contracts/libraries/DataTypes.sol";

import {OBFixture} from "test/utils/OBFixture.sol";

contract TestFacetTest is OBFixture {
    using U256 for uint256;

    function setUp() public virtual override {
        super.setUp();
    }

    function test_TestFacetMisc() public {
        diamond.nonZeroVaultSlot0(1);
        diamond.setErcDebtRate(asset, 1);
    }

    function test_setReentrantStatus() public {
        assertEq(diamond.getReentrantStatus(), Constants.NOT_ENTERED);
        diamond.setReentrantStatus(Constants.ENTERED);
        assertEq(diamond.getReentrantStatus(), Constants.ENTERED);
    }

    function test_getUserOrder_Bids() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        STypes.Order[] memory bids = diamond.getUserOrders(asset, receiver, O.LimitBid);
        assertEq(bids.length, 3);
    }

    function test_getUserOrder_Ask() public {
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        STypes.Order[] memory asks = diamond.getUserOrders(asset, receiver, O.LimitAsk);
        assertEq(asks.length, 3);
    }

    function test_getUserOrder_Short() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        STypes.Order[] memory shorts =
            diamond.getUserOrders(asset, receiver, O.LimitShort);
        assertEq(shorts.length, 3);
    }
}
