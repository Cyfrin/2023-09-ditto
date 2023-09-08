// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U88} from "contracts/libraries/PRBMathHelper.sol";

import {STypes, MTypes, F, SR} from "contracts/libraries/DataTypes.sol";
import {Constants, Vault} from "contracts/libraries/Constants.sol";
import {IAsset} from "interfaces/IAsset.sol";
// import {console} from "contracts/libraries/console.sol";

import {SecondaryType} from "test/utils/TestTypes.sol";
import {GasHelper} from "test-gas/GasHelper.sol";

contract GasMarginCallFixture is GasHelper {
    using U256 for uint256;
    using U88 for uint88;

    //Batch liquidations
    bool public constant WALLET = true;
    bool public constant ERC_ESCROWED = false;

    function setUp() public virtual override {
        super.setUp();

        ob.depositUsd(receiver, DEFAULT_AMOUNT.mulU88(100 ether));
        ob.depositEth(receiver, DEFAULT_AMOUNT.mulU88(100 ether));
        ob.depositUsd(sender, DEFAULT_AMOUNT.mulU88(100 ether));
        ob.depositEth(sender, DEFAULT_AMOUNT.mulU88(100 ether));
        ob.depositUsd(extra, DEFAULT_AMOUNT.mulU88(100 ether));
        ob.depositEth(extra, DEFAULT_AMOUNT.mulU88(100 ether));
        ob.depositUsd(tapp, Constants.MIN_DEPOSIT);
        ob.depositEth(tapp, Constants.MIN_DEPOSIT);

        // create shorts
        for (uint8 i; i < 10; i++) {
            ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
            ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        }
    }

    function gasMarginCallPrimaryAsserts(address shorter, bool loseCollateral) public {
        uint256 vault = Vault.CARBON;
        STypes.ShortRecord memory short =
            ob.getShortRecord(shorter, Constants.SHORT_STARTING_ID);
        assertTrue(short.status == SR.Cancelled);
        assertGt(
            diamond.getVaultUserStruct(vault, tapp).ethEscrowed, Constants.MIN_DEPOSIT
        );
        assertEq(diamond.getAssetStruct(asset).ercDebtRate, 0);

        if (loseCollateral) {
            assertEq(
                diamond.getVaultUserStruct(vault, shorter).ethEscrowed,
                DEFAULT_AMOUNT.mulU88(100 ether)
            );
        } else {
            assertGt(
                diamond.getVaultUserStruct(vault, shorter).ethEscrowed,
                DEFAULT_AMOUNT.mulU88(100 ether)
            );
        }
    }

    function gasMarginCallPrimaryPartialAsserts(address shorter, bool loseCollateral)
        public
    {
        uint256 vault = Vault.CARBON;
        STypes.ShortRecord memory short =
            ob.getShortRecord(shorter, Constants.SHORT_STARTING_ID);
        assertGt(
            diamond.getVaultUserStruct(vault, tapp).ethEscrowed, Constants.MIN_DEPOSIT
        );
        assertEq(
            diamond.getVaultUserStruct(vault, shorter).ethEscrowed,
            DEFAULT_AMOUNT.mulU88(100 ether)
        );
        assertEq(diamond.getAssetStruct(asset).ercDebtRate, 0);

        if (loseCollateral) {
            assertTrue(short.status == SR.Cancelled);
            short = ob.getShortRecord(tapp, Constants.SHORT_STARTING_ID);
            assertGt(short.collateral, 0);
        } else {
            assertTrue(short.status == SR.FullyFilled);
        }
    }

    function gasMarginCallSecondaryAsserts(
        address asset,
        address shorter,
        address caller,
        SecondaryType secondaryType,
        bool loseCollateral
    ) public {
        uint256 vault = Vault.CARBON;
        STypes.ShortRecord memory short =
            ob.getShortRecord(shorter, Constants.SHORT_STARTING_ID);
        assertTrue(short.status == SR.Cancelled);

        if (secondaryType == SecondaryType.LiquidateErcEscrowed) {
            assertLt(
                diamond.getAssetUserStruct(asset, caller).ercEscrowed,
                DEFAULT_AMOUNT.mulU88(100 ether)
            );
            assertEq(cusd.balanceOf(caller), DEFAULT_AMOUNT.mulU88(2 ether));
        } else if (secondaryType == SecondaryType.LiquidateWallet) {
            assertEq(
                diamond.getAssetUserStruct(asset, caller).ercEscrowed,
                DEFAULT_AMOUNT.mulU88(100 ether)
            );
            assertLt(cusd.balanceOf(caller), DEFAULT_AMOUNT.mulU88(2 ether));
        }
        assertGt(
            diamond.getVaultUserStruct(vault, caller).ethEscrowed,
            DEFAULT_AMOUNT.mulU88(100 ether)
        );

        if (loseCollateral) {
            assertGt(
                diamond.getVaultUserStruct(vault, tapp).ethEscrowed, Constants.MIN_DEPOSIT
            );
        }
    }

    function gasMarginCallSecondaryPartialAsserts(
        address asset,
        address shorter,
        address caller,
        SecondaryType secondaryType
    ) public {
        uint256 vault = Vault.CARBON;
        STypes.ShortRecord memory short =
            ob.getShortRecord(shorter, Constants.SHORT_STARTING_ID);
        assertTrue(short.status == SR.FullyFilled);

        if (secondaryType == SecondaryType.LiquidateErcEscrowed) {
            assertLt(
                diamond.getAssetUserStruct(asset, caller).ercEscrowed,
                DEFAULT_AMOUNT.mulU88(100 ether)
            );
            assertEq(cusd.balanceOf(caller), DEFAULT_AMOUNT / 2);
        } else if (secondaryType == SecondaryType.LiquidateWallet) {
            assertEq(
                diamond.getAssetUserStruct(asset, caller).ercEscrowed,
                DEFAULT_AMOUNT.mulU88(100 ether)
            );
            assertLt(cusd.balanceOf(caller), DEFAULT_AMOUNT / 2);
        }
        assertGt(
            diamond.getVaultUserStruct(vault, caller).ethEscrowed,
            DEFAULT_AMOUNT.mulU88(100 ether)
        );
    }
}

