// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U88} from "contracts/libraries/PRBMathHelper.sol";

// import {console} from "contracts/libraries/console.sol";
import {GasHelper} from "test-gas/GasHelper.sol";
import {Constants} from "contracts/libraries/Constants.sol";
import {MTypes} from "contracts/libraries/DataTypes.sol";

contract GasInactiveFixture is GasHelper {
    using U88 for uint88;

    function setUp() public virtual override {
        super.setUp();

        ob.depositUsd(receiver, DEFAULT_AMOUNT.mulU88(100 ether));
        ob.depositEth(receiver, 100 ether);
        ob.depositUsd(sender, DEFAULT_AMOUNT.mulU88(100 ether));
        ob.depositEth(sender, 100 ether);
    }
}

// @dev re-use by cancel or matched is the same cost
contract GasAskCreateCancelledTest is GasInactiveFixture {
    using U256 for uint256;

    function setUp() public override {
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        super.setUp();
        vm.startPrank(receiver);
        diamond.createAsk(
            asset, DEFAULT_PRICE, DEFAULT_AMOUNT, Constants.LIMIT_ORDER, orderHintArray
        ); // 100
        diamond.createAsk(
            asset, DEFAULT_PRICE, DEFAULT_AMOUNT, Constants.LIMIT_ORDER, orderHintArray
        ); // 101
        diamond.cancelAsk(asset, 100);
        vm.stopPrank();
    }

    function testGasCreateFromCancelled() public {
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.startPrank(receiver);
        startMeasuringGas("Order-CreateAsk-Reuse");
        diamond.createAsk(
            _asset, DEFAULT_PRICE, DEFAULT_AMOUNT, Constants.LIMIT_ORDER, orderHintArray
        ); // 100
        stopMeasuringGas();
    }
}

contract GasShortCreateCancelledTest is GasInactiveFixture {
    using U256 for uint256;

    function setUp() public override {
        uint16[] memory shortHintArray =
            createShortHintArrayGas({shortHint: DEFAULT_SHORT_HINT_ID});
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();

        super.setUp();
        vm.startPrank(receiver);
        diamond.createLimitShort(
            asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT,
            orderHintArray,
            shortHintArray,
            initialMargin
        ); // 100
        diamond.createLimitShort(
            asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT,
            orderHintArray,
            shortHintArray,
            initialMargin
        ); // 101
        diamond.cancelShort(asset, 100);
        vm.stopPrank();
    }

    function testGasCreateFromCancelled() public {
        uint16[] memory shortHintArray =
            createShortHintArrayGas({shortHint: DEFAULT_SHORT_HINT_ID});
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.startPrank(receiver);
        startMeasuringGas("Order-CreateShort-Reuse");
        diamond.createLimitShort(
            _asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT,
            orderHintArray,
            shortHintArray,
            initialMargin
        ); // 100
        stopMeasuringGas();
    }
}

contract GasBidCreateCancelledTest is GasInactiveFixture {
    using U256 for uint256;

    function setUp() public override {
        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: ONE});
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        super.setUp();
        vm.startPrank(receiver);
        diamond.createBid(
            asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT,
            Constants.LIMIT_ORDER,
            orderHintArray,
            shortHintArray
        ); // 100
        diamond.createBid(
            asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT,
            Constants.LIMIT_ORDER,
            orderHintArray,
            shortHintArray
        ); // 101
        diamond.cancelBid(asset, 100);
        vm.stopPrank();
    }

    function testGasCreateFromCancelled() public {
        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: ONE});
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.startPrank(receiver);
        startMeasuringGas("Order-CreateBid-Reuse");
        diamond.createBid(
            _asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT,
            Constants.LIMIT_ORDER,
            orderHintArray,
            shortHintArray
        ); // 100
        stopMeasuringGas();
    }
}
