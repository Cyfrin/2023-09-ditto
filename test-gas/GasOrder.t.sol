// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U88} from "contracts/libraries/PRBMathHelper.sol";

import {GasHelper} from "test-gas/GasHelper.sol";
import {Constants} from "contracts/libraries/Constants.sol";
import {MTypes, O} from "contracts/libraries/DataTypes.sol";

// import {console} from "contracts/libraries/console.sol";

contract GasOrderFixture is GasHelper {
    using U88 for uint88;

    function setUp() public virtual override {
        super.setUp();

        ob.depositUsd(receiver, DEFAULT_AMOUNT.mulU88(100 ether));
        ob.depositEth(receiver, DEFAULT_AMOUNT.mulU88(100 ether));
        ob.depositUsd(sender, DEFAULT_AMOUNT.mulU88(100 ether));
        ob.depositEth(sender, DEFAULT_AMOUNT.mulU88(100 ether));
    }
}

// canceling from the beginning or end saves 4800 gas
contract GasCancelAskTest is GasOrderFixture {
    function setUp() public override {
        super.setUp();
        ob.fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // 100
        ob.fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // 101
        ob.fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // 102
    }

    function testGasCancelAsk() public {
        address _asset = asset;
        vm.prank(receiver);
        startMeasuringGas("Order-CancelAsk");
        diamond.cancelAsk(_asset, 101);
        stopMeasuringGas();
        assertEq(ob.getAsks().length, 2);
    }
}

contract GasCancelBidTest is GasOrderFixture {
    function setUp() public override {
        super.setUp();
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // 100
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // 101
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // 102
    }

    function testGasCancelBid() public {
        address _asset = asset;
        vm.prank(receiver);
        startMeasuringGas("Order-CancelBid");
        diamond.cancelBid(_asset, 101);
        stopMeasuringGas();
        assertEq(ob.getBids().length, 2);
    }
}

contract GasCancelShortTest is GasOrderFixture {
    function setUp() public override {
        super.setUp();
        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // 100
        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // 101
        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // 102
        // Partial match with 100
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT / 2, sender);
    }

    function testGasCancelShort() public {
        address _asset = asset;
        vm.prank(receiver);
        startMeasuringGas("Order-CancelShort");
        diamond.cancelShort(_asset, 102);
        stopMeasuringGas();
        assertEq(ob.getShorts().length, 2);
    }

    function testGasCancelShortAfterPartialFill() public {
        address _asset = asset;
        vm.prank(receiver);
        startMeasuringGas("Order-CancelShort-RecordExists");
        diamond.cancelShort(_asset, 100);
        stopMeasuringGas();
        assertEq(ob.getShorts().length, 2);
    }
}

contract GasCancelShortTest2 is GasOrderFixture {
    function setUp() public override {
        super.setUp();
        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // 100
        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // 101
        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // 102
        // Partial match with 100
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT / 2, sender);
        // Exit shortRecord created by partial match with shortOrder 100
        ob.fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT / 2, sender);
        ob.exitShort(
            Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT / 2, DEFAULT_PRICE, receiver
        );
    }

    function testGasCancelShortAfterPartialFillCancelled() public {
        address _asset = asset;
        vm.prank(receiver);
        startMeasuringGas("Order-CancelShort-RecordExistsButCancelled");
        diamond.cancelShort(_asset, 100);
        stopMeasuringGas();
        assertEq(ob.getShorts().length, 2);
    }
}

