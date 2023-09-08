// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U88, U80} from "contracts/libraries/PRBMathHelper.sol";
import {Constants} from "contracts/libraries/Constants.sol";

import {GasHelper} from "test-gas/GasHelper.sol";

// import {console} from "contracts/libraries/console.sol";

contract GasShortFixture is GasHelper {
    using U88 for uint88;
    using U80 for uint80;

    function setUp() public virtual override {
        super.setUp();

        ob.depositUsd(receiver, DEFAULT_AMOUNT.mulU88(100 ether));
        ob.depositEth(receiver, DEFAULT_AMOUNT.mulU88(100 ether));
        ob.depositUsd(sender, DEFAULT_AMOUNT.mulU88(100 ether));
        ob.depositEth(sender, DEFAULT_AMOUNT.mulU88(100 ether));

        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
    }
}

contract GasCombineShortTest is GasShortFixture {
    using U256 for uint256;

    uint256 private numShorts = 100;

    function setUp() public override {
        super.setUp();

        for (uint256 i = 0; i < numShorts; i++) {
            ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, extra);
            ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, extra);
        }
    }

    function testGasCombineShortsx2() public {
        address _asset = asset;
        vm.prank(sender);

        uint8[] memory ids = new uint8[](2);
        ids[0] = Constants.SHORT_STARTING_ID;
        ids[1] = Constants.SHORT_STARTING_ID + 1;
        startMeasuringGas("ShortRecord-CombineShort");
        diamond.combineShorts(_asset, ids);
        stopMeasuringGas();
        assertEq(ob.getShortRecordCount(sender), 1);
    }

    function testGasCombineShortsx10Of100() public {
        address _asset = asset;
        uint8 num = 10;

        uint8[] memory ids = new uint8[](num);
        ids[0] = Constants.SHORT_STARTING_ID;
        ids[1] = Constants.SHORT_STARTING_ID + 17;
        ids[2] = Constants.SHORT_STARTING_ID + 23;
        ids[3] = Constants.SHORT_STARTING_ID + 35;
        ids[4] = Constants.SHORT_STARTING_ID + 36;
        ids[5] = Constants.SHORT_STARTING_ID + 51;
        ids[6] = Constants.SHORT_STARTING_ID + 52;
        ids[7] = Constants.SHORT_STARTING_ID + 57;
        ids[8] = Constants.SHORT_STARTING_ID + 66;
        ids[9] = Constants.SHORT_STARTING_ID + 95;
        vm.prank(extra);
        startMeasuringGas("ShortRecord-CombineShortx10of100");
        diamond.combineShorts(_asset, ids);
        stopMeasuringGas();
        //@dev started with 100, combined 10 into 1
        assertEq(ob.getShortRecordCount(extra), 91);
    }

    function testGasCombineShortsx100() public {
        address _asset = asset;

        uint8[] memory ids = new uint8[](100);
        for (
            uint8 i = Constants.SHORT_STARTING_ID;
            i < Constants.SHORT_STARTING_ID + 100;
            i++
        ) {
            ids[i - Constants.SHORT_STARTING_ID] = i;
        }
        vm.prank(extra);
        startMeasuringGas("ShortRecord-CombineShortx100");
        diamond.combineShorts(_asset, ids);
        stopMeasuringGas();
        assertEq(ob.getShortRecordCount(extra), 1);
    }
}

contract GasCombineShortFlaggedTest is GasShortFixture {
    using U256 for uint256;

    function setUp() public override {
        super.setUp();
        ob.setETH(2666 ether);
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID, Constants.HEAD);
        ob.setETH(2667 ether);
    }

    function testGasCombineShortsx2Flagged() public {
        address _asset = asset;
        vm.prank(sender);
        uint8[] memory ids = new uint8[](2);
        ids[0] = Constants.SHORT_STARTING_ID;
        ids[1] = Constants.SHORT_STARTING_ID + 1;
        startMeasuringGas("ShortRecord-CombineShort-Flag");
        diamond.combineShorts(_asset, ids);
        stopMeasuringGas();
        assertEq(ob.getShortRecordCount(sender), 1);
    }
}

