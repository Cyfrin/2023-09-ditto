// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U88} from "contracts/libraries/PRBMathHelper.sol";

// import {console} from "contracts/libraries/console.sol";
import {GasHelper} from "test-gas/GasHelper.sol";
import {Constants, Vault} from "contracts/libraries/Constants.sol";
import {STypes, MTypes} from "contracts/libraries/DataTypes.sol";

contract GasBidFixture is GasHelper {
    using U88 for uint88;

    function setUp() public virtual override {
        super.setUp();

        testFacet.nonZeroVaultSlot0(ob.vault());
        ob.depositUsd(receiver, DEFAULT_AMOUNT.mulU88(100 ether));
        ob.depositEth(receiver, DEFAULT_AMOUNT.mulU88(100 ether));
        ob.depositUsd(sender, DEFAULT_AMOUNT.mulU88(100 ether));
        ob.depositEth(sender, DEFAULT_AMOUNT.mulU88(100 ether));
    }

    function gasBidMatchAskTestAsserts(bool isFullyMatched) public {
        uint256 vault = Vault.CARBON;
        if (isFullyMatched) {
            assertEq(ob.getBids().length, 0);
        } else {
            assertEq(ob.getBids().length, 1);
        }

        assertEq(ob.getAsks().length, 0);
        assertGt(
            diamond.getVaultUserStruct(vault, sender).ethEscrowed,
            DEFAULT_AMOUNT.mulU88(100 ether)
        );
        assertLt(
            diamond.getVaultUserStruct(vault, receiver).ethEscrowed,
            DEFAULT_AMOUNT.mulU88(100 ether)
        );
        assertGt(
            diamond.getAssetUserStruct(asset, receiver).ercEscrowed,
            DEFAULT_AMOUNT.mulU88(100 ether)
        );
    }

    function gasBidMatchShortTestAsserts(
        bool isFullyMatched,
        uint256 shortLen,
        uint256 startingShortId
    ) public {
        uint256 vault = Vault.CARBON;
        if (isFullyMatched) {
            assertEq(ob.getBids().length, 0);
        } else {
            assertEq(ob.getBids().length, 1);
        }

        assertEq(ob.getShorts().length, shortLen);
        assertLt(
            diamond.getVaultUserStruct(vault, receiver).ethEscrowed,
            DEFAULT_AMOUNT.mulU88(100 ether)
        );
        assertGt(
            diamond.getAssetUserStruct(asset, receiver).ercEscrowed,
            DEFAULT_AMOUNT.mulU88(100 ether)
        );
        assertEq(diamond.getAssetStruct(asset).startingShortId, startingShortId);
    }
}

contract GasBidMatchSingleAskTest is GasBidFixture {
    using U256 for uint256;

    function setUp() public override {
        super.setUp();
        ob.fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
    }

    function testGasMatchBidToAsk() public {
        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: ONE});
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(receiver);
        startMeasuringGas("Order-MatchBidToSingleAsk");
        diamond.createBid(
            _asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT,
            Constants.LIMIT_ORDER,
            orderHintArray,
            shortHintArray
        );
        stopMeasuringGas();
        gasBidMatchAskTestAsserts({isFullyMatched: true});
    }

    function testGasMatchBidToAskWithLeftOver() public {
        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: ZERO});
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(receiver);
        startMeasuringGas("Order-MatchBidToSingleAskWithLeftover");
        diamond.createBid(
            _asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT * 2,
            Constants.LIMIT_ORDER,
            orderHintArray,
            shortHintArray
        );
        stopMeasuringGas();
        gasBidMatchAskTestAsserts({isFullyMatched: false});
    }
}

contract GasBidMatchMultpleAskTest is GasBidFixture {
    using U256 for uint256;

    function setUp() public override {
        super.setUp();
        ob.fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        ob.fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        ob.fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        ob.fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
    }

    function testGasMatchBidToMultipleAsks() public {
        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: ZERO});
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(receiver);
        startMeasuringGas("Order-MatchBidToMultipleAsks");
        diamond.createBid(
            _asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT * 4,
            Constants.LIMIT_ORDER,
            orderHintArray,
            shortHintArray
        );
        stopMeasuringGas();
        gasBidMatchAskTestAsserts({isFullyMatched: true});
    }
}