contract GasCreateOrderTest is GasOrderFixture {
    using U256 for uint256;

    function setUp() public override {
        super.setUp();
    }

    function testGasCreateBid() public {
        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: ONE});
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(receiver);
        startMeasuringGas("Order-CreateBid-New");
        diamond.createBid(
            _asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT,
            Constants.LIMIT_ORDER,
            orderHintArray,
            shortHintArray
        );
        stopMeasuringGas();
        assertEq(ob.getBids().length, 1);
    }

    function testGasCreateAsk() public {
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(receiver);
        startMeasuringGas("Order-CreateAsk-New");
        diamond.createAsk(
            _asset, DEFAULT_PRICE, DEFAULT_AMOUNT, Constants.LIMIT_ORDER, orderHintArray
        );
        stopMeasuringGas();
        assertEq(ob.getAsks().length, 1);
    }

    function testGasCreateShort() public {
        uint16[] memory shortHintArray =
            createShortHintArrayGas({shortHint: DEFAULT_SHORT_HINT_ID});
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(receiver);
        startMeasuringGas("Order-CreateShort-New");
        diamond.createLimitShort(
            _asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT,
            orderHintArray,
            shortHintArray,
            initialMargin
        );
        stopMeasuringGas();
        assertEq(ob.getShorts().length, 1);
    }
}

contract GasPlaceBidOnObWithHintTest is GasOrderFixture {
    function setUp() public virtual override {
        super.setUp();
        ob.fundLimitBidOpt(DEFAULT_PRICE + 0, DEFAULT_AMOUNT, receiver); // 100
        ob.fundLimitBidOpt(DEFAULT_PRICE + 2, DEFAULT_AMOUNT, receiver); // 101
        ob.fundLimitBidOpt(DEFAULT_PRICE + 3, DEFAULT_AMOUNT, receiver); // 102
        ob.fundLimitBidOpt(DEFAULT_PRICE + 4, DEFAULT_AMOUNT, receiver); // 103

        // re-use id
        ob.fundLimitBidOpt(DEFAULT_PRICE + 5, DEFAULT_AMOUNT, receiver); // 104
        vm.prank(receiver);
        diamond.cancelBid(asset, 104);
    }

    function testGasCreateAskOrderHintOffForward1() public {
        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: ONE});
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(receiver);
        startMeasuringGas("Order-CreateBid-Reuse-HintOffPlus1");
        diamond.createBid(
            _asset,
            DEFAULT_PRICE + 3,
            DEFAULT_AMOUNT,
            Constants.LIMIT_ORDER,
            orderHintArray,
            shortHintArray
        ); // supposed to be 102
        stopMeasuringGas();
        assertEq(ob.getBids().length, 5);
    }

    function testGasCreateAskOrderHintOffBack1() public {
        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: ONE});
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(receiver);
        startMeasuringGas("Order-CreateBid-Reuse-HintOffMinus1");
        diamond.createBid(
            _asset,
            DEFAULT_PRICE + 2,
            DEFAULT_AMOUNT,
            Constants.LIMIT_ORDER,
            orderHintArray,
            shortHintArray
        ); // supposed to be 101
        stopMeasuringGas();
        assertEq(ob.getBids().length, 5);
    }

    //@dev testGasCreateBidIncomingIsBestPrice should be < testGasCreateBidIncomingIsNotBestPrice
    function testGasCreateBidIncomingIsBestPrice() public {
        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: ONE});
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(receiver);
        startMeasuringGas("Order-CreateBid-IgnoreHintEvaulation");
        diamond.createBid(
            _asset,
            DEFAULT_PRICE + 10,
            DEFAULT_AMOUNT,
            Constants.LIMIT_ORDER,
            orderHintArray,
            shortHintArray
        );
        stopMeasuringGas();
        assertEq(ob.getBids().length, 5);
    }

    function testGasCreateBidIncomingIsNotBestPrice() public {
        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: ONE});
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(receiver);
        startMeasuringGas("Order-CreateBid-UseHintEvaulation");
        diamond.createBid(
            _asset,
            DEFAULT_PRICE - 1,
            DEFAULT_AMOUNT,
            Constants.LIMIT_ORDER,
            orderHintArray,
            shortHintArray
        );
        stopMeasuringGas();
        assertEq(ob.getBids().length, 5);
    }
}