contract GasMarginCallPrimaryFlagTest is GasMarginCallFixture {
    function setUp() public override {
        super.setUp();

        //lower eth price for liquidate
        ob.setETH(2666 ether);
        skip(1); //so updatedAt isn't zero
    }

    function testGasLiquidateFlag() public {
        address _asset = asset;
        address _shorter = sender;
        vm.startPrank(receiver);
        startMeasuringGas("Liquidate-Primary-Flag");
        diamond.flagShort(_asset, _shorter, Constants.SHORT_STARTING_ID, Constants.HEAD);
        stopMeasuringGas();
    }
}

contract GasMarginCallPrimaryFlagRecycleTest is GasMarginCallFixture {
    function setUp() public override {
        super.setUp();

        //lower eth price for liquidate
        ob.setETH(2666 ether);
        vm.startPrank(receiver);
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID, Constants.HEAD);
    }

    function testGasLiquidateFlagRecycle() public {
        address _asset = asset;
        address _shorter = sender;
        vm.startPrank(receiver);
        startMeasuringGas("Liquidate-Primary-Flag-Recycle");
        diamond.flagShort(
            _asset, _shorter, Constants.SHORT_STARTING_ID + 1, Constants.HEAD
        );
        stopMeasuringGas();
    }

    function testGasLiquidateFlagRecycle_UseInactiveFlaggerId() public {
        skip(SIXTEEN_HRS_PLUS);
        ob.setETH(2666 ether);
        address _asset = asset;
        address _shorter = sender;
        vm.startPrank(extra);
        startMeasuringGas("Liquidate-Primary-Flag-Recycle-UseInactiveFlaggerId");
        diamond.flagShort(_asset, _shorter, Constants.SHORT_STARTING_ID, Constants.HEAD);
        stopMeasuringGas();
    }
}