contract GasBidMatchSingleShortTest is GasBidFixture {
    using U256 for uint256;

    function setUp() public override {
        super.setUp();
        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
    }

    function testGasMatchBidToShort() public {
        uint16[] memory shortHintArray = ob.setShortHintArray();
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(receiver);
        startMeasuringGas("Order-MatchBidToSingleShort");
        diamond.createBid(
            _asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT,
            Constants.LIMIT_ORDER,
            orderHintArray,
            shortHintArray
        );
        stopMeasuringGas();
        gasBidMatchShortTestAsserts({
            isFullyMatched: true,
            shortLen: 0,
            startingShortId: 1
        });
    }

    function testGasMatchBidToShortWithLeftOver() public {
        uint16[] memory shortHintArray = ob.setShortHintArray();
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(receiver);
        startMeasuringGas("Order-MatchBidToSingleShortWithLeftover");
        diamond.createBid(
            _asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT * 2,
            Constants.LIMIT_ORDER,
            orderHintArray,
            shortHintArray
        );
        stopMeasuringGas();
        gasBidMatchShortTestAsserts({
            isFullyMatched: false,
            shortLen: 0,
            startingShortId: 1
        });
    }

    function testGasMatchBidToShortWithShares() public {
        uint16[] memory shortHintArray = ob.setShortHintArray();
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        skip(Constants.MIN_DURATION + 1);
        testFacet.setOracleTimeAndPrice(asset, DEFAULT_PRICE);
        vm.prank(receiver);
        startMeasuringGas("Order-MatchBidToSingleShortWithShares");
        diamond.createBid(
            _asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT,
            Constants.LIMIT_ORDER,
            orderHintArray,
            shortHintArray
        );
        stopMeasuringGas();
        gasBidMatchShortTestAsserts({
            isFullyMatched: true,
            shortLen: 0,
            startingShortId: 1
        });
    }
}

contract GasBidMatchSingleShortUpdateOracleTest is GasBidFixture {
    using U256 for uint256;

    function setUp() public override {
        super.setUp();
        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        ob.fundLimitShortOpt(DEFAULT_PRICE + 1 wei, DEFAULT_AMOUNT, sender);
        ob.skipTimeAndSetEth({skipTime: Constants.MIN_DURATION + 1, ethPrice: 4000 ether});
        //@dev set oracleprice to very low so bid needs to update oracle upon match
        testFacet.setOracleTimeAndPrice(asset, 0.0002 ether);
    }

    function testGasMatchBidToShortUpdatingOracleViaThreshold() public {
        uint16[] memory shortHintArray = ob.setShortHintArray();
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(receiver);
        startMeasuringGas("Order-MatchBidToSingleShortUpdatingOracleViaThreshold");
        diamond.createBid(
            _asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT,
            Constants.LIMIT_ORDER,
            orderHintArray,
            shortHintArray
        );
        stopMeasuringGas();
        gasBidMatchShortTestAsserts({
            isFullyMatched: true,
            shortLen: 1,
            startingShortId: 101
        });
    }

    function testGasMatchBidToShortManyShortHints() public {
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        ob.skipTimeAndSetEth({skipTime: Constants.MIN_DURATION + 1, ethPrice: 4000 ether});

        uint16[] memory shortHintArray = new uint16[](10);
        for (uint16 i = 0; i < 9; i++) {
            shortHintArray[i] = i;
        }
        shortHintArray[9] = 100;
        address _asset = asset;
        vm.prank(receiver);
        startMeasuringGas("Order-MatchBidToSingleShortManyShortHints");
        diamond.createBid(
            _asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT,
            Constants.LIMIT_ORDER,
            orderHintArray,
            shortHintArray
        );
        stopMeasuringGas();
        gasBidMatchShortTestAsserts({
            isFullyMatched: true,
            shortLen: 1,
            startingShortId: 101
        });
    }
}

