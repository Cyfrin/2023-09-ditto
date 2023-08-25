// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U88} from "contracts/libraries/PRBMathHelper.sol";

import {GasHelper} from "test-gas/GasHelper.sol";
import {Constants} from "contracts/libraries/Constants.sol";
import {MTypes} from "contracts/libraries/DataTypes.sol";

// import {console} from "contracts/libraries/console.sol";

contract GasYieldFixture is GasHelper {
    using U88 for uint88;

    function setUp() public virtual override {
        super.setUp();
        ob.depositUsd(receiver, DEFAULT_AMOUNT.mulU88(100 ether));
        ob.depositEth(receiver, DEFAULT_AMOUNT.mulU88(100 ether));
        ob.depositUsd(sender, DEFAULT_AMOUNT.mulU88(100 ether));
        ob.depositEth(sender, DEFAULT_AMOUNT.mulU88(100 ether));
    }
}

contract YieldGasFixture is GasYieldFixture {
    using U256 for uint256;
    using U88 for uint88;

    function setUp() public virtual override {
        super.setUp();
        uint16[] memory shortHintArray =
            createShortHintArrayGas({shortHint: DEFAULT_SHORT_HINT_ID});
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();

        vm.startPrank(owner);
        diamond.setTithe(ob.vault(), 10);
        vm.stopPrank();

        ob.depositEth(receiver, DEFAULT_AMOUNT.mulU88(200 ether));
        vm.startPrank(receiver);
        diamond.createLimitShort(
            asset,
            0.00025 ether,
            DEFAULT_AMOUNT.mulU88(2000 ether),
            orderHintArray,
            shortHintArray,
            initialMargin
        ); // 0.2*5 = 1
        ob.skipTimeAndSetEth({skipTime: Constants.MIN_DURATION + 1, ethPrice: 4000 ether});
        testFacet.setOracleTimeAndPrice(asset, DEFAULT_PRICE);
        diamond.createBid(
            asset,
            0.00025 ether,
            DEFAULT_AMOUNT.mulU88(4000 ether),
            Constants.LIMIT_ORDER,
            orderHintArray,
            shortHintArray
        ); // 1

        ob.skipTimeAndSetEth({skipTime: Constants.MIN_DURATION + 1, ethPrice: 4000 ether});
    }

    function generateYield(uint256 num) internal {
        deal(ob.contracts("steth"), ob.contracts("bridgeSteth"), num);
    }
}

contract ClaimDittoMatchedRewardGasTest is YieldGasFixture {
    using U256 for uint256;
    using U88 for uint88;

    function setUp() public override {
        uint16[] memory shortHintArray =
            createShortHintArrayGas({shortHint: DEFAULT_SHORT_HINT_ID});
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();

        super.setUp();
        diamond.claimDittoMatchedReward(ob.vault());
        // Generate more shares
        diamond.createLimitShort(
            asset,
            0.00025 ether,
            DEFAULT_AMOUNT.mulU88(800 ether),
            orderHintArray,
            shortHintArray,
            initialMargin
        );
    }

    function testGasClaimDittoMatchedReward() public {
        uint256 vault = ob.vault();
        startMeasuringGas("Yield-ClaimDittoMatchedReward");
        diamond.claimDittoMatchedReward(vault);
        stopMeasuringGas();
    }

    function testGasWithdrawDittoReward() public {
        uint256 vault = ob.vault();
        startMeasuringGas("Yield-WithdrawDittoReward");
        diamond.withdrawDittoReward(vault);
        stopMeasuringGas();
    }
}

contract DistributeYieldGasTest is YieldGasFixture {
    using U256 for uint256;
    using U88 for uint88;

    function setUp() public override {
        super.setUp();
        address[] memory assets = new address[](1);
        assets[0] = asset;
        generateYield(DEFAULT_AMOUNT.mulU88(5000 ether));
        diamond.updateYield(ob.vault());
        diamond.distributeYield(assets);

        generateYield(DEFAULT_AMOUNT.mulU88(6000 ether));
        diamond.updateYield(ob.vault());
    }

    function testGasDistributeYield() public {
        address[] memory assets = new address[](1);
        assets[0] = asset;
        startMeasuringGas("Yield-DistributeYield");
        diamond.distributeYield(assets);
        stopMeasuringGas();
    }
}