contract GasMarginCallPrimaryTest is GasMarginCallFixture {
    function setUp() public override {
        super.setUp();

        // create asks for exit/margin
        ob.fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, extra);

        //lower eth price for liquidate
        ob.setETH(2666 ether);
        vm.prank(receiver);
        skip(1); //so updatedAt isn't zero
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID, Constants.HEAD);
        skip(TEN_HRS_PLUS); //10hrs 1 second
        testFacet.setOracleTimeAndPrice(asset, testFacet.getOraclePriceT(asset));
        ob.setETH(2500 ether);
    }

    function testGasLiquidate() public {
        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: ONE});
        address _asset = asset;
        address _shorter = sender;
        vm.startPrank(receiver);
        startMeasuringGas("Liquidate-Primary");
        diamond.liquidate(_asset, _shorter, Constants.SHORT_STARTING_ID, shortHintArray);
        stopMeasuringGas();
        gasMarginCallPrimaryAsserts({shorter: _shorter, loseCollateral: false});
    }

    function testGasLiquidateUpdateOraclePrice() public {
        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: ONE});
        skip(15 minutes);
        address _asset = asset;
        address _shorter = sender;
        vm.startPrank(receiver);
        startMeasuringGas("Liquidate-Primary-UpdateOraclePrice");
        diamond.liquidate(_asset, _shorter, Constants.SHORT_STARTING_ID, shortHintArray);
        stopMeasuringGas();
        gasMarginCallPrimaryAsserts({shorter: _shorter, loseCollateral: false});
    }
}

contract GasMarginCallPrimaryPartialTest is GasMarginCallFixture {
    function setUp() public override {
        super.setUp();

        // create asks for exit/margin
        ob.fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT / 2, extra);

        //lower eth price for liquidate
        ob.setETH(2666 ether);
        vm.prank(receiver);
        skip(1); //so updatedAt isn't zero
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID, Constants.HEAD);
        ob.skipTimeAndSetEth({skipTime: TEN_HRS_PLUS, ethPrice: 2666 ether});
        testFacet.setOracleTimeAndPrice(asset, testFacet.getOraclePriceT(asset));
    }

    function testGasLiquidatePartial() public {
        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: ONE});
        address _asset = asset;
        address _shorter = sender;
        vm.startPrank(receiver);
        startMeasuringGas("Liquidate-Primary-Partial");
        diamond.liquidate(_asset, _shorter, Constants.SHORT_STARTING_ID, shortHintArray);
        stopMeasuringGas();
        gasMarginCallPrimaryPartialAsserts({shorter: _shorter, loseCollateral: false});
    }
}

contract GasMarginCallSecondaryTest is GasMarginCallFixture {
    using U88 for uint88;

    function setUp() public override {
        super.setUp();
        vm.prank(_diamond);
        cusd.mint(extra, DEFAULT_AMOUNT.mulU88(2 ether)); //for liquidateWallet
        //lower eth price for liquidate
        ob.setETH(999 ether);
    }

    function testGasliquidateErcEscrowed() public {
        address _asset = asset;
        address _shorter = sender;
        MTypes.BatchMC[] memory batches = new MTypes.BatchMC[](1);
        batches[0] =
            MTypes.BatchMC({shorter: _shorter, shortId: Constants.SHORT_STARTING_ID});
        vm.startPrank(extra);
        startMeasuringGas("Liquidate-ErcEscrowed");
        diamond.liquidateSecondary(_asset, batches, DEFAULT_AMOUNT, ERC_ESCROWED);
        stopMeasuringGas();
        gasMarginCallSecondaryAsserts({
            asset: _asset,
            shorter: sender,
            caller: extra,
            secondaryType: SecondaryType.LiquidateErcEscrowed,
            loseCollateral: false
        });
    }

    function testGasliquidateWallet() public {
        address _asset = asset;
        address _shorter = sender;
        MTypes.BatchMC[] memory batches = new MTypes.BatchMC[](1);
        batches[0] =
            MTypes.BatchMC({shorter: _shorter, shortId: Constants.SHORT_STARTING_ID});
        vm.startPrank(extra);
        startMeasuringGas("Liquidate-Wallet");
        diamond.liquidateSecondary(_asset, batches, DEFAULT_AMOUNT, WALLET);
        stopMeasuringGas();
        gasMarginCallSecondaryAsserts({
            asset: _asset,
            shorter: sender,
            caller: extra,
            secondaryType: SecondaryType.LiquidateWallet,
            loseCollateral: false
        });
    }
}