contract GasBidMatchMultpleShortsTest is GasBidFixture {
    using U256 for uint256;

    function setUp() public override {
        super.setUp();
        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
    }

    function testGasMatchBidToMultipleShorts() public {
        uint16[] memory shortHintArray = ob.setShortHintArray();
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(receiver);
        startMeasuringGas("Order-MatchBidToMultipleShorts");
        diamond.createBid(
            _asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT * 4,
            Constants.LIMIT_ORDER,
            orderHintArray,
            shortHintArray
        );
        stopMeasuringGas();
        gasBidMatchShortTestAsserts({
            isFullyMatched: true,
            shortLen: 0,
            startingShortId: 1
        });
    }

    function testGasMatchBidToMultipleShortsWithShares() public {
        uint16[] memory shortHintArray = ob.setShortHintArray();
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        skip(Constants.MIN_DURATION + 1);
        testFacet.setOracleTimeAndPrice(asset, DEFAULT_PRICE);
        vm.prank(receiver);
        startMeasuringGas("Order-MatchBidToMultipleShortsWithShares");
        diamond.createBid(
            _asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT * 4,
            Constants.LIMIT_ORDER,
            orderHintArray,
            shortHintArray
        );
        stopMeasuringGas();
        gasBidMatchShortTestAsserts({
            isFullyMatched: true,
            shortLen: 0,
            startingShortId: 1
        });
    }
}

contract GasMultipleBidsMatchSameShortTest is GasBidFixture {
    using U256 for uint256;

    function setUp() public override {
        super.setUp();
        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT / 2, receiver);
    }

    function testGasMatchSecondBidToShort() public {
        uint16[] memory shortHintArray = ob.setShortHintArray();
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(receiver);
        startMeasuringGas("Order-MatchSecondBidToShort");
        diamond.createBid(
            _asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT / 2,
            Constants.LIMIT_ORDER,
            orderHintArray,
            shortHintArray
        );
        stopMeasuringGas();
        gasBidMatchShortTestAsserts({
            isFullyMatched: true,
            shortLen: 0,
            startingShortId: 1
        });
    }
}

contract GasBidMatchMultpleAsksTestx100 is GasBidFixture {
    using U256 for uint256;

    function setUp() public override {
        super.setUp();
        uint128 numAsks = 100;
        for (uint256 i = 0; i < numAsks; i++) {
            ob.fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        }
    }

    function testGasMatchBidToMultipleAsksx100() public {
        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: ZERO});
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(receiver);
        startMeasuringGas("Order-MatchBidToMultipleAsksx100");
        diamond.createBid(
            _asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT * 100,
            Constants.LIMIT_ORDER,
            orderHintArray,
            shortHintArray
        );
        stopMeasuringGas();
        gasBidMatchAskTestAsserts({isFullyMatched: true});
    }
}

contract GasBidMatchMultpleShortsTestx100 is GasBidFixture {
    using U256 for uint256;

    uint16 private shortHintId;
    uint128 private unMatched = 10;
    uint128 private numShorts = 100;

    function setUp() public override {
        super.setUp();
        for (uint256 i = 0; i < unMatched; i++) {
            ob.fundLimitShortOpt(DEFAULT_PRICE - 1, DEFAULT_AMOUNT, sender); // unmatched
        }
        for (uint256 i = 0; i < numShorts; i++) {
            ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender); // matched
        }
        shortHintId = diamond.getShortIdAtOracle(asset);
    }

    function testGasMatchBidToMultipleShortsx100() public {
        address _asset = asset;
        uint16[] memory shortHintArray = new uint16[](1);
        shortHintArray[0] = shortHintId;
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        vm.prank(receiver);
        startMeasuringGas("Order-MatchBidToMultipleShortsx100");
        diamond.createBid(
            _asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT * 100,
            Constants.LIMIT_ORDER,
            orderHintArray,
            shortHintArray
        );
        stopMeasuringGas();
        gasBidMatchShortTestAsserts({
            isFullyMatched: true,
            shortLen: unMatched,
            startingShortId: 1
        });
    }

    function testGasMatchBidToMultipleShortsx100WithLeftOver() public {
        address _asset = asset;
        uint16[] memory shortHintArray = new uint16[](1);
        shortHintArray[0] = shortHintId;
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        vm.prank(receiver);
        startMeasuringGas("Order-MatchBidToMultipleShortsLeftoverx100");
        diamond.createBid(
            _asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT * 200,
            Constants.LIMIT_ORDER,
            orderHintArray,
            shortHintArray
        );
        stopMeasuringGas();
        gasBidMatchShortTestAsserts({
            isFullyMatched: false,
            shortLen: unMatched,
            startingShortId: 1
        });
    }
}

