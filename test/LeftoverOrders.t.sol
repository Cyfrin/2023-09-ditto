// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U80} from "contracts/libraries/PRBMathHelper.sol";

import {Constants} from "contracts/libraries/Constants.sol";

import {OBFixture} from "test/utils/OBFixture.sol";
// import {console} from "contracts/libraries/console.sol";

contract LeftoverOrdersTest is OBFixture {
    using U256 for uint256;
    using U80 for uint80;

    function setUp() public override {
        super.setUp();
    }

    function test_NoLeftoverLimitAsk() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT + 1 wei, sender);

        assertEq(getBids().length, 0);
        assertEq(getAsks().length, 0);

        assertEq(diamond.getVaultUserStruct(vault, receiver).ethEscrowed, 0);
        assertEq(diamond.getAssetUserStruct(asset, receiver).ercEscrowed, DEFAULT_AMOUNT);
        assertEq(
            diamond.getVaultUserStruct(vault, sender).ethEscrowed,
            DEFAULT_PRICE.mul(DEFAULT_AMOUNT)
        );
        assertEq(diamond.getAssetUserStruct(asset, sender).ercEscrowed, 1 wei);
    }

    function test_NoLeftoverLimitShort() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT + 1 wei, sender);

        assertEq(getBids().length, 0);
        assertEq(getShorts().length, 0);

        assertEq(diamond.getVaultUserStruct(vault, receiver).ethEscrowed, 0);
        assertEq(diamond.getAssetUserStruct(asset, receiver).ercEscrowed, DEFAULT_AMOUNT);
        assertEq(diamond.getVaultUserStruct(vault, sender).ethEscrowed, 0);
        assertEq(diamond.getAssetUserStruct(asset, sender).ercEscrowed, 0);
    }

    function test_NoLeftoverLimitBid() public {
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT + 1 wei, receiver);

        assertEq(getBids().length, 0);
        assertEq(getAsks().length, 0);

        assertEq(diamond.getVaultUserStruct(vault, receiver).ethEscrowed, 0);
        assertEq(diamond.getAssetUserStruct(asset, receiver).ercEscrowed, DEFAULT_AMOUNT);
        assertEq(
            diamond.getVaultUserStruct(vault, sender).ethEscrowed,
            DEFAULT_PRICE.mul(DEFAULT_AMOUNT)
        );
        assertEq(diamond.getAssetUserStruct(asset, sender).ercEscrowed, 0);
    }

    function test_NoLeftoverLimitAsk2() public {
        fundLimitBidOpt(DEFAULT_PRICE - 1, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT + 1 wei, sender);

        assertEq(getBids().length, 1);
        assertEq(getAsks().length, 0);

        assertEq(diamond.getVaultUserStruct(vault, receiver).ethEscrowed, 0);
        assertEq(diamond.getAssetUserStruct(asset, receiver).ercEscrowed, DEFAULT_AMOUNT);
        assertEq(
            diamond.getVaultUserStruct(vault, sender).ethEscrowed,
            DEFAULT_PRICE.mul(DEFAULT_AMOUNT)
        );
        assertEq(diamond.getAssetUserStruct(asset, sender).ercEscrowed, 1 wei);
    }

    function test_NoLeftoverLimitShort2() public {
        fundLimitBidOpt(DEFAULT_PRICE - 1, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT + 1 wei, sender);

        assertEq(getBids().length, 1);
        assertEq(getShorts().length, 0);

        assertEq(diamond.getVaultUserStruct(vault, receiver).ethEscrowed, 0);
        assertEq(diamond.getAssetUserStruct(asset, receiver).ercEscrowed, DEFAULT_AMOUNT);
        assertEq(diamond.getVaultUserStruct(vault, sender).ethEscrowed, 0);
        assertEq(diamond.getAssetUserStruct(asset, sender).ercEscrowed, 0);
    }

    function test_NoLeftoverLimitBid2() public {
        fundLimitAskOpt(DEFAULT_PRICE + 1, DEFAULT_AMOUNT, sender);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT + 1 wei, receiver);

        assertEq(getBids().length, 0);
        assertEq(getAsks().length, 1);

        assertEq(diamond.getVaultUserStruct(vault, receiver).ethEscrowed, 0);
        assertEq(diamond.getAssetUserStruct(asset, receiver).ercEscrowed, DEFAULT_AMOUNT);
        assertEq(
            diamond.getVaultUserStruct(vault, sender).ethEscrowed,
            DEFAULT_PRICE.mul(DEFAULT_AMOUNT)
        );
        assertEq(diamond.getAssetUserStruct(asset, sender).ercEscrowed, 0);
    }
}
