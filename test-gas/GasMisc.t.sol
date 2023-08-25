// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {IAsset} from "interfaces/IAsset.sol";
import {IMockAggregatorV3} from "interfaces/IMockAggregatorV3.sol";

import {STypes} from "contracts/libraries/DataTypes.sol";
import {Constants, Vault} from "contracts/libraries/Constants.sol";
import {GasHelper} from "test-gas/GasHelper.sol";

contract GasMiscFixture is GasHelper {
    function setUp() public virtual override {
        super.setUp();
    }
}

contract GasCreateOBTest is GasMiscFixture {
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
        cgldAggregator.setRoundData(
            92233720368547778907 wei,
            2000 ether,
            block.timestamp,
            block.timestamp,
            92233720368547778907 wei
        );
        vm.stopPrank();
    }

    function testGasCreateMarket() public {
        STypes.Asset memory a;
        a.vault = uint8(Vault.CARBON);
        a.oracle = _cgldAggregator;
        a.initialMargin = 400; // 400 -> 4 ether
        a.primaryLiquidationCR = 300; // 300 -> 3 ether
        a.secondaryLiquidationCR = 200; // 200 -> 2 ether
        a.forcedBidPriceBuffer = 120; // 12 -> 1.2 ether
        a.resetLiquidationTime = 1400; // 1400 -> 14 hours
        a.secondLiquidationTime = 1000; // 1000 -> 10 hours
        a.firstLiquidationTime = 800; // 800 -> 8 hours
        a.minimumCR = 110; // 11 -> 1.1 ether
        a.tappFeePct = 25; //25 -> .025 ether
        a.callerFeePct = 5; //5 -> .005 ether
        a.minBidEth = 1; // // 1 -> .001 ether
        a.minAskEth = 1; // // 1 -> .001 ether
        a.minShortErc = 2000; // // 2000 -> 2000 ether

        address token = _cgld;

        vm.startPrank(owner);
        startMeasuringGas("Owner-CreateMarket");
        diamond.createMarket({asset: token, a: a});
        stopMeasuringGas();
    }
}

contract GasMiscTest is GasMiscFixture {
    function setUp() public override {
        super.setUp();
    }

    function testGasMint() public {
        address _sender = sender;
        vm.prank(_diamond);
        startMeasuringGas("Vault-MintAsset");
        cusd.mint(_sender, 1 ether);
        stopMeasuringGas();
    }
}