contract GasPlaceAskOnObWithHintTest is GasOrderFixture {
    function setUp() public virtual override {
        super.setUp();
        ob.fundLimitAskOpt(DEFAULT_PRICE + 4, DEFAULT_AMOUNT, sender); // 100
        ob.fundLimitAskOpt(DEFAULT_PRICE + 3, DEFAULT_AMOUNT, sender); // 101
        ob.fundLimitAskOpt(DEFAULT_PRICE + 2, DEFAULT_AMOUNT, sender); // 102
        ob.fundLimitAskOpt(DEFAULT_PRICE + 1, DEFAULT_AMOUNT, sender); // 103

        // re-use id
        ob.fundLimitAskOpt(DEFAULT_PRICE + 1, DEFAULT_AMOUNT, sender); // 104
        vm.prank(sender);
        diamond.cancelAsk(asset, 104);
    }

    //@dev testGasCreateAskIncomingIsBestPrice should be < testGasCreateAskIncomingIsNotBestPrice
    function testGasCreateAskIncomingIsBestPrice() public {
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("Order-CreateAsk-IgnoreHintEvaulation");
        diamond.createAsk(
            _asset, DEFAULT_PRICE, DEFAULT_AMOUNT, Constants.LIMIT_ORDER, orderHintArray
        );
        stopMeasuringGas();
        assertEq(ob.getAsks().length, 5);
    }

    function testGasCreateAskIncomingIsNotBestPrice() public {
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("Order-CreateAsk-UseHintEvaulation");
        diamond.createAsk(
            _asset,
            DEFAULT_PRICE + 10,
            DEFAULT_AMOUNT,
            Constants.LIMIT_ORDER,
            orderHintArray
        );
        stopMeasuringGas();
        assertEq(ob.getAsks().length, 5);
    }
}

contract GasPlaceShortOnObWithHintTest is GasOrderFixture {
    function setUp() public virtual override {
        super.setUp();
        ob.fundLimitShortOpt(DEFAULT_PRICE + 4, DEFAULT_AMOUNT, sender); // 100
        ob.fundLimitShortOpt(DEFAULT_PRICE + 3, DEFAULT_AMOUNT, sender); // 101
        ob.fundLimitShortOpt(DEFAULT_PRICE + 2, DEFAULT_AMOUNT, sender); // 102
        ob.fundLimitShortOpt(DEFAULT_PRICE + 1, DEFAULT_AMOUNT, sender); // 103

        // re-use id
        ob.fundLimitShortOpt(DEFAULT_PRICE + 1, DEFAULT_AMOUNT, sender); // 104
        vm.prank(sender);
        diamond.cancelShort(asset, 104);
    }

    //@dev testGasCreateShortIncomingIsBestPrice should be < testGasCreateShortIncomingIsNotBestPrice
    function testGasCreateShortIncomingIsBestPrice() public {
        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: ONE});
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("Order-CreateShort-IgnoreHintEvaulation");
        diamond.createLimitShort(
            _asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT,
            orderHintArray,
            shortHintArray,
            initialMargin
        );
        stopMeasuringGas();
        assertEq(ob.getShorts().length, 5);
    }

    function testGasCreateShortIncomingIsNotBestPrice() public {
        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: ONE});
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("Order-CreateShort-UseHintEvaulation");
        diamond.createLimitShort(
            _asset,
            DEFAULT_PRICE + 10,
            DEFAULT_AMOUNT,
            orderHintArray,
            shortHintArray,
            initialMargin
        );
        stopMeasuringGas();
        assertEq(ob.getShorts().length, 5);
    }
}