contract DistributeYieldGasTestx2 is YieldGasFixture {
    using U256 for uint256;
    using U88 for uint88;

    function setUp() public override {
        uint16[] memory shortHintArray = new uint16[](2);
        shortHintArray[0] = DEFAULT_SHORT_HINT_ID;
        shortHintArray[1] = ONE;
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        super.setUp();
        address[] memory assets = new address[](1);
        assets[0] = asset;
        // Generate 1 more shorts
        for (uint160 i = 1; i < 2; i++) {
            diamond.createLimitShort(
                asset,
                0.00025 ether,
                DEFAULT_AMOUNT.mulU88(800 ether),
                orderHintArray,
                shortHintArray,
                initialMargin
            ); // 0.2*5 = 1
            diamond.createBid(
                asset,
                0.00025 ether,
                DEFAULT_AMOUNT.mulU88(4000 ether),
                Constants.LIMIT_ORDER,
                orderHintArray,
                shortHintArray
            ); // 1
        }
        generateYield(DEFAULT_AMOUNT.mulU88(5000 ether));
        diamond.updateYield(ob.vault());
        diamond.distributeYield(assets);

        generateYield(DEFAULT_AMOUNT.mulU88(6000 ether));
        diamond.updateYield(ob.vault());
    }

    function testGasDistributeYieldx2() public {
        address[] memory assets = new address[](1);
        assets[0] = asset;
        startMeasuringGas("Yield-DistributeYieldx2");
        diamond.distributeYield(assets);
        stopMeasuringGas();
    }
}

contract DistributeYieldGasTestx4 is YieldGasFixture {
    using U256 for uint256;
    using U88 for uint88;

    function setUp() public override {
        uint16[] memory shortHintArray = new uint16[](2);
        shortHintArray[0] = DEFAULT_SHORT_HINT_ID;
        shortHintArray[1] = ONE;
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        super.setUp();
        address[] memory assets = new address[](1);
        assets[0] = asset;
        // Generate 3 more shorts
        for (uint160 i = 1; i < 4; i++) {
            diamond.createLimitShort(
                asset,
                0.00025 ether,
                DEFAULT_AMOUNT.mulU88(800 ether),
                orderHintArray,
                shortHintArray,
                initialMargin
            ); // 0.2*5 = 1
            diamond.createBid(
                asset,
                0.00025 ether,
                DEFAULT_AMOUNT.mulU88(4000 ether),
                Constants.LIMIT_ORDER,
                orderHintArray,
                shortHintArray
            ); // 1
        }
        generateYield(DEFAULT_AMOUNT.mulU88(5000 ether));
        diamond.updateYield(ob.vault());
        diamond.distributeYield(assets);

        generateYield(DEFAULT_AMOUNT.mulU88(6000 ether));
        diamond.updateYield(ob.vault());
    }

    function testGasDistributeYieldx4() public {
        address[] memory assets = new address[](1);
        assets[0] = asset;
        startMeasuringGas("Yield-DistributeYieldx4");
        diamond.distributeYield(assets);
        stopMeasuringGas();
    }
}

contract DistributeYieldGasTestx16 is YieldGasFixture {
    using U256 for uint256;
    using U88 for uint88;

    function setUp() public override {
        uint16[] memory shortHintArray = new uint16[](2);
        shortHintArray[0] = DEFAULT_SHORT_HINT_ID;
        shortHintArray[1] = ONE;
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        super.setUp();
        address[] memory assets = new address[](1);
        assets[0] = asset;
        // Generate 15 more shorts
        for (uint160 i = 1; i < 16; i++) {
            diamond.createLimitShort(
                asset,
                0.00025 ether,
                DEFAULT_AMOUNT.mulU88(800 ether),
                orderHintArray,
                shortHintArray,
                initialMargin
            ); // 0.2*5 = 1
            diamond.createBid(
                asset,
                0.00025 ether,
                4000 ether,
                Constants.LIMIT_ORDER,
                orderHintArray,
                shortHintArray
            ); // 1
        }
        generateYield(DEFAULT_AMOUNT.mulU88(5000 ether));
        diamond.updateYield(ob.vault());
        diamond.distributeYield(assets);

        generateYield(DEFAULT_AMOUNT.mulU88(6000 ether));
        diamond.updateYield(ob.vault());
    }

    function testGasDistributeYieldx16() public {
        address[] memory assets = new address[](1);
        assets[0] = asset;
        startMeasuringGas("Yield-DistributeYieldx16");
        diamond.distributeYield(assets);
        stopMeasuringGas();
    }
}