contract GasMarginCallSecondaryPartialTest is GasMarginCallFixture {
    function setUp() public override {
        super.setUp();
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, tapp);
        // Since the tapp already has short in position 2, combine with the newly created short 101
        // This should never happen in practice since the tapp doesnt make shorts, just for ease of testing
        vm.prank(tapp);
        uint8[] memory ids = new uint8[](2);
        ids[0] = Constants.SHORT_STARTING_ID;
        ids[1] = Constants.SHORT_STARTING_ID + 1;
        diamond.combineShorts(asset, ids);
        // Lower eth price for liquidate
        ob.setETH(750 ether);
        // Set up liquidateWallet
        vm.prank(_diamond);
        cusd.mint(extra, DEFAULT_AMOUNT / 2);
    }

    function testGasliquidateErcEscrowedPartial() public {
        address _asset = asset;
        address _shorter = tapp;
        MTypes.BatchMC[] memory batches = new MTypes.BatchMC[](1);
        batches[0] =
            MTypes.BatchMC({shorter: _shorter, shortId: Constants.SHORT_STARTING_ID});
        vm.startPrank(extra);
        startMeasuringGas("Liquidate-ErcEscrowed-Partial");
        diamond.liquidateSecondary(_asset, batches, DEFAULT_AMOUNT / 2, ERC_ESCROWED);
        stopMeasuringGas();
        gasMarginCallSecondaryPartialAsserts({
            asset: _asset,
            shorter: _shorter,
            caller: extra,
            secondaryType: SecondaryType.LiquidateErcEscrowed
        });
    }

    function testGasliquidateWalletPartial() public {
        address _asset = asset;
        address _shorter = tapp;
        MTypes.BatchMC[] memory batches = new MTypes.BatchMC[](1);
        batches[0] =
            MTypes.BatchMC({shorter: _shorter, shortId: Constants.SHORT_STARTING_ID});
        vm.startPrank(extra);
        startMeasuringGas("Liquidate-Wallet-Partial");
        diamond.liquidateSecondary(_asset, batches, DEFAULT_AMOUNT / 2, WALLET);
        stopMeasuringGas();
        gasMarginCallSecondaryPartialAsserts({
            asset: _asset,
            shorter: _shorter,
            caller: extra,
            secondaryType: SecondaryType.LiquidateWallet
        });
    }
}

contract GasMarginCallSecondaryPartialLowCratioTest is GasMarginCallFixture {
    function setUp() public override {
        super.setUp();
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, tapp);
        // Since the tapp already has short in position 2, combine with the newly created short 101
        // This should never happen in practice since the tapp doesnt make shorts, just for ease of testing
        vm.prank(tapp);

        uint8[] memory ids = new uint8[](2);
        ids[0] = Constants.SHORT_STARTING_ID;
        ids[1] = Constants.SHORT_STARTING_ID + 1;
        diamond.combineShorts(asset, ids);
        // Lower eth price for liquidate
        ob.setETH(200 ether);
        // Set up liquidateWallet
        vm.prank(_diamond);
        cusd.mint(extra, DEFAULT_AMOUNT / 2);
    }

    function testGasliquidateErcEscrowedPartialLowCratio() public {
        address _asset = asset;
        address _shorter = tapp;
        MTypes.BatchMC[] memory batches = new MTypes.BatchMC[](1);
        batches[0] =
            MTypes.BatchMC({shorter: _shorter, shortId: Constants.SHORT_STARTING_ID});
        vm.startPrank(extra);
        startMeasuringGas("Liquidate-ErcEscrowed-Partial-LowCratio");
        diamond.liquidateSecondary(_asset, batches, DEFAULT_AMOUNT / 2, ERC_ESCROWED);
        stopMeasuringGas();
        gasMarginCallSecondaryPartialAsserts({
            asset: _asset,
            shorter: _shorter,
            caller: extra,
            secondaryType: SecondaryType.LiquidateErcEscrowed
        });
    }

    function testGasliquidateWalletPartialLowCratio() public {
        address _asset = asset;
        address _shorter = tapp;
        MTypes.BatchMC[] memory batches = new MTypes.BatchMC[](1);
        batches[0] =
            MTypes.BatchMC({shorter: _shorter, shortId: Constants.SHORT_STARTING_ID});
        vm.startPrank(extra);
        startMeasuringGas("Liquidate-Wallet-Partial-LowCratio");
        diamond.liquidateSecondary(_asset, batches, DEFAULT_AMOUNT / 2, WALLET);
        stopMeasuringGas();
        gasMarginCallSecondaryPartialAsserts({
            asset: _asset,
            shorter: _shorter,
            caller: extra,
            secondaryType: SecondaryType.LiquidateWallet
        });
    }
}

