// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U88} from "contracts/libraries/PRBMathHelper.sol";

// import {console} from "contracts/libraries/console.sol";
import {GasHelper} from "test-gas/GasHelper.sol";
import {Constants, Vault} from "contracts/libraries/Constants.sol";
import {STypes, MTypes, O} from "contracts/libraries/DataTypes.sol";

contract GasSellFixture is GasHelper {
    using U88 for uint88;

    function setUp() public virtual override {
        super.setUp();

        testFacet.nonZeroVaultSlot0(ob.vault());
        ob.depositUsd(receiver, DEFAULT_AMOUNT.mulU88(100 ether));
        ob.depositEth(receiver, DEFAULT_AMOUNT.mulU88(100 ether));
        ob.depositUsd(sender, DEFAULT_AMOUNT.mulU88(100 ether));
        ob.depositEth(sender, DEFAULT_AMOUNT.mulU88(100 ether));
    }

    function gasAskMatchBidTestAsserts(bool isFullyMatched) public {
        uint256 vault = Vault.CARBON;
        if (isFullyMatched) {
            assertEq(ob.getAsks().length, 0);
        } else {
            assertEq(ob.getAsks().length, 1);
        }

        assertEq(ob.getBids().length, 0);
        assertGt(
            diamond.getVaultUserStruct(vault, sender).ethEscrowed,
            DEFAULT_AMOUNT.mulU88(100 ether)
        );
        assertLt(
            diamond.getAssetUserStruct(asset, sender).ercEscrowed,
            DEFAULT_AMOUNT.mulU88(100 ether)
        );
        assertGt(
            diamond.getAssetUserStruct(asset, receiver).ercEscrowed,
            DEFAULT_AMOUNT.mulU88(100 ether)
        );
    }

    function gasShortMatchBidTestAsserts(bool isFullyMatched, uint256 startingShortId)
        public
    {
        uint256 vault = Vault.CARBON;
        if (isFullyMatched) {
            assertEq(ob.getShorts().length, 0);
        } else {
            assertEq(ob.getShorts().length, 1);
        }

        assertEq(ob.getBids().length, 0);
        assertLt(
            diamond.getVaultUserStruct(vault, sender).ethEscrowed,
            DEFAULT_AMOUNT.mulU88(100 ether)
        );
        assertGt(
            diamond.getAssetUserStruct(asset, receiver).ercEscrowed,
            DEFAULT_AMOUNT.mulU88(100 ether)
        );
        assertEq(diamond.getAssetStruct(asset).startingShortId, startingShortId);
    }
}

contract GasAskMatchSingleBidTest is GasSellFixture {
    using U256 for uint256;
    using U88 for uint88;

    function setUp() public override {
        super.setUp();
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
    }

    function testGasMatchAskToBid() public {
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("Order-MatchAskToSingleBid");
        diamond.createAsk(
            _asset, DEFAULT_PRICE, DEFAULT_AMOUNT, Constants.LIMIT_ORDER, orderHintArray
        );
        stopMeasuringGas();
        gasAskMatchBidTestAsserts({isFullyMatched: true});
    }

    function testGasMatchAskToBidWithLeftOverAsk() public {
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("Order-MatchAskToSingleBidWithLeftoverAsk");
        diamond.createAsk(
            _asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT * 2,
            Constants.LIMIT_ORDER,
            orderHintArray
        );
        stopMeasuringGas();
        gasAskMatchBidTestAsserts({isFullyMatched: false});
    }

    function testGasMatchAskToBidWithLeftOverBid() public {
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        uint256 vault = Vault.CARBON;
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("Order-MatchAskToBidWithLeftoverBid");
        diamond.createAsk(
            _asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT / 2,
            Constants.LIMIT_ORDER,
            orderHintArray
        );
        stopMeasuringGas();
        assertEq(ob.getBids().length, 1);
        assertEq(ob.getAsks().length, 0);
        assertGt(
            diamond.getVaultUserStruct(vault, sender).ethEscrowed,
            DEFAULT_AMOUNT.mulU88(100 ether)
        );
        assertLt(
            diamond.getAssetUserStruct(asset, sender).ercEscrowed,
            DEFAULT_AMOUNT.mulU88(100 ether)
        );
        assertGt(
            diamond.getAssetUserStruct(asset, receiver).ercEscrowed,
            DEFAULT_AMOUNT.mulU88(100 ether)
        );
    }

    function testGasMatchAskToBidWithShares() public {
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        skip(Constants.MIN_DURATION + 1);
        testFacet.setOracleTimeAndPrice(asset, DEFAULT_PRICE);
        vm.prank(sender);
        startMeasuringGas("Order-MatchAskToSingleBidWithShares");
        diamond.createAsk(
            _asset, DEFAULT_PRICE, DEFAULT_AMOUNT, Constants.LIMIT_ORDER, orderHintArray
        );
        stopMeasuringGas();
        gasAskMatchBidTestAsserts({isFullyMatched: true});
    }
}