contract GasExitShortTest is GasShortFixture {
    using U256 for uint256;
    using U88 for uint88;

    uint256 private numShorts = 100;

    function setUp() public override {
        super.setUp();
        //create ask for exit/margin
        ob.fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        ob.fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        // mint usd for exitShortWallet
        vm.prank(_diamond);
        cusd.mint(sender, DEFAULT_AMOUNT.mulU88(2 ether));
    }

    function testGasExitShortFull() public {
        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: ONE});
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("ExitShort-full");
        diamond.exitShort(
            _asset,
            Constants.SHORT_STARTING_ID,
            DEFAULT_AMOUNT,
            DEFAULT_PRICE,
            shortHintArray
        );
        stopMeasuringGas();
        assertEq(ob.getShortRecordCount(sender), 1);
    }

    function testGasExitShortPartial() public {
        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: ONE});
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("ExitShort-partial");
        diamond.exitShort(
            _asset,
            Constants.SHORT_STARTING_ID,
            DEFAULT_AMOUNT.mulU88(0.5 ether),
            DEFAULT_PRICE,
            shortHintArray
        );
        stopMeasuringGas();
        assertEq(ob.getShortRecordCount(sender), 2);
        assertEq(
            ob.getShortRecord(sender, Constants.SHORT_STARTING_ID).ercDebt,
            DEFAULT_AMOUNT.mulU88(0.5 ether)
        );
    }

    function testGasExitShortWalletFull() public {
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("ExitShort-wallet-full");
        diamond.exitShortWallet(_asset, Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT);
        stopMeasuringGas();
        assertEq(ob.getShortRecordCount(sender), 1);
    }

    function testGasExitShortWalletPartial() public {
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("ExitShort-wallet-partial");
        diamond.exitShortWallet(
            _asset, Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT.mulU88(0.5 ether)
        );
        stopMeasuringGas();
        assertEq(ob.getShortRecordCount(sender), 2);
        assertEq(
            ob.getShortRecord(sender, Constants.SHORT_STARTING_ID).ercDebt,
            DEFAULT_AMOUNT.mulU88(0.5 ether)
        );
    }

    function testGasExitShortErcEscrowedFull() public {
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("ExitShort-ercEscrowed-full");
        diamond.exitShortErcEscrowed(_asset, Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT);
        stopMeasuringGas();
        assertEq(ob.getShortRecordCount(sender), 1);
    }

    function testGasExitShortErcEscrowedPartial() public {
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("ExitShort-ercEscrowed-partial");
        diamond.exitShortErcEscrowed(
            _asset, Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT.mulU88(0.5 ether)
        );
        stopMeasuringGas();
        assertEq(ob.getShortRecordCount(sender), 2);
        assertEq(
            ob.getShortRecord(sender, Constants.SHORT_STARTING_ID).ercDebt,
            DEFAULT_AMOUNT.mulU88(0.5 ether)
        );
    }
}

contract GasShortCollateralTest is GasShortFixture {
    using U256 for uint256;
    using U88 for uint88;
    using U80 for uint80;

    function setUp() public override {
        super.setUp();
        vm.prank(sender);
        diamond.increaseCollateral(
            asset, Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT.mulU88(DEFAULT_PRICE)
        );
    }

    function testGasIncreaseCollateral() public {
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("ShortRecord-IncreaseCollateral");
        diamond.increaseCollateral(_asset, Constants.SHORT_STARTING_ID, 1 wei);
        stopMeasuringGas();
        uint256 collateral = DEFAULT_AMOUNT.mulU88(DEFAULT_PRICE) * 7;
        assertEq(
            ob.getShortRecord(sender, Constants.SHORT_STARTING_ID).collateral,
            collateral + 1 wei
        );
    }

    function testGasDecreaseCollateral() public {
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("ShortRecord-DecreaseCollateral");
        diamond.decreaseCollateral(
            _asset, Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT.mulU88(DEFAULT_PRICE)
        );
        stopMeasuringGas();
        uint256 collateral = DEFAULT_PRICE.mulU80(DEFAULT_AMOUNT) * 7;
        assertEq(
            ob.getShortRecord(sender, Constants.SHORT_STARTING_ID).collateral,
            collateral - DEFAULT_AMOUNT.mulU88(DEFAULT_PRICE)
        );
    }
}

contract GasShortMintNFT is GasShortFixture {
    using U256 for uint256;
    using U80 for uint80;

    function setUp() public override {
        super.setUp();
        vm.prank(sender);
        diamond.mintNFT(asset, Constants.SHORT_STARTING_ID);
        assertEq(diamond.getTokenId(), 2);

        //@Dev give extra a short and nft to set slot > 0
        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, extra);
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        vm.prank(extra);
        diamond.mintNFT(asset, Constants.SHORT_STARTING_ID);
        assertEq(diamond.getTokenId(), 3);
    }

    function testGasMintNFT() public {
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("ShortRecord-MintNFT");
        diamond.mintNFT(_asset, Constants.SHORT_STARTING_ID + 1);
        stopMeasuringGas();
        assertEq(diamond.getTokenId(), 4);
    }

    function testGasTransferFromNFT() public {
        address _sender = sender;
        address _extra = extra;
        vm.prank(sender);
        startMeasuringGas("ShortRecord-TransferFromNFT");
        diamond.transferFrom(_sender, _extra, 1);
        stopMeasuringGas();
    }
}