contract GasMarginCallPrimaryTappTest is GasMarginCallFixture {
    function setUp() public override {
        super.setUp();

        // create asks for exit/margin
        ob.fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, extra);

        // mint eth for tapp
        ob.depositEth(tapp, FUNDED_TAPP);

        //lower eth price for liquidate
        ob.setETH(666.66 ether); //black swan
        vm.prank(receiver);
        skip(1); //so updatedAt isn't zero
        ob.skipTimeAndSetEth({skipTime: TEN_HRS_PLUS, ethPrice: 666.66 ether});
        testFacet.setOracleTimeAndPrice(asset, testFacet.getOraclePriceT(asset));
    }

    function testGasLiquidateTapp() public {
        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: ONE});
        address _asset = asset;
        address _shorter = sender;
        vm.startPrank(receiver);
        startMeasuringGas("Liquidate-Primary-LoseCollateral");
        diamond.liquidate(_asset, _shorter, Constants.SHORT_STARTING_ID, shortHintArray);
        stopMeasuringGas();
        gasMarginCallPrimaryAsserts({shorter: sender, loseCollateral: true});
    }
}

contract GasMarginCallPrimaryTappPartialTest is GasMarginCallFixture {
    function setUp() public override {
        super.setUp();

        // create asks for exit/margin
        ob.fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT / 2, extra);

        // mint eth for tapp
        ob.depositEth(tapp, FUNDED_TAPP);

        //lower eth price for liquidate
        ob.setETH(666.66 ether); //black swan
        vm.prank(receiver);
        skip(1); //so updatedAt isn't zero
        testFacet.setOracleTimeAndPrice(asset, testFacet.getOraclePriceT(asset));
    }

    function testGasLiquidateTappPartial() public {
        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: ONE});
        address _asset = asset;
        address _shorter = sender;
        vm.startPrank(receiver);
        startMeasuringGas("Liquidate-Primary-LoseCollateral-Partial");
        diamond.liquidate(_asset, _shorter, Constants.SHORT_STARTING_ID, shortHintArray);
        stopMeasuringGas();
        gasMarginCallPrimaryPartialAsserts({shorter: sender, loseCollateral: true});
    }
}

contract GasMarginCallSecondaryTappTest is GasMarginCallFixture {
    using U88 for uint88;

    function setUp() public override {
        super.setUp();
        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        // mint usd for liquidateWallet
        vm.prank(_diamond);
        cusd.mint(extra, DEFAULT_AMOUNT.mulU88(2 ether));

        //lower eth price for liquidate
        ob.setETH(675 ether); //roughly get cratio between 1 and 1.1
    }

    function testGasliquidateErcEscrowedPenaltyFee() public {
        address _asset = asset;
        address _shorter = sender;
        MTypes.BatchMC[] memory batches = new MTypes.BatchMC[](1);
        batches[0] =
            MTypes.BatchMC({shorter: _shorter, shortId: Constants.SHORT_STARTING_ID});
        vm.startPrank(extra);
        startMeasuringGas("Liquidate-ErcEscrowed-TappFee");
        diamond.liquidateSecondary(_asset, batches, DEFAULT_AMOUNT, ERC_ESCROWED);
        stopMeasuringGas();
        gasMarginCallSecondaryAsserts({
            asset: _asset,
            shorter: sender,
            caller: extra,
            secondaryType: SecondaryType.LiquidateErcEscrowed,
            loseCollateral: true
        });
    }

    function testGasliquidateWalletPenaltyFee() public {
        address _asset = asset;
        address _shorter = sender;
        MTypes.BatchMC[] memory batches = new MTypes.BatchMC[](1);
        batches[0] =
            MTypes.BatchMC({shorter: _shorter, shortId: Constants.SHORT_STARTING_ID});
        vm.startPrank(extra);
        startMeasuringGas("Liquidate-Wallet-TappFee");
        diamond.liquidateSecondary(_asset, batches, DEFAULT_AMOUNT, WALLET);
        stopMeasuringGas();
        gasMarginCallSecondaryAsserts({
            asset: _asset,
            shorter: sender,
            caller: extra,
            secondaryType: SecondaryType.LiquidateWallet,
            loseCollateral: true
        });
    }
}