contract GasShortMatchSingleBidTest is GasSellFixture {
    using U256 for uint256;
    using U88 for uint88;

    function setUp() public override {
        super.setUp();
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
    }

    function testGasMatchShortToBid() public {
        uint16[] memory shortHintArray = ob.setShortHintArray();
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("Order-MatchShortToBid");
        diamond.createLimitShort(
            _asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT,
            orderHintArray,
            shortHintArray,
            initialMargin
        );
        stopMeasuringGas();
        gasShortMatchBidTestAsserts({isFullyMatched: true, startingShortId: 1});
    }

    function testGasMatchShortToBidWithLeftOverShort() public {
        uint16[] memory shortHintArray = ob.setShortHintArray();
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("Order-MatchShortToBidWithLeftoverShort");
        diamond.createLimitShort(
            _asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT * 2,
            orderHintArray,
            shortHintArray,
            initialMargin
        );
        stopMeasuringGas();
        gasShortMatchBidTestAsserts({isFullyMatched: false, startingShortId: 101});
    }

    function testGasMatchShortToBidWithLeftOverBid() public {
        uint16[] memory shortHintArray = ob.setShortHintArray();
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        uint256 vault = Vault.CARBON;
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("Order-MatchShortToBidWithLeftoverBid");
        diamond.createLimitShort(
            _asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT / 2,
            orderHintArray,
            shortHintArray,
            initialMargin
        );
        stopMeasuringGas();
        assertEq(ob.getBids().length, 1);
        assertEq(ob.getShorts().length, 0);
        assertLt(
            diamond.getVaultUserStruct(vault, sender).ethEscrowed,
            DEFAULT_AMOUNT.mulU88(100 ether)
        );
        assertGt(
            diamond.getAssetUserStruct(asset, receiver).ercEscrowed,
            DEFAULT_AMOUNT.mulU88(100 ether)
        );
        assertEq(diamond.getAssetStruct(asset).startingShortId, 1);
    }

    function testGasMatchShortToBidWithShares() public {
        uint16[] memory shortHintArray = ob.setShortHintArray();
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        skip(Constants.MIN_DURATION + 1);
        testFacet.setOracleTimeAndPrice(asset, DEFAULT_PRICE);
        vm.prank(sender);
        startMeasuringGas("Order-MatchShortToBidWithShares");
        diamond.createLimitShort(
            _asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT,
            orderHintArray,
            shortHintArray,
            initialMargin
        );
        stopMeasuringGas();
        gasShortMatchBidTestAsserts({isFullyMatched: true, startingShortId: 1});
    }
}

contract GasAskMatchMultpleBidsTest is GasSellFixture {
    using U256 for uint256;

    function setUp() public override {
        super.setUp();
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
    }

    function testGasMatchAskToMultipleBids() public {
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("Order-MatchAskToMultipleBids");
        diamond.createAsk(
            _asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT * 4,
            Constants.LIMIT_ORDER,
            orderHintArray
        );
        stopMeasuringGas();
        gasAskMatchBidTestAsserts({isFullyMatched: true});
    }

    function testGasMatchAskToMultipleBidsWithShares() public {
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        skip(Constants.MIN_DURATION + 1);
        testFacet.setOracleTimeAndPrice(asset, DEFAULT_PRICE);
        vm.prank(sender);
        startMeasuringGas("Order-MatchAskToMultipleBidsWithShares");
        diamond.createAsk(
            _asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT * 4,
            Constants.LIMIT_ORDER,
            orderHintArray
        );
        stopMeasuringGas();
        gasAskMatchBidTestAsserts({isFullyMatched: true});
    }
}