contract GasCancelBidFarFromHead is GasOrderFixture {
    using U256 for uint256;

    function setUp() public virtual override {
        super.setUp();

        vm.prank(owner);
        testFacet.setOrderIdT(asset, 64900);
        for (uint256 i; i < 100; i++) {
            ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        }
        assertEq(diamond.getAssetNormalizedStruct(asset).orderId, 65000);
        assertEq(ob.getBids().length, 100);
    }

    function testGasCancelBidFarFromHead() public {
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("Order-GasCancelBidFarFromHead");
        diamond.cancelOrderFarFromOracle({
            asset: _asset,
            orderType: O.LimitBid,
            lastOrderId: 64999,
            numOrdersToCancel: 1
        });
        stopMeasuringGas();
        assertEq(diamond.getAssetNormalizedStruct(asset).orderId, 65000);
        assertEq(ob.getBids().length, 99);
    }

    function testGasCancelBidFarFromHeadDAO100X() public {
        address _asset = asset;
        vm.prank(owner);
        startMeasuringGas("Order-GasCancelBidFarFromHead-DAO-100X");
        diamond.cancelOrderFarFromOracle({
            asset: _asset,
            orderType: O.LimitBid,
            lastOrderId: 64999,
            numOrdersToCancel: 100
        });
        stopMeasuringGas();
        assertEq(diamond.getAssetNormalizedStruct(asset).orderId, 65000);
        assertEq(ob.getBids().length, 0);
    }
}

contract GasCancelAskFarFromHead is GasOrderFixture {
    using U256 for uint256;

    function setUp() public virtual override {
        super.setUp();

        vm.prank(owner);
        testFacet.setOrderIdT(asset, 64900);
        for (uint256 i; i < 100; i++) {
            ob.fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        }
        assertEq(diamond.getAssetNormalizedStruct(asset).orderId, 65000);
        assertEq(ob.getAsks().length, 100);
    }

    function testGasCancelAskFarFromHead() public {
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("Order-GasCancelAskFarFromHead");
        diamond.cancelOrderFarFromOracle({
            asset: _asset,
            orderType: O.LimitAsk,
            lastOrderId: 64999,
            numOrdersToCancel: 100
        });
        stopMeasuringGas();
        assertEq(diamond.getAssetNormalizedStruct(asset).orderId, 65000);
        assertEq(ob.getAsks().length, 99);
    }

    function testGasCancelAskFarFromHeadDAO100X() public {
        address _asset = asset;
        vm.prank(owner);
        startMeasuringGas("Order-GasCancelAskFarFromHead-DAO-100X");
        diamond.cancelOrderFarFromOracle({
            asset: _asset,
            orderType: O.LimitAsk,
            lastOrderId: 64999,
            numOrdersToCancel: 100
        });
        stopMeasuringGas();
        assertEq(diamond.getAssetNormalizedStruct(asset).orderId, 65000);
        assertEq(ob.getAsks().length, 0);
    }
}

contract GasCancelShortFarFromHead is GasOrderFixture {
    using U256 for uint256;

    function setUp() public virtual override {
        super.setUp();

        vm.prank(owner);
        testFacet.setOrderIdT(asset, 64900);
        for (uint256 i; i < 100; i++) {
            ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        }
        assertEq(diamond.getAssetNormalizedStruct(asset).orderId, 65000);
        assertEq(ob.getShorts().length, 100);
    }

    function testGasCancelShortFarFromHead() public {
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("Order-GasCancelShortFarFromHead");
        diamond.cancelOrderFarFromOracle({
            asset: _asset,
            orderType: O.LimitShort,
            lastOrderId: 64999,
            numOrdersToCancel: 100
        });
        stopMeasuringGas();
        assertEq(diamond.getAssetNormalizedStruct(asset).orderId, 65000);
        assertEq(ob.getShorts().length, 99);
    }

    function testGasCancelShortFarFromHeadDAO100X() public {
        address _asset = asset;
        vm.prank(owner);
        startMeasuringGas("Order-GasCancelShortFarFromHead-DAO-100X");
        diamond.cancelOrderFarFromOracle({
            asset: _asset,
            orderType: O.LimitShort,
            lastOrderId: 64999,
            numOrdersToCancel: 100
        });
        stopMeasuringGas();
        assertEq(diamond.getAssetNormalizedStruct(asset).orderId, 65000);
        assertEq(ob.getShorts().length, 0);
    }
}