contract GasMarginCallBlackSwan is GasMarginCallFixture {
    function setUp() public override {
        super.setUp();

        // create asks for exit/margin
        ob.fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, extra);

        //lower eth price for liquidate
        ob.setETH(666.66 ether); //black swan
        vm.prank(receiver);
        skip(1); //so updatedAt isn't zero
        testFacet.setOracleTimeAndPrice(asset, testFacet.getOraclePriceT(asset));
    }

    function testGasLiquidateBlackSwan() public {
        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: ONE});
        address _asset = asset;
        address _shorter = sender;
        vm.startPrank(receiver);
        startMeasuringGas("Liquidate-BlackSwan");
        diamond.liquidate(_asset, _shorter, Constants.SHORT_STARTING_ID, shortHintArray);
        stopMeasuringGas();
        assertGt(diamond.getAssetStruct(asset).ercDebtRate, 0);
    }
}

contract GasMarginCallSecondaryBatch is GasMarginCallFixture {
    function setUp() public override {
        super.setUp();
        vm.prank(_diamond);
        cusd.mint(extra, DEFAULT_AMOUNT * 10); //for liquidateWallet
        assertEq(ob.getShortRecordCount(sender), 10);

        //lower eth price for liquidate
        ob.setETH(999 ether);
    }

    function testGasliquidateWalletBatch() public {
        address _asset = asset;
        address _shorter = sender;
        MTypes.BatchMC[] memory batches = new MTypes.BatchMC[](10);
        for (uint8 i; i < 10; i++) {
            uint8 id = Constants.SHORT_STARTING_ID + i;
            batches[i] = MTypes.BatchMC({shorter: _shorter, shortId: id});
        }
        vm.startPrank(extra);
        startMeasuringGas("Liquidate-Wallet-Batch");
        diamond.liquidateSecondary(_asset, batches, DEFAULT_AMOUNT * 10, WALLET);
        stopMeasuringGas();
        assertEq(ob.getShortRecordCount(sender), 0);
    }

    function testGasliquidateErcEscrowedBatch() public {
        address _asset = asset;
        address _shorter = sender;
        MTypes.BatchMC[] memory batches = new MTypes.BatchMC[](10);
        for (uint8 i; i < 10; i++) {
            uint8 id = Constants.SHORT_STARTING_ID + i;
            batches[i] = MTypes.BatchMC({shorter: _shorter, shortId: id});
        }
        vm.startPrank(extra);
        startMeasuringGas("Liquidate-ErcEscrowed-Batch");
        diamond.liquidateSecondary(_asset, batches, DEFAULT_AMOUNT * 10, ERC_ESCROWED);
        stopMeasuringGas();
        assertEq(ob.getShortRecordCount(sender), 0);
    }
}

