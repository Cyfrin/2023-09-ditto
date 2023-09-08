// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U88} from "contracts/libraries/PRBMathHelper.sol";

import {Constants} from "contracts/libraries/Constants.sol";
import {STypes} from "contracts/libraries/DataTypes.sol";
import {OBFixture} from "test/utils/OBFixture.sol";
// import {console} from "contracts/libraries/console.sol";

contract MiscStorageTest is OBFixture {
    using U88 for uint88;

    function setUp() public override {
        super.setUp();
    }

    function testProperShortId() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(2 ether), receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(2 ether), sender);

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(3 ether), receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(3 ether), sender);

        assertEq(getShortRecordCount(sender), 3);
        assertEq(
            getShortRecord(sender, Constants.SHORT_STARTING_ID).ercDebt, DEFAULT_AMOUNT
        );
        assertEq(
            getShortRecord(sender, Constants.SHORT_STARTING_ID + 1).ercDebt,
            DEFAULT_AMOUNT.mulU88(2 ether)
        );
        assertEq(
            getShortRecord(sender, Constants.SHORT_STARTING_ID + 2).ercDebt,
            DEFAULT_AMOUNT.mulU88(3 ether)
        );
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(2 ether), receiver);
        exitShort(
            Constants.SHORT_STARTING_ID + 1,
            DEFAULT_AMOUNT.mulU88(2 ether),
            DEFAULT_PRICE,
            sender
        );

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(4 ether), receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(4 ether), sender);

        assertEq(getShortRecordCount(sender), 3);
        assertEq(
            getShortRecord(sender, Constants.SHORT_STARTING_ID).ercDebt, DEFAULT_AMOUNT
        );
        assertEq(
            getShortRecord(sender, Constants.SHORT_STARTING_ID + 1).ercDebt,
            DEFAULT_AMOUNT.mulU88(4 ether)
        );
        assertEq(
            getShortRecord(sender, Constants.SHORT_STARTING_ID + 2).ercDebt,
            DEFAULT_AMOUNT.mulU88(3 ether)
        );
    }

    //  getShortRecordCount
    function testCanCheckShorts() public {
        assertEq(getShortRecordCount(sender), 0);

        fundLimitShortOpt(0.1 ether, DEFAULT_AMOUNT, sender);
        assertEq(getShortRecordCount(sender), 0);
        fundLimitBidOpt(0.1 ether, DEFAULT_AMOUNT, receiver);
        assertEq(getShortRecordCount(receiver), 0);
        assertEq(getShortRecordCount(sender), 1);

        fundLimitShortOpt(0.1 ether, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(0.1 ether, DEFAULT_AMOUNT, receiver);

        assertEq(getShortRecordCount(receiver), 0);
        assertEq(getShortRecordCount(sender), 2);
    }

    function testCanCheckShortsAfterExit() public {
        testCanCheckShorts();
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        exitShort(Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT, DEFAULT_PRICE, sender);
        assertEq(getShortRecordCount(sender), 1);

        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        exitShort(Constants.SHORT_STARTING_ID + 1, DEFAULT_AMOUNT, DEFAULT_PRICE, sender);
        assertEq(getShortRecordCount(sender), 0);
    }

    // getLiquidationBool, getShorterRatio
    function testCratio() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        assertEq(diamond.getAssetPrice(asset), U256.inv(4000 ether));

        STypes.ShortRecord memory short =
            getShortRecord(sender, Constants.SHORT_STARTING_ID);
        assertEq(diamond.getCollateralRatio(asset, short), 6 ether);
        assertEq(diamond.getAssetCollateralRatio(asset), 6 ether);

        _setETH(3000 ether);

        short = getShortRecord(sender, Constants.SHORT_STARTING_ID);
        assertEq(diamond.getCollateralRatio(asset, short), 4500000000000004500);
        assertEq(diamond.getAssetCollateralRatio(asset), 4500000000000004500);
    }

    function testMultipleCratio() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        // swap
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        assertEq(diamond.getAssetPrice(asset), U256.inv(4000 ether));
        STypes.ShortRecord memory short =
            getShortRecord(sender, Constants.SHORT_STARTING_ID);
        assertEq(diamond.getCollateralRatio(asset, short), 6 ether);
        short = getShortRecord(sender, Constants.SHORT_STARTING_ID + 1);
        assertEq(diamond.getCollateralRatio(asset, short), 6 ether);
        short = getShortRecord(receiver, Constants.SHORT_STARTING_ID);
        assertEq(diamond.getCollateralRatio(asset, short), 6 ether);

        assertEq(diamond.getAssetCollateralRatio(asset), 6 ether);

        _setETH(3000 ether);

        short = getShortRecord(sender, Constants.SHORT_STARTING_ID);
        assertEq(diamond.getCollateralRatio(asset, short), 4500000000000004500);
        short = getShortRecord(sender, Constants.SHORT_STARTING_ID + 1);
        assertEq(diamond.getCollateralRatio(asset, short), 4500000000000004500);

        short = getShortRecord(receiver, Constants.SHORT_STARTING_ID);
        assertEq(diamond.getCollateralRatio(asset, short), 4500000000000004500);

        assertEq(diamond.getAssetCollateralRatio(asset), 4500000000000004500);
    }

    function testGetShorterLastIndexExitShort() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        uint256 gasLeft = gasleft();
        exitShort(Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT, DEFAULT_PRICE, receiver);
        emit log_named_uint("gasLeft", gasLeft - gasleft());
        gasLeft = gasleft();
        exitShort(
            Constants.SHORT_STARTING_ID + 1, DEFAULT_AMOUNT, DEFAULT_PRICE, receiver
        );
        emit log_named_uint("gasLeft", gasLeft - gasleft());
    }

    function testGetShorterLastIndexMarginCall() public {
        // Fund Tapp to avoid market freeze
        depositEth(tapp, DEFAULT_TAPP);

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        _setETH(2666 ether); //price in USD (min eth for liquidation ratio Formula: .0015P = 4 => P = 2666.67
        uint256 gasLeft = gasleft();

        vm.startPrank(sender);
        skipTimeAndSetEth({skipTime: 1, ethPrice: 2666 ether});
        diamond.flagShort(asset, receiver, Constants.SHORT_STARTING_ID, Constants.HEAD);
        skipTimeAndSetEth({skipTime: TEN_HRS_PLUS, ethPrice: 2666 ether});
        diamond.liquidate(
            asset, receiver, Constants.SHORT_STARTING_ID, shortHintArrayStorage
        );
        emit log_named_uint("gasLeft", gasLeft - gasleft());
        gasLeft = gasleft();

        diamond.flagShort(
            asset, receiver, Constants.SHORT_STARTING_ID + 1, Constants.HEAD
        );
        skipTimeAndSetEth({skipTime: TEN_HRS_PLUS, ethPrice: 2666 ether});
        diamond.liquidate(
            asset, receiver, Constants.SHORT_STARTING_ID + 1, shortHintArrayStorage
        );
        emit log_named_uint("gasLeft", gasLeft - gasleft());
    }

    // exitShort
    function testGetShorter() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        uint256 shortCnt = getShortRecordCount(sender);
        assertEq(shortCnt, 1);

        //create another short from same address
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        shortCnt = getShortRecordCount(sender);
        assertEq(shortCnt, 2);

        // create short from another address
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        shortCnt = getShortRecordCount(sender);
        assertEq(shortCnt, 2);
        shortCnt = getShortRecordCount(receiver);
        assertEq(shortCnt, 1);

        // exit both shorts for sender
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        exitShort(Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT, DEFAULT_PRICE, sender);
        exitShort(Constants.SHORT_STARTING_ID + 1, DEFAULT_AMOUNT, DEFAULT_PRICE, sender);

        shortCnt = getShortRecordCount(sender);
        assertEq(shortCnt, 0);

        // add the original sender back into the shorters
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        // add another short and then exit short for the receiver
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, extra);

        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        exitShort(Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT, DEFAULT_PRICE, receiver);
    }

    // mint
    function testCanMint() public {
        assertEq(cusd.balanceOf(sender), 0);

        uint256 amount = 100 ether;
        vm.prank(_diamond);
        cusd.mint(sender, amount);
        assertEq(cusd.balanceOf(sender), amount);
    }

    function testCanTokenBurnFrom() public {
        assertEq(getTotalErc(), 0);

        fundLimitBidOpt(0.1 ether, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(0.1 ether, DEFAULT_AMOUNT, sender);

        assertEq(getTotalErc(), DEFAULT_AMOUNT);
        fundLimitAskOpt(0.00025 ether, DEFAULT_AMOUNT, receiver);
        exitShort(Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT, DEFAULT_PRICE, sender);
    }

    function testCanCancelBids() public {
        fundLimitBidOpt(0.1 ether, DEFAULT_AMOUNT, sender); // 100
        fundLimitBidOpt(0.1 ether, DEFAULT_AMOUNT, sender); // 101
        fundLimitBidOpt(0.1 ether, DEFAULT_AMOUNT, sender); // 102
        STypes.Order[] memory topBids = getBids();

        // remove the second bid
        vm.prank(sender);
        cancelBid(topBids[1].id); // 101

        topBids = getBids();

        assertEq(topBids.length, 2);
        assertEq(topBids[0].id, 100);
        assertEq(topBids[1].id, 102);

        fundLimitBidOpt(0.1 ether, DEFAULT_AMOUNT, sender); // 101
        topBids = getBids();

        assertEq(topBids.length, 3);
        assertEq(topBids[0].id, 100);
        assertEq(topBids[1].id, 102);
        assertEq(topBids[2].id, 101);
    }

    function testCanCancelAsk() public {
        depositEth(sender, 10 ether);
        fundLimitAskOpt(0.1 ether, DEFAULT_AMOUNT, sender); // 100
        fundLimitAskOpt(0.1 ether, DEFAULT_AMOUNT, sender); // 101
        fundLimitAskOpt(0.1 ether, DEFAULT_AMOUNT, sender); // 102
        STypes.Order[] memory Asks = getAsks();

        vm.prank(sender);
        // remove the second ask
        cancelAsk(Asks[1].id); // 101

        Asks = getAsks();

        assertEq(Asks.length, 2);
        assertEq(Asks[0].id, 100);
        assertEq(Asks[1].id, 102);

        fundLimitAskOpt(0.1 ether, DEFAULT_AMOUNT, sender);
        Asks = getAsks();

        assertEq(Asks.length, 3);
        assertEq(Asks[0].id, 100);
        assertEq(Asks[1].id, 102);
        assertEq(Asks[2].id, 101); // reuse 101

        fundLimitAskOpt(0.1 ether, DEFAULT_AMOUNT, sender);
        Asks = getAsks();

        assertEq(Asks.length, 4);
        assertEq(Asks[0].id, 100);
        assertEq(Asks[1].id, 102);
        assertEq(Asks[2].id, 101); // reuse 101
        assertEq(Asks[3].id, 103);
    }

    function testCanCancelShort() public {
        depositEth(sender, DEFAULT_AMOUNT.mulU88(10 ether));
        fundLimitShortOpt(0.1 ether, DEFAULT_AMOUNT, sender); // 100
        fundLimitShortOpt(0.1 ether, DEFAULT_AMOUNT, sender); // 101
        fundLimitShortOpt(0.1 ether, DEFAULT_AMOUNT, sender); // 102
        STypes.Order[] memory shorts = getShorts();

        vm.prank(sender);
        // remove the second ask
        cancelShort(shorts[1].id); // 101

        shorts = getShorts();

        assertEq(shorts.length, 2);
        assertEq(shorts[0].id, 100);
        assertEq(shorts[1].id, 102);

        fundLimitShortOpt(0.1 ether, DEFAULT_AMOUNT, sender);
        shorts = getShorts();

        assertEq(shorts.length, 3);
        assertEq(shorts[0].id, 100);
        assertEq(shorts[1].id, 102);
        assertEq(shorts[2].id, 101); // reuse 101

        fundLimitShortOpt(0.1 ether, DEFAULT_AMOUNT, sender);
        shorts = getShorts();

        assertEq(shorts.length, 4);
        assertEq(shorts[0].id, 100);
        assertEq(shorts[1].id, 102);
        assertEq(shorts[2].id, 101); // reuse 101
        assertEq(shorts[3].id, 103);
    }
}
