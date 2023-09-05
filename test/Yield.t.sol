// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U88, U80} from "contracts/libraries/PRBMathHelper.sol";

import {Errors} from "contracts/libraries/Errors.sol";
import {Constants, Vault} from "contracts/libraries/Constants.sol";
import {STypes, MTypes, O} from "contracts/libraries/DataTypes.sol";

import {OBFixture} from "test/utils/OBFixture.sol";
// import {console} from "contracts/libraries/console.sol";

contract YieldTest is OBFixture {
    using U256 for uint256;
    using U88 for uint88;
    using U80 for uint80;

    bool private constant BID_FIRST = true;
    bool private constant SHORT_FIRST = false;
    bool public distributed = false;

    uint256 public skipTime = Constants.MIN_DURATION + 1;
    uint256 public yieldEligibleTime = (Constants.YIELD_DELAY_HOURS * 2) * 1 hours; //@round up by hours instead of seconds or minutes

    function setUp() public virtual override {
        super.setUp();

        // Fund addresses
        for (uint160 j = 1; j <= 4; j++) {
            depositUsd(address(j), DEFAULT_AMOUNT.mulU88(4000 ether));

            deal(address(j), 250 ether);
            deal(_reth, address(j), 250 ether);
            deal(_steth, address(j), 500 ether);

            vm.startPrank(address(j), address(j));
            reth.approve(
                _bridgeReth,
                0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
            );
            steth.approve(
                _bridgeSteth,
                0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
            );

            diamond.depositEth{value: 250 ether}(_bridgeReth);
            diamond.deposit(_bridgeReth, 250 ether);
            diamond.deposit(_bridgeSteth, 500 ether);
            vm.stopPrank();
        }
    }

    function generateYield(uint256 amount) internal {
        uint256 startingAmt = bridgeSteth.getZethValue();
        uint256 endingAmt = startingAmt + amount;
        deal(_steth, _bridgeSteth, endingAmt);
        diamond.updateYield(vault);
    }

    function generateYield() internal {
        reth.submitBalances(100 ether, 80 ether);
        deal(_steth, _bridgeSteth, 2500 ether);
        updateYield();
    }

    function updateYield() internal {
        uint256 zethTotal = diamond.getVaultStruct(vault).zethTotal;
        uint256 zethTreasury = diamond.getVaultUserStruct(vault, tapp).ethEscrowed;
        uint256 zethYieldRate = diamond.getVaultStruct(vault).zethYieldRate;
        uint256 zethCollateral = diamond.getVaultStruct(vault).zethCollateral;

        diamond.updateYield(vault);

        uint256 yield = diamond.getVaultStruct(vault).zethTotal - zethTotal;
        uint256 treasuryD =
            diamond.getVaultUserStruct(vault, tapp).ethEscrowed - zethTreasury;
        uint256 yieldRateD = diamond.getVaultStruct(vault).zethYieldRate - zethYieldRate;
        assertEq(diamond.getVaultStruct(vault).zethTotal, 5000 ether);
        // Can be different bc of truncating
        assertApproxEqAbs(treasuryD + zethCollateral.mul(yieldRateD), yield, MAX_DELTA);
    }

    function distributeYield(address _addr) internal returns (uint256 reward) {
        //@dev skip bc yield can only be distributed after a week
        skip(yieldEligibleTime);
        address[] memory assets = new address[](1);
        assets[0] = asset;
        uint256 ethEscrowed = diamond.getVaultUserStruct(vault, _addr).ethEscrowed;

        vm.prank(_addr);
        diamond.distributeYield(assets);
        reward = diamond.getVaultUserStruct(vault, _addr).ethEscrowed - ethEscrowed;
    }

    function claimDittoMatchedReward(address _addr) internal {
        vm.prank(_addr);
        diamond.claimDittoMatchedReward(vault);
    }

    function withdrawDittoReward(address _addr) internal {
        vm.prank(_addr);
        diamond.withdrawDittoReward(vault);
    }

    function test_view_getUndistributedYield() public {
        assertEq(diamond.getUndistributedYield(vault), 0);
        generateYield();
        assertEq(diamond.getUndistributedYield(vault), 0);

        uint256 UNDISTRIBUTED_YIELD = 10 ether;
        uint256 startingAmt = bridgeSteth.getZethValue();
        uint256 endingAmt = startingAmt + UNDISTRIBUTED_YIELD;
        deal(_steth, _bridgeSteth, endingAmt);

        assertEq(diamond.getUndistributedYield(vault), UNDISTRIBUTED_YIELD);
    }

    function test_view_getYield() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        skipTimeAndSetEth({skipTime: skipTime, ethPrice: 4000 ether});

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        skip(yieldEligibleTime);
        generateYield(10 ether);

        assertEq(diamond.getYield(asset, sender), 0);
        assertApproxEqAbs(diamond.getYield(asset, receiver), 9 ether, MAX_DELTA);
        assertApproxEqAbs(
            diamond.getDittoMatchedReward(vault, receiver), 1209571, MAX_DELTA
        );
        assertEq(diamond.getDittoReward(vault, receiver), 0);

        distributeYield(receiver);
        vm.prank(receiver);
        diamond.claimDittoMatchedReward(vault);

        assertEq(diamond.getYield(asset, receiver), 0);
        assertEq(diamond.getDittoMatchedReward(vault, receiver), 0);
        assertApproxEqAbs(diamond.getDittoReward(vault, receiver), 2433572, MAX_DELTA);
    }

    function test_DistributeYieldSameAsset() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        skip(yieldEligibleTime);
        generateYield(1 ether);

        address[] memory assets = new address[](2);
        assets[0] = asset;
        assets[1] = asset;
        uint256 ethEscrowed = diamond.getVaultUserStruct(vault, receiver).ethEscrowed;

        vm.prank(receiver);
        diamond.distributeYield(assets);
        uint256 ethEscrowed2 = diamond.getVaultUserStruct(vault, receiver).ethEscrowed;
        assertApproxEqAbs(ethEscrowed2 - ethEscrowed, 900000000000000000, MAX_DELTA);
    }

    function test_view_getTithe() public {
        assertEq(diamond.getTithe(vault), 0.1 ether);
    }

    function exitShortWalletAsserts() public {
        // Exit Short Partial from Wallet
        changePrank(_diamond);
        token.mint(sender, DEFAULT_AMOUNT);
        changePrank(sender);
        diamond.exitShortWallet(asset, Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT / 2);
        assertEq(
            diamond.getVaultStruct(vault).zethCollateral,
            DEFAULT_AMOUNT.mulU88(0.0015 ether)
        ); // 0.00025*6
        assertEq(
            diamond.getAssetStruct(asset).zethCollateral,
            DEFAULT_AMOUNT.mulU88(0.0015 ether)
        ); // 0.00025*6
        assertEq(
            getShortRecord(sender, Constants.SHORT_STARTING_ID).ercDebt,
            DEFAULT_AMOUNT / 2
        );
        // Exit Short Full from Wallet
        diamond.exitShortWallet(asset, Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT / 2);
        testCanInitializeState();
    }

    function exitShortEscrowAsserts() public {
        // Exit Short Partial from Escrow
        diamond.exitShortErcEscrowed(
            asset, Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT / 2
        );
        assertEq(
            diamond.getVaultStruct(vault).zethCollateral,
            DEFAULT_AMOUNT.mulU88(0.0015 ether)
        ); // 0.00025*6
        assertEq(
            diamond.getAssetStruct(asset).zethCollateral,
            DEFAULT_AMOUNT.mulU88(0.0015 ether)
        ); // 0.00025*6
        assertEq(
            getShortRecord(sender, Constants.SHORT_STARTING_ID).ercDebt,
            DEFAULT_AMOUNT / 2
        );
        // Exit Short Full from Escrow
        diamond.exitShortErcEscrowed(
            asset, Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT / 2
        );
        testCanInitializeState();
    }

    function exitShortAsserts(uint256 order) public {
        // Exit Short Partial
        exitShort(Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT / 2, DEFAULT_PRICE);
        if (order == 0) {
            assertEq(
                diamond.getVaultStruct(vault).zethCollateral,
                DEFAULT_AMOUNT.mulU88(0.001375 ether)
            ); // 0.00025*6 - 0.00025/2
            assertEq(
                diamond.getAssetStruct(asset).zethCollateral,
                DEFAULT_AMOUNT.mulU88(0.001375 ether)
            );
            assertEq(
                getShortRecord(sender, Constants.SHORT_STARTING_ID).ercDebt,
                DEFAULT_AMOUNT / 2
            );
            // Exit Short Full
            exitShort(Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT / 2, DEFAULT_PRICE);
        } else if (order == 1) {
            assertEq(
                diamond.getVaultStruct(vault).zethCollateral,
                DEFAULT_AMOUNT.mulU88(0.002125 ether)
            ); // 0.00025*6 - 0.00025/2 + 0.00025/2*6
            assertEq(
                diamond.getAssetStruct(asset).zethCollateral,
                DEFAULT_AMOUNT.mulU88(0.002125 ether)
            );
            assertEq(
                getShortRecord(sender, Constants.SHORT_STARTING_ID).ercDebt,
                DEFAULT_AMOUNT / 2
            );
            // Exit Short Full
            exitShort(Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT / 2, DEFAULT_PRICE);
            // Exit leftover short
            createLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT);
            exitShort(Constants.SHORT_STARTING_ID + 1, DEFAULT_AMOUNT, DEFAULT_PRICE);
        } else {
            assertEq(
                diamond.getVaultStruct(vault).zethCollateral,
                DEFAULT_AMOUNT.mulU88(0.002125 ether)
            ); // 0.00025*6 - 0.00025/2 + 0.00025/2*6
            assertEq(
                diamond.getAssetStruct(asset).zethCollateral,
                DEFAULT_AMOUNT.mulU88(0.002125 ether)
            );
            assertEq(
                getShortRecord(sender, Constants.SHORT_STARTING_ID).ercDebt,
                DEFAULT_AMOUNT / 2
            );
            // Exit Short Full
            exitShort(Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT / 2, DEFAULT_PRICE);
            // Exit leftover short
            createLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT);
            exitShort(Constants.SHORT_STARTING_ID + 1, DEFAULT_AMOUNT, DEFAULT_PRICE);
        }
        testCanInitializeState();
    }

    function marginCallWalletAsserts() public {
        changePrank(_diamond);
        token.mint(receiver, DEFAULT_AMOUNT);
        _setETH(1000 ether);
        vm.stopPrank();
        liquidateWallet(sender, Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT, receiver);
        _setETH(4000 ether);
        testCanInitializeState();
        vm.startPrank(sender);
    }

    function marginCallEscrowAsserts() public {
        vm.stopPrank();
        _setETH(1000 ether);
        liquidateErcEscrowed(
            sender, Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT, receiver
        );
        _setETH(4000 ether);
        testCanInitializeState();
        vm.startPrank(sender);
    }

    function marginCallAsserts(uint256 order) public {
        changePrank(owner);
        testFacet.setprimaryLiquidationCRT(asset, 2550);
        changePrank(receiver);
        // Margin Call Partial
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID, Constants.HEAD);
        skipTimeAndSetEth({skipTime: TEN_HRS_PLUS, ethPrice: 4000 ether});
        uint256 tappFee = 0.025 ether;
        uint256 ethFilledTotal;

        if (order == 0) {
            (uint256 gas, uint256 ethFilled) = diamond.liquidate(
                asset, sender, Constants.SHORT_STARTING_ID, shortHintArrayStorage
            );
            ethFilledTotal += ethFilled;
            uint256 ethUsed = DEFAULT_AMOUNT.mulU88(0.00137125 ether) - gas; // 0.00025*6 - 0.00025/2 - 0.00025/2*.025 - 0.00025/2*.005
            assertEq(diamond.getVaultStruct(vault).zethCollateral, ethUsed);
            assertEq(diamond.getAssetStruct(asset).zethCollateral, ethUsed);
            assertEq(
                getShortRecord(sender, Constants.SHORT_STARTING_ID).ercDebt,
                DEFAULT_AMOUNT / 2
            );
            // Margin Call Full
            createLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT / 2);
            (, ethFilled) = diamond.liquidate(
                asset, sender, Constants.SHORT_STARTING_ID, shortHintArrayStorage
            );
            ethFilledTotal += ethFilled;
        } else if (order == 1) {
            (uint256 gas, uint256 ethFilled) = diamond.liquidate(
                asset, sender, Constants.SHORT_STARTING_ID, shortHintArrayStorage
            );
            ethFilledTotal += ethFilled;
            uint256 ethUsed = DEFAULT_AMOUNT.mulU88(0.00212125 ether) - gas; // 0.00025*6 - 0.00025/2 - 0.00025/2*.025 - 0.00025/2*.005 + 0.00025/2*6
            assertEq(diamond.getVaultStruct(vault).zethCollateral, ethUsed);
            assertEq(diamond.getAssetStruct(asset).zethCollateral, ethUsed);
            assertEq(
                getShortRecord(sender, Constants.SHORT_STARTING_ID).ercDebt,
                DEFAULT_AMOUNT / 2
            );
            // Margin Call Full
            changePrank(sender);
            createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT / 2);
            changePrank(receiver);
            (, ethFilled) = diamond.liquidate(
                asset, sender, Constants.SHORT_STARTING_ID, shortHintArrayStorage
            );
            ethFilledTotal += ethFilled;
            // Exit leftover shorts
            createLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT);
            changePrank(sender);
            exitShort(Constants.SHORT_STARTING_ID + 1, DEFAULT_AMOUNT / 2, DEFAULT_PRICE);
            exitShort(Constants.SHORT_STARTING_ID + 2, DEFAULT_AMOUNT / 2, DEFAULT_PRICE);
        } else {
            (uint256 gas, uint256 ethFilled) = diamond.liquidate(
                asset, sender, Constants.SHORT_STARTING_ID, shortHintArrayStorage
            );
            ethFilledTotal += ethFilled;
            uint256 ethUsed = DEFAULT_AMOUNT.mulU88(0.00212125 ether) - gas; // 0.00025*6 - 0.00025/2 - 0.00025/2*.025 - 0.00025/2*.005 + 0.00025/2*6
            assertEq(diamond.getVaultStruct(vault).zethCollateral, ethUsed);
            assertEq(diamond.getAssetStruct(asset).zethCollateral, ethUsed);
            assertEq(
                getShortRecord(sender, Constants.SHORT_STARTING_ID).ercDebt,
                DEFAULT_AMOUNT / 2
            );
            // Margin Call Full
            changePrank(sender);
            createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT / 2);
            changePrank(receiver);
            (, ethFilled) = diamond.liquidate(
                asset, sender, Constants.SHORT_STARTING_ID, shortHintArrayStorage
            );
            ethFilledTotal += ethFilled;
            // Exit leftover shorts
            createLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT);
            changePrank(sender);
            exitShort(Constants.SHORT_STARTING_ID + 1, DEFAULT_AMOUNT / 2, DEFAULT_PRICE);
            exitShort(Constants.SHORT_STARTING_ID + 2, DEFAULT_AMOUNT / 2, DEFAULT_PRICE);
        }
        assertEq(diamond.getZethTotal(vault), 4000 ether);
        assertEq(diamond.getVaultStruct(vault).zethTotal, 4000 ether);
        assertEq(
            diamond.getVaultUserStruct(vault, tapp).ethEscrowed,
            ethFilledTotal.mul(tappFee)
        );
        assertEq(diamond.getVaultStruct(vault).zethCollateral, 0);
        assertEq(diamond.getAssetStruct(asset).zethCollateral, 0);
    }

    function oneYieldDistribution(
        uint80 bidPrice,
        uint88 bidERC,
        uint80 shortPrice,
        uint88 shortERC,
        bool bidFirst
    ) public {
        address sharesUser;
        uint256 executionPrice;
        uint256 shares;

        if (bidFirst) {
            sharesUser = sender;
            vm.prank(sender);
            createLimitBid(bidPrice, bidERC);
            skipTimeAndSetEth({skipTime: skipTime, ethPrice: 4000 ether});
            vm.prank(receiver);
            createLimitShort(shortPrice, shortERC);
            executionPrice = bidPrice;
            shares = shortERC < bidERC
                ? shortERC.mul(bidPrice) * (skipTime / 1 days)
                : bidERC.mul(bidPrice) * (skipTime / 1 days);
        } else {
            sharesUser = receiver;
            vm.prank(receiver);
            createLimitShort(shortPrice, shortERC);
            skipTimeAndSetEth({skipTime: skipTime, ethPrice: 4000 ether});
            vm.prank(sender);
            createLimitBid(bidPrice, bidERC);
            executionPrice = shortPrice;
            shares = shortERC < bidERC
                ? shortERC.mul(shortPrice).mul(5 ether) * (skipTime / 1 days)
                : bidERC.mul(shortPrice).mul(5 ether) * (skipTime / 1 days);
        }

        {
            skipTime += yieldEligibleTime;
            uint256 zethTotal = diamond.getZethTotal(vault);
            generateYield();
            uint256 zethReward = diamond.getZethTotal(vault) - zethTotal;
            uint256 zethCollateral = shortERC < bidERC
                ? shortERC.mul(executionPrice) + shortERC.mul(shortPrice).mul(5 ether)
                : bidERC.mul(executionPrice) + bidERC.mul(shortPrice).mul(5 ether);
            uint256 zethTreasuryTithe = zethReward.mul(diamond.getTithe(vault));
            uint256 zethCollateralReward = zethReward - zethTreasuryTithe;
            uint256 zethYieldRate = zethCollateralReward.div(zethCollateral);
            assertEq(
                diamond.getVaultUserStruct(vault, tapp).ethEscrowed,
                zethTreasuryTithe,
                "1"
            );
            assertEq(diamond.getVaultStruct(vault).zethCollateral, zethCollateral, "2");
            assertEq(diamond.getAssetStruct(asset).zethCollateral, zethCollateral);
            assertEq(diamond.getVaultStruct(vault).zethYieldRate, zethYieldRate, "3");
            assertEq(
                diamond.getVaultStruct(vault).zethCollateralReward,
                zethCollateralReward,
                "4"
            );
            assertEq(diamond.getVaultStruct(vault).dittoMatchedShares, shares, "5");
            uint256 zethUserReward = distributeYield(receiver);
            vm.prank(receiver);
            diamond.withdrawDittoReward(vault);
            uint256 mReward =
                diamond.getVaultStruct(vault).dittoShorterRate * (skipTime + 1);
            uint256 userReward = zethUserReward.mul(mReward).div(zethCollateralReward) - 1;
            assertEq(ditto.balanceOf(receiver), userReward, "6");
        }

        {
            uint256 uReward = diamond.getVaultStruct(vault).dittoMatchedRate
                * (skipTime / 1 days * 1 days);
            uint256 uShares =
                diamond.getVaultUserStruct(vault, sharesUser).dittoMatchedShares;
            uint256 totalShares = diamond.getVaultStruct(vault).dittoMatchedShares;
            uint256 dittoPrev = ditto.balanceOf(sharesUser);
            uint256 userReward = dittoPrev == 0
                ? (uShares - 1).mul(uReward).div(totalShares) - 1
                : (uShares - 1).mul(uReward).div(totalShares);
            claimDittoMatchedReward(sharesUser);
            withdrawDittoReward(sharesUser);
            assertEq(ditto.balanceOf(sharesUser) - dittoPrev, userReward, "7");
        }
    }

    function testTitheReverts() public {
        vm.prank(owner);
        vm.expectRevert(Errors.InvalidTithe.selector);
        diamond.setTithe(vault, 33_34);
    }

    function testNoYieldReturn() public {
        uint256 zethTotal = diamond.getZethTotal(vault);
        diamond.updateYield(vault);
        assertEq(diamond.getZethTotal(vault), zethTotal);

        deal(_steth, _bridgeSteth, 1999 ether); // Prev balance was 2000
        zethTotal = diamond.getZethTotal(vault);
        diamond.updateYield(vault);
        assertEq(diamond.getZethTotal(vault), zethTotal);
    }

    function testCanInitializeState() public {
        assertEq(diamond.getZethTotal(vault), 4000 ether);
        assertEq(diamond.getVaultStruct(vault).zethTotal, 4000 ether);
        assertEq(diamond.getVaultUserStruct(vault, tapp).ethEscrowed, 0);
        assertEq(diamond.getVaultStruct(vault).zethCollateral, 0);
        assertEq(diamond.getAssetStruct(asset).zethCollateral, 0);
        assertEq(diamond.getVaultStruct(vault).zethYieldRate, 0);
        assertEq(diamond.getVaultUserStruct(vault, sender).dittoMatchedShares, 0);
        assertEq(diamond.getVaultUserStruct(vault, sender).dittoReward, 0);
        assertEq(ditto.balanceOf(sender), 0);
        assertEq(reth.getExchangeRate(), 1 ether);
    }

    function testCancels() public {
        vm.startPrank(sender);
        // Cancel Bid
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        cancelBid(100);
        testCanInitializeState();
        // Cancel Short
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        cancelShort(101);
        testCanInitializeState();
    }

    function testExitShortAncillary() public {
        vm.startPrank(sender);
        // Exit Short Wallet Bid-Ask
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        exitShortWalletAsserts();
        // Exit Short Wallet Ask-Bid
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        exitShortWalletAsserts();
        // Exit Short Escrow Bid-Ask
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        exitShortEscrowAsserts();
        // Exit Short Escrow Ask-Bid
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        exitShortEscrowAsserts();
    }

    function testExitShortPrimaryWithAsk() public {
        vm.startPrank(sender);
        // Exit Short Bid-Ask-Ask
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT);
        exitShortAsserts(0);
        // Exit Short Ask-Bid-Ask
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT);
        exitShortAsserts(0);
    }

    function testExitShortPrimaryWithShort1() public {
        vm.startPrank(sender);
        // Exit Short Bid-Ask-Short
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        exitShortAsserts(1);
    }

    function testExitShortPrimaryWithShort2() public {
        vm.startPrank(sender);
        // Exit Short Ask-Bid-Short
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        exitShortAsserts(2);
    }

    function testExitShortYieldDisbursement() public {
        // Create shorts and generate yield
        fundLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT * 6, extra);
        fundLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT * 3, sender);
        fundLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // 100
        fundLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // 101
        fundLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // 102
        generateYield(DEFAULT_AMOUNT);
        distributeYield(sender);
        setETH(4000 ether);

        // Setup different exit shorts for receiver
        vm.prank(_diamond);
        token.mint(receiver, DEFAULT_AMOUNT);
        fundLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT * 2, extra);

        // Exit Short wallet

        exitShortWallet(Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT / 2, receiver); // partial
        exitShortWallet(Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT / 2, receiver); // full

        // Exit Short ercEscrowed
        exitShortErcEscrowed(
            Constants.SHORT_STARTING_ID + 1, DEFAULT_AMOUNT / 2, receiver
        ); // partial
        exitShortErcEscrowed(
            Constants.SHORT_STARTING_ID + 1, DEFAULT_AMOUNT / 2, receiver
        ); // full

        // Exit Short primary
        exitShort(
            Constants.SHORT_STARTING_ID + 2, DEFAULT_AMOUNT / 2, DEFAULT_PRICE, receiver
        ); // partial
        exitShort(
            Constants.SHORT_STARTING_ID + 2, DEFAULT_AMOUNT / 2, DEFAULT_PRICE, receiver
        ); // full

        // Exit sender short
        exitShortErcEscrowed(Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT * 2, sender);
        exitShort(Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT, DEFAULT_PRICE, sender);
        // Compare Exit Short disbursements (receiver) with distribute yield (sender)
        assertEq(
            diamond.getVaultUserStruct(vault, sender).ethEscrowed,
            diamond.getVaultUserStruct(vault, receiver).ethEscrowed
        );
    }

    function testMarginCallAncillary() public {
        vm.startPrank(sender);
        // Margin Call Wallet Bid-Ask
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        marginCallWalletAsserts();
        // Margin Call Wallet Ask-Bid
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        marginCallWalletAsserts();
        // Margin Call Escrow Bid-Ask
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        marginCallEscrowAsserts();
        // Margin Call Escrow Ask-Bid
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        marginCallEscrowAsserts();
    }

    function testMarginCallPrimaryWithAsk1() public {
        vm.startPrank(sender);
        // Margin Call Bid-Ask-Ask
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT / 2);
        marginCallAsserts(0);
    }

    function testMarginCallPrimaryWithAsk2() public {
        vm.startPrank(sender);
        // Margin Call Ask-Bid-Ask
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT / 2);
        marginCallAsserts(0);
    }

    function testMarginCallPrimaryWithShort1() public {
        vm.startPrank(sender);
        // Margin Call Bid-Ask-Short
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT / 2);
        marginCallAsserts(1);
    }

    function testMarginCallPrimaryWithShort2() public {
        vm.startPrank(sender);
        // Margin Call Ask-Bid-Short
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT / 2);
        marginCallAsserts(2);
    }

    function testMarginCallYieldDisbursement() public {
        // Create shorts and generate yield
        fundLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT * 7, extra);
        fundLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT, address(4)); // 100
        fundLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT, sender); // 100
        fundLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT, sender); // 101
        fundLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT, sender); // 102
        fundLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // 100
        fundLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // 101
        fundLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // 102
        generateYield(DEFAULT_AMOUNT);

        // Setup different margin calls for receiver
        vm.prank(_diamond);
        token.mint(extra, DEFAULT_AMOUNT * 2);

        fundLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT, extra);
        _setETH(800 ether); // c-ratio = 1.2
        vm.startPrank(extra);
        diamond.flagShort(
            asset, receiver, Constants.SHORT_STARTING_ID + 2, Constants.HEAD
        );
        diamond.flagShort(asset, address(4), Constants.SHORT_STARTING_ID, Constants.HEAD);
        skipTimeAndSetEth({skipTime: TEN_HRS_PLUS, ethPrice: 800 ether});
        vm.stopPrank();
        liquidate(address(4), Constants.SHORT_STARTING_ID, extra); // normlaize gas for remaining liquidations

        // Margin Call wallet
        liquidateWallet(receiver, Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT, extra); // full

        // Margin Call ercEscrowed
        liquidateErcEscrowed(
            receiver, Constants.SHORT_STARTING_ID + 1, DEFAULT_AMOUNT, extra
        ); // full

        // Margin Call primary
        fundLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT / 2, extra);

        liquidate(receiver, Constants.SHORT_STARTING_ID + 2, extra); // partial
        fundLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT / 2, extra);
        liquidate(receiver, Constants.SHORT_STARTING_ID + 2, extra); // full

        // Distribute yield and then exit sender short
        distributeYield(sender);
        _setETH(800 ether); // prevent stale oracle
        fundLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT / 2, extra);
        vm.prank(extra);
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID, Constants.HEAD);
        skipTimeAndSetEth({skipTime: TEN_HRS_PLUS, ethPrice: 800 ether});
        liquidate(sender, Constants.SHORT_STARTING_ID, extra); // partial
        fundLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT / 2, extra);
        liquidate(sender, Constants.SHORT_STARTING_ID, extra); // partial
        liquidateWallet(sender, Constants.SHORT_STARTING_ID + 1, DEFAULT_AMOUNT, extra);
        liquidateErcEscrowed(
            sender, Constants.SHORT_STARTING_ID + 2, DEFAULT_AMOUNT, extra
        );

        // Compare Margin Call disbursements (receiver) with distribute yield (sender)
        assertApproxEqAbs(
            diamond.getVaultUserStruct(vault, sender).ethEscrowed,
            diamond.getVaultUserStruct(vault, receiver).ethEscrowed,
            MAX_DELTA
        );
    }

    function testCanYieldDistributeInitialState() public {
        generateYield();
        assertEq(diamond.getZethTotal(vault), 5000 ether); // 4000/.8
        assertEq(diamond.getVaultStruct(vault).zethTotal, 5000 ether);
        assertEq(diamond.getVaultUserStruct(vault, tapp).ethEscrowed, 1000 ether); // 0 + 4000/4000*1000/10 + 4000/4000*1000*9/10
        assertEq(diamond.getVaultStruct(vault).zethCollateral, 0);
        assertEq(diamond.getAssetStruct(asset).zethCollateral, 0);
        assertEq(diamond.getVaultStruct(vault).zethYieldRate, 0);
    }

    function testCanInitializeStateUnmatchedShort() public {
        vm.prank(sender);
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        assertEq(diamond.getZethTotal(vault), 4000 ether);
        assertEq(diamond.getVaultStruct(vault).zethTotal, 4000 ether);
        assertEq(diamond.getVaultUserStruct(vault, tapp).ethEscrowed, 0);
        assertEq(diamond.getVaultStruct(vault).zethCollateral, 0);
        assertEq(diamond.getAssetStruct(asset).zethCollateral, 0);
        assertEq(diamond.getVaultStruct(vault).zethYieldRate, 0);
    }

    function testCanInitializeStateMatchedBid() public {
        vm.prank(sender);
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        vm.prank(receiver);
        createLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT);
        testCanInitializeState();
    }

    function testCanYieldDistributeWithUnmatchedShort() public {
        vm.prank(sender);
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        generateYield();
        assertEq(diamond.getZethTotal(vault), 5000 ether); // 4000/.8
        assertEq(diamond.getVaultUserStruct(vault, tapp).ethEscrowed, 1000 ether);
        assertEq(diamond.getVaultStruct(vault).zethCollateral, 0);
        assertEq(diamond.getAssetStruct(asset).zethCollateral, 0);
        assertEq(diamond.getVaultStruct(vault).zethYieldRate, 0);
    }

    function testCanYieldDistributeWithMatchedShortFullBidShort() public {
        oneYieldDistribution(
            DEFAULT_PRICE, 200000 ether, DEFAULT_PRICE, 400000 ether, BID_FIRST
        );
    }

    function testCanYieldDistributeWithMatchedShortFullShortBid() public {
        oneYieldDistribution(
            DEFAULT_PRICE, 200000 ether, DEFAULT_PRICE, 400000 ether, SHORT_FIRST
        );
    }

    function testCanYieldDistributeWithMatchedShortFullBidShortDiffPrice() public {
        oneYieldDistribution(
            DEFAULT_PRICE + 1, 200000 ether, DEFAULT_PRICE, 400000 ether, BID_FIRST
        );
    }

    function testCanYieldDistributeWithMatchedShortFullShortBidDiffPrice() public {
        oneYieldDistribution(
            DEFAULT_PRICE + 1, 200000 ether, DEFAULT_PRICE, 400000 ether, SHORT_FIRST
        );
    }

    function testCanYieldDistributeWithMatchedShortPartialBidShort() public {
        oneYieldDistribution(
            DEFAULT_PRICE, 400000 ether, DEFAULT_PRICE, 720000 ether, BID_FIRST
        );
    }

    function testCanYieldDistributeWithMatchedShortPartialShortBid() public {
        oneYieldDistribution(
            DEFAULT_PRICE, 400000 ether, DEFAULT_PRICE, 720000 ether, SHORT_FIRST
        );
    }

    function testCanYieldDistributeWithMatchedShortPartialBidShortDiffPrice() public {
        oneYieldDistribution(
            DEFAULT_PRICE + 1, 400000 ether, DEFAULT_PRICE, 720000 ether, BID_FIRST
        );
    }

    function testCanYieldDistributeWithMatchedShortPartialShortBidDiffPrice() public {
        oneYieldDistribution(
            DEFAULT_PRICE + 1, 400000 ether, DEFAULT_PRICE, 720000 ether, SHORT_FIRST
        );
    }

    function testCanYieldDistributeWithMatchedShortExactBidShort() public {
        oneYieldDistribution(
            DEFAULT_PRICE, 600000 ether, DEFAULT_PRICE, 600000 ether, BID_FIRST
        );
    }

    function testCanYieldDistributeWithMatchedShortExactShortBid() public {
        oneYieldDistribution(
            DEFAULT_PRICE, 600000 ether, DEFAULT_PRICE, 600000 ether, SHORT_FIRST
        );
    }

    function testCanYieldDistributeWithMatchedShortExactBidShortDiffPrice() public {
        oneYieldDistribution(
            DEFAULT_PRICE + 1, 600000 ether, DEFAULT_PRICE, 600000 ether, BID_FIRST
        );
    }

    function testCanYieldDistributeWithMatchedShortExactShortBidDiffPrice() public {
        oneYieldDistribution(
            DEFAULT_PRICE + 1, 600000 ether, DEFAULT_PRICE, 600000 ether, SHORT_FIRST
        );
    }

    function testCanYieldDistributeWith2ShortersAnd2Distributions() public {
        vm.prank(extra);
        createLimitBid(DEFAULT_PRICE, 400000 ether); // 100
        // First Short First Shorter
        vm.prank(sender);
        createLimitShort(DEFAULT_PRICE, 200000 ether); // 50
        // First Short Second Shorter
        vm.prank(receiver);
        createLimitShort(DEFAULT_PRICE, 200000 ether); // 50

        if (!distributed) {
            skip(9000001);
        } else {
            skip(9000001 - skipTime * 2);
        }

        generateYield(1000 ether);
        rewind(yieldEligibleTime);
        uint256 senderReward = distributeYield(sender);
        withdrawDittoReward(sender);
        assertEq(senderReward, 450 ether, "1"); // 0.9(1000)/2
        assertEq(diamond.getVaultUserStruct(vault, sender).ethEscrowed, 1200 ether, "2"); // 1000 - 50*5 + 450
        assertEq(ditto.balanceOf(sender), 4500000, "3");
        assertEq(
            getShortRecord(sender, Constants.SHORT_STARTING_ID).zethYieldRate,
            900 ether / 600,
            "4"
        ); // 0.9(1000) / (300 + 300)
        assertEq(
            getShortRecord(receiver, Constants.SHORT_STARTING_ID).zethYieldRate, 0, "5"
        );

        skip(26460000); // match yield distribution to make calcs easier
        generateYield(3000 ether);
        rewind(yieldEligibleTime);
        senderReward = distributeYield(sender);
        withdrawDittoReward(sender);
        rewind(yieldEligibleTime);
        uint256 receiverReward = distributeYield(receiver);
        withdrawDittoReward(receiver);
        // Vault Totals
        assertEq(diamond.getZethTotal(vault), 4000 ether + 4000 ether);
        assertEq(diamond.getVaultStruct(vault).zethTotal, 4000 ether + 4000 ether);
        assertEq(diamond.getVaultUserStruct(vault, tapp).ethEscrowed, 454 ether); // 0.1 + 0.1/(4000+1)*1 + (4001-0.1)/(4000+1)*1/10
        assertEq(diamond.getVaultStruct(vault).zethCollateral, 600 ether);
        assertEq(diamond.getAssetStruct(asset).zethCollateral, 600 ether);
        assertEq(diamond.getVaultStruct(vault).zethYieldRate, 3546 ether / 600); // 900 + (3000 - (454-100))

        // User totals
        assertEq(senderReward, 1323 ether, "11"); // 3546 / 2 - 450
        assertEq(receiverReward, 1773 ether, "12"); // 3546 / 2
        assertEq(diamond.getVaultUserStruct(vault, sender).ethEscrowed, 2523 ether, "13"); // 1000-50*5+1773
        assertEq(
            diamond.getVaultUserStruct(vault, receiver).ethEscrowed,
            diamond.getVaultUserStruct(vault, sender).ethEscrowed,
            "14"
        );
        assertEq(ditto.balanceOf(sender), 17730000, "15");
        assertEq(ditto.balanceOf(sender), ditto.balanceOf(receiver), "16");
        assertEq(
            getShortRecord(sender, Constants.SHORT_STARTING_ID).zethYieldRate,
            3546 ether / 600,
            "17"
        );
        assertEq(
            getShortRecord(sender, Constants.SHORT_STARTING_ID).zethYieldRate,
            getShortRecord(receiver, Constants.SHORT_STARTING_ID).zethYieldRate,
            "18"
        );
    }

    function testDittoMatchedRewardDistribution() public {
        // r matches after 14 days + 1 seconds
        vm.startPrank(receiver);
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        skipTimeAndSetEth({skipTime: skipTime, ethPrice: 4000 ether});
        createLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT);
        vm.stopPrank();

        // s matches half after 14 days + 1 seconds, cancels half, matches half over 0 seconds
        vm.startPrank(sender);
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        skipTimeAndSetEth({skipTime: skipTime, ethPrice: 4000 ether});
        createLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(0.6 ether));
        cancelBid(100);
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(0.4 ether));
        createLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(0.4 ether));
        vm.stopPrank();

        // Check DittoMatchedReward Points
        uint256 matched1 = DEFAULT_AMOUNT.mulU88(DEFAULT_PRICE);
        uint256 matched2 = DEFAULT_AMOUNT.mulU88(DEFAULT_PRICE).mul(0.6 ether);
        uint256 shares1 = matched1 * (skipTime / 1 days);
        uint256 shares2 = matched2 * (skipTime / 1 days);
        assertEq(
            diamond.getVaultUserStruct(vault, receiver).dittoMatchedShares,
            shares1,
            "shares1"
        );
        assertEq(
            diamond.getVaultUserStruct(vault, sender).dittoMatchedShares,
            shares2,
            "shares2"
        ); // 0.6 ether * (skipTime + 1), // add 1 for each extra skip

        // Generate yield and check that state was returned to normal
        distributed = true;
        testCanYieldDistributeWith2ShortersAnd2Distributions();

        // Check reward claims from matching
        uint256 totalReward = diamond.getOffsetTime() / 1 days * 1 days
            * diamond.getVaultStruct(vault).dittoMatchedRate;
        uint256 balance1 = ditto.balanceOf(receiver);
        uint256 balance2 = ditto.balanceOf(sender);

        claimDittoMatchedReward(receiver);
        withdrawDittoReward(receiver);
        // First ditto reward claim happened in nested test, don't need to sub 1 again here
        uint256 reward1 = (shares1 - 1).mul(totalReward).div(shares1 + shares2);
        assertEq(ditto.balanceOf(receiver), reward1 + balance1, "yield1");

        claimDittoMatchedReward(sender);
        withdrawDittoReward(sender);
        // First ditto reward claim happened in nested test, don't need to sub 1 again here
        uint256 reward2 = (shares2 - 1).mul(totalReward - reward1).div(shares2 + 1);
        assertEq(ditto.balanceOf(sender), reward2 + balance2, "yield2");
    }

    function testDittoMatchedRate() public {
        // r matches after 14 days + 1 seconds
        vm.startPrank(receiver);
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        skip(skipTime);
        createLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT);

        // reward 1 day later should be more than original reward
        assertEq(diamond.getVaultStruct(vault).dittoMatchedTime, 0);
        skip(1 days);
        diamond.claimDittoMatchedReward(vault);

        uint256 dittoMatchedTime = ((skipTime - 1) + 1 days) / 1 days;
        assertEq(diamond.getVaultStruct(vault).dittoMatchedTime, dittoMatchedTime);
    }

    function testMatchedOrderNoShares() public {
        vm.startPrank(receiver);
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT);
        assertEq(diamond.getVaultUserStruct(vault, receiver).dittoMatchedShares, 0);
    }

    function testShortRecordFacetYield() public {
        // create first shorts
        fundLimitBid(DEFAULT_PRICE, 320000 ether, receiver); // 800
        fundLimitShort(DEFAULT_PRICE, 80000 ether, sender); // 20*6 = 120
        fundLimitShort(DEFAULT_PRICE, 80000 ether, extra); // 20*6 = 120
        fundLimitShort(DEFAULT_PRICE, 80000 ether, address(4)); // 20*6 = 120
        fundLimitShort(DEFAULT_PRICE, 160000 ether, receiver); // 20*6 = 120

        generateYield();

        // receiver gets other half of short filled, provides fill for sender's second short
        fundLimitBid(DEFAULT_PRICE, 160000 ether, receiver); // 120 + 20*6 = 240
        // sender second short, combined
        fundLimitShort(DEFAULT_PRICE, 80000 ether, sender); // 120 + 20*6 = 240
        vm.prank(sender);
        combineShorts({
            id1: Constants.SHORT_STARTING_ID,
            id2: Constants.SHORT_STARTING_ID + 1
        });
        // extra increases collateral
        vm.prank(extra);
        diamond.increaseCollateral(asset, Constants.SHORT_STARTING_ID, 120 ether); // 120 + 120 = 240
        // address(4) increases and then decreases collateral
        vm.prank(address(4));
        diamond.increaseCollateral(asset, Constants.SHORT_STARTING_ID, 170 ether);
        skip(yieldEligibleTime);
        vm.prank(address(4));
        diamond.decreaseCollateral(asset, Constants.SHORT_STARTING_ID, 50 ether); // 120 + 170 - 50 = 240

        uint256 reward1 = distributeYield(address(1));
        uint256 reward2 = distributeYield(address(2));
        uint256 reward3 = distributeYield(address(3));
        uint256 reward4 = distributeYield(address(4));

        assertEq(reward1, reward2);
        assertEq(reward1, reward3);
        assertGt(reward1, reward4);

        assertApproxEqAbs(
            diamond.getVaultUserStruct(vault, address(3)).ethEscrowed,
            diamond.getVaultUserStruct(vault, address(4)).ethEscrowed,
            MAX_DELTA
        );
    }

    function testCanYieldDistributeManyShorts() public {
        //@dev force the createLimitShort and createBid to default to internal loop
        MTypes.OrderHint[] memory orderHintArray;
        for (uint160 j = 1; j <= 3; j++) {
            for (uint160 k = 1; k <= 50; k++) {
                orderHintArray = diamond.getHintArray(asset, DEFAULT_PRICE, O.LimitShort);
                vm.prank(address(j));
                diamond.createLimitShort(
                    asset,
                    DEFAULT_PRICE,
                    8000 ether,
                    orderHintArray,
                    shortHintArrayStorage,
                    initialMargin
                ); // 2*5 = 10
                orderHintArray = diamond.getHintArray(asset, DEFAULT_PRICE, O.LimitBid);
                vm.prank(address(j + 1));
                diamond.createBid(
                    asset,
                    DEFAULT_PRICE,
                    40000 ether,
                    Constants.LIMIT_ORDER,
                    orderHintArray,
                    shortHintArrayStorage
                ); // 10
            }
        }
        generateYield();
        distributeYield(address(1));
        distributeYield(address(2));
        distributeYield(address(3));
        assertEq(diamond.getZethTotal(vault), 5000 ether);
        assertEq(diamond.getVaultUserStruct(vault, tapp).ethEscrowed, 100 ether); // 0 + (1000)/10
        assertEq(diamond.getVaultStruct(vault).zethCollateral, 1800 ether); // 12 * 150
        assertEq(diamond.getAssetStruct(asset).zethCollateral, 1800 ether);
        assertEq(diamond.getVaultStruct(vault).zethYieldRate, 900 ether / 1800); // (1000)*9/10
    }

    ///////////YIELD_DELAY_HOURS Tests///////////
    function setUpShortAndCheckInitialEscrowed()
        public
        returns (uint256 collateral, uint256 unlockedCollateral)
    {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        collateral = getShortRecord(sender, Constants.SHORT_STARTING_ID).collateral;
        unlockedCollateral = collateral - DEFAULT_PRICE.mulU80(DEFAULT_AMOUNT);
        assertEq(diamond.getVaultUserStruct(vault, sender).ethEscrowed, 1000 ether);
        assertEq(diamond.getVaultUserStruct(vault, tapp).ethEscrowed, 0);
        return (collateral, unlockedCollateral);
    }

    //Test distributeYield for flashloan scenarios
    function testCantUpdateYieldBeforeDelayInterval() public {
        setUpShortAndCheckInitialEscrowed();
        vm.startPrank(sender);
        generateYield(1 ether);

        address[] memory assets = new address[](1);
        assets[0] = asset;
        vm.expectRevert(Errors.NoYield.selector);
        diamond.distributeYield(assets);

        //skip time (+ 1 hours because everything is operating in hours, not seconds)
        skip(yieldEligibleTime);
        diamond.distributeYield(assets);
    }

    function testCantUpdateYieldBeforeDelayIntervalCombineShorts() public {
        setUpShortAndCheckInitialEscrowed();

        vm.startPrank(sender);
        generateYield(1 ether);

        address[] memory assets = new address[](1);
        assets[0] = asset;
        skip(yieldEligibleTime);
        //@dev setETH to prevent stale oracle revert
        setETH(4000 ether);
        //combine shorts to reset the updatedAt
        vm.stopPrank();
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        vm.startPrank(sender);
        combineShorts({
            id1: Constants.SHORT_STARTING_ID,
            id2: Constants.SHORT_STARTING_ID + 1
        });
        assertEq(
            getShortRecord(sender, Constants.SHORT_STARTING_ID).updatedAt,
            diamond.getOffsetTimeHours()
        );
        vm.expectRevert(Errors.NoYield.selector);
        diamond.distributeYield(assets);

        //try again
        skip(yieldEligibleTime);
        diamond.distributeYield(assets);
    }

    function testCantUpdateYieldBeforeDelayIntervalIncreaseCollateral() public {
        setUpShortAndCheckInitialEscrowed();

        vm.startPrank(sender);
        generateYield(1 ether);

        address[] memory assets = new address[](1);
        assets[0] = asset;
        skip(yieldEligibleTime);

        //increase Collateral to reset the updatedAt
        increaseCollateral(Constants.SHORT_STARTING_ID, 0.0001 ether);
        assertEq(
            getShortRecord(sender, Constants.SHORT_STARTING_ID).updatedAt,
            diamond.getOffsetTimeHours()
        );
        vm.expectRevert(Errors.NoYield.selector);
        diamond.distributeYield(assets);

        //try again
        skip(yieldEligibleTime);
        diamond.distributeYield(assets);
    }

    function testCantUpdateYieldBeforeDelayIntervalExitShortPartial() public {
        setUpShortAndCheckInitialEscrowed();

        _setETH(2666 ether);
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID, Constants.HEAD);
        vm.startPrank(sender);
        generateYield(1 ether);

        address[] memory assets = new address[](1);
        assets[0] = asset;
        skip(yieldEligibleTime);
        vm.stopPrank();

        //partially exit short to reset the updatedAt
        vm.prank(_diamond);
        token.mint(sender, DEFAULT_AMOUNT);
        exitShortWallet(Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT / 2, sender); //partial
        assertEq(
            getShortRecord(sender, Constants.SHORT_STARTING_ID).updatedAt,
            diamond.getOffsetTimeHours()
        );
        vm.prank(sender);
        vm.expectRevert(Errors.NoYield.selector);
        diamond.distributeYield(assets);

        //try again
        skip(yieldEligibleTime);
        vm.prank(sender);
        diamond.distributeYield(assets);
    }

    //Test disburseCollateral for flashloan scenarios
    function checkTappDidNotReceiveYield() public {
        assertEq(diamond.getVaultUserStruct(vault, tapp).ethEscrowed, 0);
    }

    function checkTappReceivedYield() public {
        assertGt(diamond.getVaultUserStruct(vault, tapp).ethEscrowed, 0);
    }

    function testCantDisburseCollateralBeforeDelayIntervalExitShortTappGetsYield()
        public
    {
        (, uint256 unlockedCollateral) = setUpShortAndCheckInitialEscrowed();

        vm.prank(owner);
        diamond.setTithe(vault, 0);
        generateYield(1 ether);
        fundLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT, extra);
        exitShort(Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT, DEFAULT_PRICE, sender);

        assertEq(
            diamond.getVaultUserStruct(vault, sender).ethEscrowed,
            1000 ether + unlockedCollateral
        );
        checkTappReceivedYield();
    }

    function testCantDisburseCollateralBeforeDelayIntervalExitShortShorterGetsYield()
        public
    {
        (, uint256 unlockedCollateral) = setUpShortAndCheckInitialEscrowed();

        vm.prank(owner);
        diamond.setTithe(vault, 0);
        generateYield(1 ether);
        skip(yieldEligibleTime);
        setETH(4000 ether);
        fundLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT, extra);
        exitShort(Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT, DEFAULT_PRICE, sender);

        assertGt(
            diamond.getVaultUserStruct(vault, sender).ethEscrowed,
            1000 ether + unlockedCollateral
        );
        checkTappDidNotReceiveYield();
    }

    function testCantDisburseCollateralBeforeDelayIntervalIncreaseCollateralTappGetsYield(
    ) public {
        setUpShortAndCheckInitialEscrowed();

        vm.prank(owner);
        diamond.setTithe(vault, 0);
        generateYield(10 ether);
        vm.prank(sender);
        decreaseCollateral(Constants.SHORT_STARTING_ID, 1 wei);

        assertEq(
            diamond.getVaultUserStruct(vault, sender).ethEscrowed, 1000 ether + 1 wei
        );
        checkTappReceivedYield();
    }

    function testCantDisburseCollateralBeforeDelayIntervalIncreaseCollateralShorterGetsYield(
    ) public {
        setUpShortAndCheckInitialEscrowed();

        vm.prank(owner);
        diamond.setTithe(vault, 0);
        generateYield(10 ether);
        skip(yieldEligibleTime);
        vm.prank(sender);
        decreaseCollateral(Constants.SHORT_STARTING_ID, 1 wei);

        assertGt(
            diamond.getVaultUserStruct(vault, sender).ethEscrowed, 1000 ether + 1 wei
        );
        checkTappDidNotReceiveYield();
    }

    //@dev shorter liquidated by primary margin call will always get yield via disburse
    function testCantDisburseCollateralBeforeDelayIntervalPrimaryLiquidateShorterGetsYield(
    ) public {
        (uint256 collateral,) = setUpShortAndCheckInitialEscrowed();

        vm.prank(owner);
        diamond.setTithe(vault, 0);
        generateYield(1 ether);

        fundLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT, extra);
        setETH(2666 ether);
        vm.prank(extra);
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID, Constants.HEAD);
        skipTimeAndSetEth({skipTime: TEN_HRS_PLUS, ethPrice: 2666 ether});
        vm.prank(extra);
        (uint256 gas, uint256 ethFilled) = diamond.liquidate(
            asset, sender, Constants.SHORT_STARTING_ID, shortHintArrayStorage
        );

        uint256 tappFeePct = diamond.getAssetNormalizedStruct(asset).tappFeePct;
        uint256 callerFeePct = diamond.getAssetNormalizedStruct(asset).callerFeePct;
        uint256 tappFee = tappFeePct.mul(ethFilled);
        uint256 callerFee = callerFeePct.mul(ethFilled);

        assertGt(
            diamond.getVaultUserStruct(vault, sender).ethEscrowed,
            1000 ether + (collateral - ethFilled - gas - tappFee - callerFee)
        );
        assertEq(diamond.getVaultUserStruct(vault, tapp).ethEscrowed, tappFee);
    }

    function testCantDisburseCollateralBeforeDelayIntervalLiquidateWalletTappGetsYield()
        public
    {
        (uint256 collateral,) = setUpShortAndCheckInitialEscrowed();

        vm.prank(owner);
        diamond.setTithe(vault, 0);
        generateYield(1 ether);

        setETH(750 ether);
        uint256 ercDebtAtOraclePrice = getShortRecord(sender, Constants.SHORT_STARTING_ID)
            .ercDebt
            .mul(diamond.getAssetPrice(asset));
        vm.prank(_diamond);
        token.mint(extra, DEFAULT_AMOUNT);
        liquidateWallet(sender, Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT, extra);

        assertEq(
            diamond.getVaultUserStruct(vault, sender).ethEscrowed,
            1000 ether + (collateral - ercDebtAtOraclePrice)
        );
        checkTappReceivedYield();
    }

    function testCantDisburseCollateralBeforeDelayIntervalLiquidateWalletShorterGetsYield(
    ) public {
        (uint256 collateral,) = setUpShortAndCheckInitialEscrowed();

        vm.prank(owner);
        diamond.setTithe(vault, 0);
        generateYield(1 ether);

        setETH(750 ether);

        uint256 ercDebtAtOraclePrice = getShortRecord(sender, Constants.SHORT_STARTING_ID)
            .ercDebt
            .mul(diamond.getAssetPrice(asset));
        vm.prank(_diamond);
        token.mint(extra, DEFAULT_AMOUNT);
        skip(yieldEligibleTime);
        liquidateWallet(sender, Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT, extra);

        assertGt(
            diamond.getVaultUserStruct(vault, sender).ethEscrowed,
            1000 ether + (collateral - ercDebtAtOraclePrice)
        );
        checkTappDidNotReceiveYield();
    }

    function testCantDisburseCollateralBeforeDelayIntervalLiquidateErcEscrowedTappGetsYield(
    ) public {
        (uint256 collateral,) = setUpShortAndCheckInitialEscrowed();

        vm.prank(owner);
        diamond.setTithe(vault, 0);
        generateYield(1 ether);

        setETH(750 ether);
        uint256 ercDebtAtOraclePrice = getShortRecord(sender, Constants.SHORT_STARTING_ID)
            .ercDebt
            .mul(diamond.getAssetPrice(asset));

        liquidateErcEscrowed(sender, Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT, extra);

        assertEq(
            diamond.getVaultUserStruct(vault, sender).ethEscrowed,
            1000 ether + (collateral - ercDebtAtOraclePrice)
        );
        checkTappReceivedYield();
    }

    function testCantDisburseCollateralBeforeDelayIntervalLiquidateErcEscrowedShorterGetsYield(
    ) public {
        (uint256 collateral,) = setUpShortAndCheckInitialEscrowed();

        vm.prank(owner);
        diamond.setTithe(vault, 0);
        generateYield(1 ether);

        setETH(750 ether);
        skip(yieldEligibleTime);
        uint256 ercDebtAtOraclePrice = getShortRecord(sender, Constants.SHORT_STARTING_ID)
            .ercDebt
            .mul(diamond.getAssetPrice(asset));

        liquidateErcEscrowed(sender, Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT, extra);

        assertGt(
            diamond.getVaultUserStruct(vault, sender).ethEscrowed,
            1000 ether + (collateral - ercDebtAtOraclePrice)
        );
        checkTappDidNotReceiveYield();
    }

    function testDittoRewardPenalty() public {
        // Create shortRecords
        vm.prank(address(1));
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT * 4);
        vm.prank(address(1));
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        vm.prank(address(2));
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        vm.prank(address(3));
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        vm.prank(address(4));
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);

        // Modify this shortRecord before time skip
        vm.prank(address(2));
        diamond.increaseCollateral(
            asset, Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT.mulU88(DEFAULT_PRICE) * 6
        );

        generateYield(1 ether);
        // Prepare distributeYield
        skip(yieldEligibleTime);
        address[] memory assets = new address[](1);
        assets[0] = asset;

        // Base Case
        STypes.ShortRecord memory short =
            getShortRecord(address(1), Constants.SHORT_STARTING_ID);
        assertEq(diamond.getCollateralRatio(asset, short), 6 ether);
        vm.prank(address(1));
        diamond.distributeYield(assets);
        // Double CR through increase
        short = getShortRecord(address(2), Constants.SHORT_STARTING_ID);
        assertEq(diamond.getCollateralRatio(asset, short), 12 ether);
        vm.prank(address(2));
        diamond.distributeYield(assets);
        // Double CR through oracle price change
        _setETH(8000 ether);
        short = getShortRecord(address(3), Constants.SHORT_STARTING_ID);
        assertEq(diamond.getCollateralRatio(asset, short), 12 ether);
        vm.prank(address(3));
        diamond.distributeYield(assets);
        // Halve doubled CR though decrease
        vm.prank(address(4));
        diamond.decreaseCollateral(
            asset, Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT.mulU88(DEFAULT_PRICE) * 3
        );
        short = getShortRecord(address(4), Constants.SHORT_STARTING_ID);
        assertEq(diamond.getCollateralRatio(asset, short), 6 ether);
        vm.prank(address(4));
        diamond.distributeYield(assets);

        // Check absolute ditto reward for base case
        uint256 dittoRewardShortersTotal =
            diamond.getVaultStruct(vault).dittoShorterRate * (yieldEligibleTime + 1);
        uint256 dittoRewardBaseCase = dittoRewardShortersTotal / 5 - 1; //
        assertEq(diamond.getDittoReward(vault, address(1)), dittoRewardBaseCase);
        // short1 = short2 bc increasing collateral doesnt affect relative ditto reward
        assertEq(
            diamond.getDittoReward(vault, address(1)),
            diamond.getDittoReward(vault, address(2))
        );
        // short3 = short4 bc decreasing collateral doesnt affect relative ditto reward
        assertEq(
            diamond.getDittoReward(vault, address(3)),
            diamond.getDittoReward(vault, address(4))
        );
        // short1,short2 = short3,short4 x 2 bc of CR difference
        assertEq(
            diamond.getDittoReward(vault, address(1)),
            diamond.getDittoReward(vault, address(3)) * 2 + 1
        );
    }
}