contract GasMarginCallSecondaryBatchWithRates is GasMarginCallFixture {
    function setUp() public override {
        super.setUp();
        vm.prank(_diamond);
        cusd.mint(extra, DEFAULT_AMOUNT * 11); //for liquidateWallet
        assertEq(ob.getShortRecordCount(sender), 10);

        // Non-zero zethYieldRate
        deal(ob.contracts("steth"), ob.contracts("bridgeSteth"), 305 ether);
        diamond.updateYield(ob.vault());
        // Non-zero ercDebtRate
        testFacet.setErcDebtRate(asset, 0.1 ether); // 1.1x
        // Fake increasing asset ercDebt so it can be subtracted later
        ob.fundLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT, extra); // 0.1*10 = 1
        ob.fundLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT, extra); // 0.1*10 = 1

        //lower eth price for liquidate
        ob.setETH(999 ether);
    }

    function testGasliquidateWalletBatchWithRates() public {
        address _asset = asset;
        address _shorter = sender;
        MTypes.BatchMC[] memory batches = new MTypes.BatchMC[](10);
        for (uint8 i; i < 10; i++) {
            uint8 id = Constants.SHORT_STARTING_ID + i;
            batches[i] = MTypes.BatchMC({shorter: _shorter, shortId: id});
        }
        vm.startPrank(extra);
        startMeasuringGas("Liquidate-Wallet-Batch-Rates");
        diamond.liquidateSecondary(_asset, batches, DEFAULT_AMOUNT * 11, WALLET);
        stopMeasuringGas();
        assertEq(ob.getShortRecordCount(sender), 0);
    }

    function testGasliquidateErcEscrowedBatchWithRates() public {
        address _asset = asset;
        address _shorter = sender;
        MTypes.BatchMC[] memory batches = new MTypes.BatchMC[](10);
        for (uint8 i; i < 10; i++) {
            uint8 id = Constants.SHORT_STARTING_ID + i;
            batches[i] = MTypes.BatchMC({shorter: _shorter, shortId: id});
        }
        vm.startPrank(extra);
        startMeasuringGas("Liquidate-ErcEscrowed-Batch-Rates");
        diamond.liquidateSecondary(_asset, batches, DEFAULT_AMOUNT * 20, ERC_ESCROWED);
        stopMeasuringGas();
        assertEq(ob.getShortRecordCount(sender), 0);
    }
}

contract GasMarginCallBlackSwanFreezeCratioGt1 is GasMarginCallFixture {
    function setUp() public override {
        super.setUp();

        ob.setETH(700 ether); // c-ratio 1.05
    }

    function testGasBlackSwanFreezeCratioGt1() public {
        vm.prank(receiver);
        startMeasuringGas("Shutdown-CratioGt1");
        diamond.shutdownMarket(asset);
        stopMeasuringGas();
        assertTrue(diamond.getAssetStruct(asset).frozen == F.Permanent);
    }
}

contract GasMarginCallBlackSwanFreezeCratioLt1 is GasMarginCallFixture {
    function setUp() public override {
        super.setUp();

        ob.setETH(600 ether); // c-ratio 0.9
    }

    function testGasBlackSwanFreezeCratioLt1() public {
        vm.prank(receiver);
        startMeasuringGas("Shutdown-CratioLt1");
        diamond.shutdownMarket(asset);
        stopMeasuringGas();
        assertTrue(diamond.getAssetStruct(asset).frozen == F.Permanent);
    }
}

contract GasMarginCallBlackSwanFreezeRedeemErc is GasMarginCallFixture {
    function setUp() public override {
        super.setUp();

        // Doesn't matter as long as less than market shutdown threshold
        ob.setETH(700 ether); // c-ratio 1.05

        vm.startPrank(sender);
        diamond.shutdownMarket(asset);
        diamond.withdrawAsset(asset, DEFAULT_AMOUNT);

        assertTrue(diamond.getAssetStruct(asset).frozen == F.Permanent);
    }

    function testGasBlackSwanFreezeRedeemErcWallet() public {
        startMeasuringGas("RedeemErc-Wallet");
        diamond.redeemErc(asset, DEFAULT_AMOUNT, 0);
        stopMeasuringGas();
    }

    function testGasBlackSwanFreezeRedeemErcEscrowed() public {
        startMeasuringGas("RedeemErc-Escrowed");
        diamond.redeemErc(asset, 0, DEFAULT_AMOUNT);
        stopMeasuringGas();
    }

    function testGasBlackSwanFreezeRedeemBoth() public {
        startMeasuringGas("RedeemErc-Both");
        diamond.redeemErc(asset, DEFAULT_AMOUNT, DEFAULT_AMOUNT);
        stopMeasuringGas();
    }
}