contract GasBidMatchShortsHint is GasBidFixture {
    using U256 for uint256;

    function setUp() public override {
        super.setUp();
        //make many shorts that can't be matched
        for (uint256 i = 0; i < 5; i++) {
            ob.fundLimitShortOpt(DEFAULT_PRICE - 1 wei, DEFAULT_AMOUNT, sender);
        }
        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        ob.skipTimeAndSetEth({skipTime: Constants.MIN_DURATION + 1, ethPrice: 4000 ether});
    }

    function testGasMatchBidToShortsWithHint() public {
        uint16[] memory shortHintArray = new uint16[](1);
        shortHintArray[0] = 105;
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(receiver);
        startMeasuringGas("Order-SkippingShortsUsingHint");
        diamond.createBid(
            _asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT,
            Constants.LIMIT_ORDER,
            orderHintArray,
            shortHintArray
        );
        stopMeasuringGas();
        gasBidMatchShortTestAsserts({
            isFullyMatched: true,
            shortLen: 5,
            startingShortId: 1
        });
    }

    function testGasMatchBidToShortsManyHints() public {
        ob.skipTimeAndSetEth({skipTime: Constants.MIN_DURATION + 1, ethPrice: 4000 ether});
        uint16[] memory shortHintArray = new uint16[](10);
        for (uint16 i = 0; i < 9; i++) {
            shortHintArray[i] = i;
        }
        shortHintArray[9] = 105;
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(receiver);
        startMeasuringGas("Order-SkippingShortsUsingManyHint");
        diamond.createBid(
            _asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT,
            Constants.LIMIT_ORDER,
            orderHintArray,
            shortHintArray
        );
        stopMeasuringGas();
        gasBidMatchShortTestAsserts({
            isFullyMatched: true,
            shortLen: 5,
            startingShortId: 1
        });
    }
}

contract GasBidMatchShortSkipOraclePriceUpdate is GasBidFixture {
    using U256 for uint256;

    function setUp() public override {
        super.setUp();
        for (uint80 i = 0; i < 8; i++) {
            //short hint Ids 100 -> 107 (8 shorts)
            ob.fundLimitShortOpt(DEFAULT_PRICE + i, DEFAULT_AMOUNT, sender);
        }
    }

    function testGasMatchBidManyWrongHintsSkipStartingShortUpdate() public {
        skip(1 hours);
        uint16[] memory shortHintArray = new uint16[](10);
        //short hints 0-8 are 0 and invalid
        shortHintArray[9] = 107;
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        uint80 price = DEFAULT_PRICE + 7 wei;
        uint88 amount = DEFAULT_AMOUNT * 3;
        vm.prank(receiver);
        startMeasuringGas("Order-WrongHints-MatchBidSkipStartingShortUpdate");
        diamond.createBid(
            _asset, price, amount, Constants.LIMIT_ORDER, orderHintArray, shortHintArray
        );
        stopMeasuringGas();
        STypes.Order[] memory shorts = ob.getShorts();
        assertEq(shorts.length, 5);
        assertEq(shorts[shorts.length - 1].id, 107);
    }

    function testGasMatchBidManyWrongHintsUpdateStartingShort() public {
        ob.skipTimeAndSetEth({skipTime: 1 hours, ethPrice: 4001 ether});
        uint16[] memory shortHintArray = new uint16[](10);
        //short hints 0-8 are 0 and invalid
        shortHintArray[9] = 107;
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        uint80 price = DEFAULT_PRICE + 7 wei;
        uint88 amount = DEFAULT_AMOUNT * 3;
        vm.prank(receiver);
        startMeasuringGas("Order-WrongHints-MatchBidStartingShortUpdated");
        diamond.createBid(
            _asset, price, amount, Constants.LIMIT_ORDER, orderHintArray, shortHintArray
        );
        stopMeasuringGas();
        STypes.Order[] memory shorts = ob.getShorts();
        assertEq(shorts.length, 5);
        assertEq(shorts[shorts.length - 1].id, 107);
    }
}