contract GasShortMatchMultpleBidsTest is GasSellFixture {
    using U256 for uint256;

    function setUp() public override {
        super.setUp();
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
    }

    function testGasMatchShortToMultipleBids() public {
        uint16[] memory shortHintArray = ob.setShortHintArray();
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("Order-MatchShortToMultipleBids");
        diamond.createLimitShort(
            _asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT * 4,
            orderHintArray,
            shortHintArray,
            initialMargin
        );
        stopMeasuringGas();
        gasShortMatchBidTestAsserts({isFullyMatched: true, startingShortId: 1});
    }

    function testGasMatchShortToMultipleBidsWithShares() public {
        uint16[] memory shortHintArray = ob.setShortHintArray();
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        skip(Constants.MIN_DURATION + 1);
        testFacet.setOracleTimeAndPrice(asset, DEFAULT_PRICE);
        vm.prank(sender);
        startMeasuringGas("Order-MatchShortToMultipleBidsWithShares");
        diamond.createLimitShort(
            _asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT * 4,
            orderHintArray,
            shortHintArray,
            initialMargin
        );
        stopMeasuringGas();
        gasShortMatchBidTestAsserts({isFullyMatched: true, startingShortId: 1});
    }
}

contract GasAskMatchMultpleBidsTestx100 is GasSellFixture {
    using U256 for uint256;

    function setUp() public override {
        super.setUp();
        uint128 numBids = 100;
        for (uint256 i = 0; i < numBids; i++) {
            ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        }
    }

    function testGasMatchAskToMultipleBidsx100() public {
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("Order-MatchAskToMultipleBidsx100");
        diamond.createAsk(
            _asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT * 100,
            Constants.LIMIT_ORDER,
            orderHintArray
        );
        stopMeasuringGas();
        gasAskMatchBidTestAsserts({isFullyMatched: true});
    }

    function testGasMatchAskToMultipleBidsWithSharesx100() public {
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        skip(Constants.MIN_DURATION + 1);
        testFacet.setOracleTimeAndPrice(asset, DEFAULT_PRICE);
        vm.prank(sender);
        startMeasuringGas("Order-MatchAskToMultipleBidsWithSharesx100");
        diamond.createAsk(
            _asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT * 100,
            Constants.LIMIT_ORDER,
            orderHintArray
        );
        stopMeasuringGas();
        gasAskMatchBidTestAsserts({isFullyMatched: true});
    }
}

contract GasShortMatchMultpleBidsTestx100 is GasSellFixture {
    using U256 for uint256;

    function setUp() public override {
        super.setUp();
        uint128 numBids = 100;
        for (uint256 i = 0; i < numBids; i++) {
            ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        }
    }

    function testGasMatchShortToMultipleBidsx100() public {
        uint16[] memory shortHintArray = ob.setShortHintArray();
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.startPrank(sender);
        startMeasuringGas("Order-MatchShortToMultipleBidsx100");
        diamond.createLimitShort(
            _asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT * 100,
            orderHintArray,
            shortHintArray,
            initialMargin
        );
        stopMeasuringGas();
        gasShortMatchBidTestAsserts({isFullyMatched: true, startingShortId: 1});
    }

    function testGasMatchShortToMultipleBidsWithSharesx100() public {
        uint16[] memory shortHintArray = ob.setShortHintArray();
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        skip(Constants.MIN_DURATION + 1);
        testFacet.setOracleTimeAndPrice(asset, DEFAULT_PRICE);
        vm.startPrank(sender);
        startMeasuringGas("Order-MatchShortToMultipleBidsWithSharesx100");
        diamond.createLimitShort(
            _asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT * 100,
            orderHintArray,
            shortHintArray,
            initialMargin
        );
        stopMeasuringGas();
        gasShortMatchBidTestAsserts({isFullyMatched: true, startingShortId: 1});
    }
}

contract GasShortMatchSingleBudUpdateOracleTest is GasSellFixture {
    using U256 for uint256;

    function setUp() public override {
        super.setUp();
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
    }

    function testGasMatchShortToBidUpdatingOracleViaThreshold() public {
        uint16[] memory shortHintArray = ob.setShortHintArray();
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        //@dev set oracleprice to very low so short needs to update oracle upon match
        testFacet.setOracleTimeAndPrice(asset, 0.0002 ether);
        vm.prank(sender);
        startMeasuringGas("Order-MatchShortToBidUpdatingOracleViaThreshold");
        diamond.createLimitShort(
            _asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT,
            orderHintArray,
            shortHintArray,
            initialMargin
        );
        stopMeasuringGas();
        gasShortMatchBidTestAsserts({isFullyMatched: true, startingShortId: 1});
    }
}
