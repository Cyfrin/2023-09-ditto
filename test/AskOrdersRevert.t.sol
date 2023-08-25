// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U88} from "contracts/libraries/PRBMathHelper.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {OBFixture} from "test/utils/OBFixture.sol";
import {Constants} from "contracts/libraries/Constants.sol";

contract AskRevertTest is OBFixture {
    using U88 for uint88;

    function setUp() public override {
        super.setUp();
    }

    function testCannotCreateLimitShortNoDeposit() public {
        vm.expectRevert(Errors.InsufficientETHEscrowed.selector);
        diamond.createLimitShort(
            asset,
            1 ether,
            DEFAULT_AMOUNT.mulU88(2 ether),
            badOrderHintArray,
            shortHintArrayStorage,
            initialMargin
        );
    }

    function testCannotCreateLimitAskNoDeposit() public {
        vm.expectRevert(Errors.InsufficientERCEscrowed.selector);
        createLimitAsk(1 ether, 2 ether);
    }

    function testCannotCreateLimitShortWithoutEnoughDeposit() public {
        depositEthAndPrank(sender, 4 ether);
        vm.expectRevert(Errors.InsufficientETHEscrowed.selector);
        diamond.createLimitShort(
            asset,
            1 ether,
            DEFAULT_AMOUNT,
            badOrderHintArray,
            shortHintArrayStorage,
            initialMargin
        );

        depositEthAndPrank(sender, 1 ether - 1 wei);
        vm.expectRevert(Errors.InsufficientETHEscrowed.selector);
        diamond.createLimitShort(
            asset,
            1 ether,
            DEFAULT_AMOUNT,
            badOrderHintArray,
            shortHintArrayStorage,
            initialMargin
        );
    }

    function testCannotCreateLimitAskWithoutEnoughDeposit() public {
        depositEthAndPrank(sender, 1 ether);
        vm.expectRevert(Errors.InsufficientERCEscrowed.selector);
        createLimitAsk(1 ether + 1 wei, 1 ether);
    }

    function testCannotCreateMarketAskWithoutEnoughDeposit() public {
        vm.expectRevert(Errors.InsufficientERCEscrowed.selector);
        createLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT * 2);
    }

    function testCannotCreateLimitShortWithPriceOrQuantity0() public {
        vm.expectRevert(Errors.OrderUnderMinimumSize.selector);
        diamond.createLimitShort(
            asset, 0, 0, badOrderHintArray, shortHintArrayStorage, initialMargin
        );
    }

    function testCannotCreateLimitAskWithPriceOrQuantity0() public {
        vm.expectRevert(Errors.OrderUnderMinimumSize.selector);
        createLimitAsk(0, 0);
    }

    function testCannotCreateMarketAskWithPriceOrQuantity0() public {
        vm.startPrank(sender);
        vm.expectRevert(Errors.OrderUnderMinimumSize.selector);
        diamond.createAsk(
            asset, DEFAULT_PRICE, 0, Constants.MARKET_ORDER, badOrderHintArray
        );

        vm.expectRevert(Errors.OrderUnderMinimumSize.selector);
        diamond.createAsk(asset, 0, 1 ether, Constants.MARKET_ORDER, badOrderHintArray);
    }

    function testCannotSellUnderMinimumSize() public {
        vm.expectRevert(Errors.OrderUnderMinimumSize.selector);
        diamond.createAsk(
            asset, DEFAULT_PRICE, 0.3999 ether, Constants.MARKET_ORDER, badOrderHintArray
        );
    }
}
