// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {IDiamond} from "interfaces/IDiamond.sol";

import {U256, U88, U80} from "contracts/libraries/PRBMathHelper.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {OBFixture} from "test/utils/OBFixture.sol";
import {Constants} from "contracts/libraries/Constants.sol";
import {LibOrders} from "contracts/libraries/LibOrders.sol";

contract RevertOrdersTest is OBFixture {
    using U256 for uint256;
    using U88 for uint88;
    using U80 for uint80;

    function setUp() public override {
        super.setUp();
    }

    function test_RevertIf_NotContract() public {
        vm.expectRevert(Errors.NotDiamond.selector);
        vm.prank(sender);
        diamond.createForcedBid(sender, asset, 1 ether, 2 ether, shortHintArrayStorage);

        vm.expectRevert(Errors.NotDiamond.selector);
        IDiamond(payable(address(_diamond))).createForcedBid(
            sender, asset, 1 ether, 2 ether, shortHintArrayStorage
        );
    }

    function test_RevertIf_NoDeposit_Short() public {
        vm.prank(noDeposit);
        vm.expectRevert(Errors.InsufficientETHEscrowed.selector);
        diamond.createLimitShort(
            asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT,
            badOrderHintArray,
            shortHintArrayStorage,
            initialMargin
        );
    }

    function test_RevertIf_NoDeposit_Ask() public {
        vm.prank(noDeposit);
        vm.expectRevert(Errors.InsufficientERCEscrowed.selector);
        createLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT);
    }

    function test_RevertIf_NoDeposit_Bid() public {
        vm.expectRevert(Errors.InsufficientETHEscrowed.selector);
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
    }

    function test_RevertIf_NotEnoughDeposit_Short() public {
        uint88 minAskEth = DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT).mulU88(
            LibOrders.convertCR(initialMargin)
        );

        depositEthAndPrank(sender, minAskEth - 1);
        vm.expectRevert(Errors.InsufficientETHEscrowed.selector);
        diamond.createLimitShort(
            asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT,
            badOrderHintArray,
            shortHintArrayStorage,
            initialMargin
        );
    }

    function test_RevertIf_NotEnoughDeposit_Ask() public {
        uint88 minAskEth = DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT);

        depositEthAndPrank(sender, minAskEth - 1);
        vm.expectRevert(Errors.InsufficientERCEscrowed.selector);
        createLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT);
    }

    function test_RevertIf_NotEnoughDeposit_MarketAsk() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        vm.expectRevert(Errors.InsufficientERCEscrowed.selector);
        diamond.createAsk(
            asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT,
            Constants.MARKET_ORDER,
            badOrderHintArray
        );
    }

    function test_RevertIf_NotEnoughDepositBid() public {
        uint88 minBidEth = DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT);

        depositEthAndPrank(sender, minBidEth - 1);
        vm.expectRevert(Errors.InsufficientETHEscrowed.selector);
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
    }

    function test_RevertIf_NotEnoughDepositMarketBid() public {
        fundLimitShortOpt(1 ether, DEFAULT_AMOUNT.mulU88(2 ether), receiver);

        vm.expectRevert(Errors.InsufficientETHEscrowed.selector);
        diamond.createBid(
            asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT,
            Constants.MARKET_ORDER,
            badOrderHintArray,
            shortHintArrayStorage
        );
    }

    //@dev using diamond.createLimitShort instead of helper createLimitShort to avoid clashing with the built-in function call diamond.getShortIdAtOracle(asset)
    function test_RevertIf_PriceOrQuantity0() public {
        vm.expectRevert(Errors.OrderUnderMinimumSize.selector);
        diamond.createLimitShort(
            asset, 0, 0, badOrderHintArray, shortHintArrayStorage, initialMargin
        );

        vm.expectRevert(Errors.OrderUnderMinimumSize.selector);
        diamond.createLimitShort(
            asset, 1, 0, badOrderHintArray, shortHintArrayStorage, initialMargin
        );

        vm.expectRevert(Errors.OrderUnderMinimumSize.selector);
        diamond.createLimitShort(
            asset, 0, 1, badOrderHintArray, shortHintArrayStorage, initialMargin
        );

        vm.expectRevert(Errors.OrderUnderMinimumSize.selector);
        createLimitAsk(0, 0);

        vm.expectRevert(Errors.OrderUnderMinimumSize.selector);
        createLimitAsk(1, 0);

        vm.expectRevert(Errors.OrderUnderMinimumSize.selector);
        createLimitAsk(0, 1);
    }

    function test_RevertIf_PriceOrQuantity0_Bid() public {
        vm.expectRevert(Errors.OrderUnderMinimumSize.selector);
        diamond.createBid(
            asset, 0, 0, Constants.LIMIT_ORDER, badOrderHintArray, shortHintArrayStorage
        );
    }

    function test_RevertIf_PriceOrQuantityInvalid_MarketAsk() public {
        depositUsd(sender, 1 ether);

        vm.startPrank(sender);
        vm.expectRevert(Errors.OrderUnderMinimumSize.selector);
        diamond.createAsk(
            asset, DEFAULT_PRICE, 0, Constants.MARKET_ORDER, badOrderHintArray
        );

        vm.expectRevert(Errors.OrderUnderMinimumSize.selector);
        diamond.createAsk(
            asset, 0, DEFAULT_AMOUNT, Constants.MARKET_ORDER, badOrderHintArray
        );
    }

    function test_RevertIf_PriceOrQuantityInvalid_MarketBid() public {
        fundLimitShortOpt(1 ether, DEFAULT_AMOUNT.mulU88(2 ether), receiver);

        vm.expectRevert(Errors.OrderUnderMinimumSize.selector);
        diamond.createBid(
            asset,
            DEFAULT_PRICE,
            0,
            Constants.MARKET_ORDER,
            badOrderHintArray,
            shortHintArrayStorage
        );

        vm.expectRevert(Errors.OrderUnderMinimumSize.selector);
        diamond.createBid(
            asset,
            0,
            DEFAULT_AMOUNT,
            Constants.MARKET_ORDER,
            badOrderHintArray,
            shortHintArrayStorage
        );
    }

    function test_RevertIf_UnderMinSize_Ask() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(0.4 ether), sender);
        depositUsdAndPrank(receiver, 1 ether);
        vm.expectRevert(Errors.OrderUnderMinimumSize.selector);
        diamond.createAsk(
            asset,
            DEFAULT_PRICE,
            0.39999999 ether,
            Constants.MARKET_ORDER,
            badOrderHintArray
        );
    }

    function test_RevertIf_UnderMinSize_Bid() public {
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(0.4 ether), sender);
        depositEthAndPrank(receiver, 1 ether);
        vm.expectRevert(Errors.OrderUnderMinimumSize.selector);
        diamond.createBid(
            asset,
            DEFAULT_PRICE,
            0.39999999 ether,
            Constants.MARKET_ORDER,
            badOrderHintArray,
            shortHintArrayStorage
        );
    }
}
