// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U88} from "contracts/libraries/PRBMathHelper.sol";

import {IAsset} from "interfaces/IAsset.sol";
import {IMockAggregatorV3} from "interfaces/IMockAggregatorV3.sol";

import {Errors} from "contracts/libraries/Errors.sol";
import {STypes, MTypes, O} from "contracts/libraries/DataTypes.sol";
import {Constants, Vault} from "contracts/libraries/Constants.sol";
import {LibOrders} from "contracts/libraries/LibOrders.sol";

import {OBFixture} from "test/utils/OBFixture.sol";
import {console} from "contracts/libraries/console.sol";

contract MultiAssetOrdersTest is OBFixture {
    using U256 for uint256;
    using U88 for uint88;

    uint80 public constant DEFAULT_PRICE_CGLD = 0.5 ether;
    uint88 public constant DEFAULT_AMOUNT_CGLD = 10 ether;

    IAsset public cgld;
    address public _cgld;
    IMockAggregatorV3 public cgldAggregator;
    address public _cgldAggregator;

    function setUp() public override {
        super.setUp();

        vm.startPrank(owner);

        _cgld = deployCode("Asset.sol", abi.encode(_diamond, "Carbon Gold", "CGLD"));
        cgld = IAsset(_cgld);
        vm.label(_cgld, "CGLD");
        _cgldAggregator = deployCode("MockAggregatorV3.sol");
        cgldAggregator = IMockAggregatorV3(_cgldAggregator);
        _setCGLD(2000 ether);

        STypes.Asset memory a;
        a.vault = uint8(Vault.CARBON);
        a.oracle = _cgldAggregator;
        a.initialMargin = 400; // 400 -> 4 ether
        a.primaryLiquidationCR = 300; // 300 -> 3 ether
        a.secondaryLiquidationCR = 200; // 200 -> 2 ether
        a.forcedBidPriceBuffer = 120; // 120 -> 1.2 ether
        a.resetLiquidationTime = 1400; // 1400 -> 14 hours
        a.secondLiquidationTime = 1000; // 1000 -> 10 hours
        a.firstLiquidationTime = 800; // 800 -> 8 hours
        a.minimumCR = 120; // 120 -> 1.2 ether
        a.tappFeePct = 30; // 30 -> .03 ether
        a.callerFeePct = 6; // 10 -> .006 ether
        a.minBidEth = 1; // 1 -> .001 ether
        a.minAskEth = 1; // 1 -> .001 ether
        a.minShortErc = 10; // 10 -> 10 ether

        diamond.createMarket({asset: _cgld, a: a});

        vm.stopPrank();
    }

    function _setCGLD(int256 _amount) public {
        cgldAggregator.setRoundData(
            92233720368547778907 wei,
            _amount / ORACLE_DECIMALS,
            block.timestamp,
            block.timestamp,
            92233720368547778907 wei
        );
    }

    function testMultiAssetSameTime() public {
        MTypes.OrderHint[] memory orderHintArray;

        //setup original cusd market
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        STypes.Order[] memory shorts_cusd = getShorts();
        uint80 cgld_price = DEFAULT_PRICE_CGLD;
        uint88 cgld_amount = DEFAULT_AMOUNT_CGLD;
        depositEth(
            sender,
            cgld_amount.mulU88(cgld_price).mulU88(
                diamond.getAssetNormalizedStruct(_cgld).initialMargin
            )
        );
        uint16 gldInitialMargin = diamond.getAssetStruct(_cgld).initialMargin;
        //@dev calling before createLimitShort to prevent conflict with vm.prank()
        orderHintArray = diamond.getHintArray(asset, DEFAULT_PRICE_CGLD, O.LimitShort);
        vm.prank(sender);
        diamond.createLimitShort(
            _cgld,
            DEFAULT_PRICE_CGLD,
            DEFAULT_AMOUNT_CGLD,
            orderHintArray,
            shortHintArrayStorage,
            gldInitialMargin
        );

        STypes.Order[] memory shorts_cgld = diamond.getShorts(_cgld);
        assertEq(shorts_cusd[0].price, DEFAULT_PRICE);
        assertEq(shorts_cusd[0].ercAmount, DEFAULT_AMOUNT);
        assertEq(shorts_cgld[0].price, DEFAULT_PRICE_CGLD);
        assertEq(shorts_cgld[0].ercAmount, DEFAULT_AMOUNT_CGLD);

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        assertEq(getShorts().length, 0);
        depositEth(receiver, cgld_amount.mulU88(cgld_price));
        orderHintArray = diamond.getHintArray(asset, DEFAULT_PRICE_CGLD, O.LimitBid);
        vm.prank(receiver);
        diamond.createBid(
            _cgld,
            DEFAULT_PRICE_CGLD,
            DEFAULT_AMOUNT_CGLD,
            Constants.LIMIT_ORDER,
            orderHintArray,
            shortHintArrayStorage
        );
        assertEq(diamond.getShorts(_cgld).length, 0);

        STypes.ShortRecord memory shortRecordUsd =
            getShortRecord(sender, Constants.SHORT_STARTING_ID);
        assertEq(
            shortRecordUsd.collateral,
            (LibOrders.convertCR(initialMargin) + 1 ether).mul(DEFAULT_AMOUNT).mul(
                DEFAULT_PRICE
            )
        );
        assertEq(shortRecordUsd.ercDebt, DEFAULT_AMOUNT);

        STypes.ShortRecord memory shortRecordGld =
            diamond.getShortRecord(_cgld, sender, Constants.SHORT_STARTING_ID);
        assertEq(
            shortRecordGld.collateral,
            cgld_amount.mul(cgld_price).mul(
                diamond.getAssetNormalizedStruct(_cgld).initialMargin + 1 ether
            )
        );
        assertEq(shortRecordGld.ercDebt, DEFAULT_AMOUNT_CGLD);

        assertEq(diamond.getAssetUserStruct(asset, receiver).ercEscrowed, DEFAULT_AMOUNT);
        assertEq(
            diamond.getAssetUserStruct(_cgld, receiver).ercEscrowed, DEFAULT_AMOUNT_CGLD
        );

        assertEq(
            diamond.getVaultStruct(vault).zethCollateral,
            shortRecordUsd.collateral + shortRecordGld.collateral
        );
    }

    function testMultiAssetSettings() public {
        //test cusd ob settings (see OBFixture, createMarket())
        assertEq(diamond.getAssetStruct(asset).initialMargin, 500);
        assertEq(diamond.getAssetStruct(asset).primaryLiquidationCR, 400);
        assertEq(diamond.getAssetStruct(asset).secondaryLiquidationCR, 150);
        assertEq(diamond.getAssetStruct(asset).forcedBidPriceBuffer, 110);
        assertEq(diamond.getAssetStruct(asset).minimumCR, 110);
        assertEq(diamond.getAssetStruct(asset).tappFeePct, 25);
        assertEq(diamond.getAssetStruct(asset).callerFeePct, 5);
        assertEq(diamond.getAssetStruct(asset).resetLiquidationTime, 1600);
        assertEq(diamond.getAssetStruct(asset).secondLiquidationTime, 1200);
        assertEq(diamond.getAssetStruct(asset).firstLiquidationTime, 1000);

        assertEq(diamond.getAssetNormalizedStruct(asset).initialMargin, 5 ether);
        assertEq(diamond.getAssetNormalizedStruct(asset).primaryLiquidationCR, 4 ether);
        assertEq(
            diamond.getAssetNormalizedStruct(asset).secondaryLiquidationCR, 1.5 ether
        );
        assertEq(diamond.getAssetNormalizedStruct(asset).forcedBidPriceBuffer, 1.1 ether);
        assertEq(diamond.getAssetNormalizedStruct(asset).minimumCR, 1.1 ether);
        assertEq(diamond.getAssetNormalizedStruct(asset).tappFeePct, 0.025 ether);
        assertEq(diamond.getAssetNormalizedStruct(asset).callerFeePct, 0.005 ether);
        assertEq(diamond.getAssetNormalizedStruct(asset).resetLiquidationTime, 16);
        assertEq(diamond.getAssetNormalizedStruct(asset).secondLiquidationTime, 12);
        assertEq(diamond.getAssetNormalizedStruct(asset).firstLiquidationTime, 10);

        assertEq(diamond.getAssetStruct(_cgld).initialMargin, 400);
        assertEq(diamond.getAssetStruct(_cgld).primaryLiquidationCR, 300);
        assertEq(diamond.getAssetStruct(_cgld).secondaryLiquidationCR, 200);
        assertEq(diamond.getAssetStruct(_cgld).forcedBidPriceBuffer, 120);
        assertEq(diamond.getAssetStruct(_cgld).minimumCR, 120);
        assertEq(diamond.getAssetStruct(_cgld).tappFeePct, 30);
        assertEq(diamond.getAssetStruct(_cgld).callerFeePct, 6);
        assertEq(diamond.getAssetStruct(_cgld).resetLiquidationTime, 1400);
        assertEq(diamond.getAssetStruct(_cgld).secondLiquidationTime, 1000);
        assertEq(diamond.getAssetStruct(_cgld).firstLiquidationTime, 800);

        assertEq(diamond.getAssetNormalizedStruct(_cgld).initialMargin, 4 ether);
        assertEq(diamond.getAssetNormalizedStruct(_cgld).primaryLiquidationCR, 3 ether);
        assertEq(diamond.getAssetNormalizedStruct(_cgld).secondaryLiquidationCR, 2 ether);
        assertEq(diamond.getAssetNormalizedStruct(_cgld).forcedBidPriceBuffer, 1.2 ether);
        assertEq(diamond.getAssetNormalizedStruct(_cgld).minimumCR, 1.2 ether);
        assertEq(diamond.getAssetNormalizedStruct(_cgld).tappFeePct, 0.03 ether);
        assertEq(diamond.getAssetNormalizedStruct(_cgld).callerFeePct, 0.006 ether);
        assertEq(diamond.getAssetNormalizedStruct(_cgld).resetLiquidationTime, 14);
        assertEq(diamond.getAssetNormalizedStruct(_cgld).secondLiquidationTime, 10);
        assertEq(diamond.getAssetNormalizedStruct(_cgld).firstLiquidationTime, 8);
    }

    function testRevertYieldDifferentVaults() public {
        // Deploy new gold market in different vault
        vm.startPrank(owner);
        _cgld = deployCode("Asset.sol", abi.encode(_diamond, "Carbon Gold", "CGLD"));
        cgld = IAsset(_cgld);
        vm.label(_cgld, "CGLD");
        _cgldAggregator = deployCode("MockAggregatorV3.sol");
        cgldAggregator = IMockAggregatorV3(_cgldAggregator);
        _setCGLD(2000 ether);

        STypes.Asset memory a;
        a.vault = 2;
        a.oracle = _cgldAggregator;
        a.initialMargin = 400; // 400 -> 4 ether
        a.primaryLiquidationCR = 300; // 300 -> 3 ether
        a.secondaryLiquidationCR = 200; // 200 -> 2 ether
        a.forcedBidPriceBuffer = 120; // 120 -> 1.2 ether
        a.resetLiquidationTime = 1400; // 1400 -> 14 hours
        a.secondLiquidationTime = 1000; // 1000 -> 10 hours
        a.firstLiquidationTime = 800; // 800 -> 8 hours
        a.minimumCR = 120; // 120 -> 1.2 ether
        a.tappFeePct = 30; // 30 -> .03 ether
        a.callerFeePct = 6; // 10 -> .006 ether
        a.minBidEth = 1; // 1 -> .001 ether
        a.minAskEth = 1; // 1 -> .001 ether
        a.minShortErc = 2000; // 1 -> .001 ether

        diamond.createMarket({asset: _cgld, a: a});
        vm.stopPrank();

        address[] memory assets = new address[](2);
        assets[0] = asset; // Vault 1
        assets[1] = _cgld; // Vault 2

        vm.expectRevert(Errors.DifferentVaults.selector);
        diamond.distributeYield(assets);
    }
}
