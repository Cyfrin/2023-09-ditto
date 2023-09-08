// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.21;

import {U256, Math128, U88, U80} from "contracts/libraries/PRBMathHelper.sol";
import {F} from "contracts/libraries/DataTypes.sol";

import {MarginCallHelper} from "test/utils/MarginCallHelper.sol";

import {console} from "contracts/libraries/console.sol";

contract MarginCallGeneralTest is MarginCallHelper {
    using U256 for uint256;
    using Math128 for uint128;
    using U88 for uint88;
    using U80 for uint80;

    function setUp() public override {
        super.setUp();
    }

    function testgasFeeAwarded() public {
        // Prepare for margin call
        prepareAsk(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(0.5 ether));

        //price in USD (min eth for liquidation ratio Formula: .0015P = 4 => P = 2666.67
        MarginCallStruct memory m = simulateLiquidation(r, s, 2666 ether, extra, sender);

        //did caller get fee?
        e.ethEscrowed = m.gasFee + m.callerFee;
        assertStruct(extra, e);
    }

    //testing max function
    function testForcedBidMaxforcedBidPriceBufferGtTenPct() public {
        uint256 forcedBidPriceBuffer = createShortsAndChangeforcedBidPriceBuffer({
            changeLL: INCREASE_LIQUIDATION_LIMIT
        });
        assertEq(forcedBidPriceBuffer, 1.2 ether);
        confirmBuyer({buyer: SHORTER});
    }

    function testForcedBidMaxforcedBidPriceBufferLtTenPct() public {
        uint256 forcedBidPriceBuffer = createShortsAndChangeforcedBidPriceBuffer({
            changeLL: DECREASE_LIQUIDATION_LIMIT
        });
        assertEq(forcedBidPriceBuffer, 1 ether);
        confirmBuyer({buyer: SHORTER});
    }

    function testForcedBidMaxLiquidationTappBuys() public {
        uint256 forcedBidPriceBuffer = createShortsAndChangeforcedBidPriceBuffer({
            changeLL: INCREASE_LIQUIDATION_LIMIT
        });
        assertEq(forcedBidPriceBuffer, 1.2 ether);
        confirmBuyer({buyer: TAPP});
    }

    //Testing Gas of making many forced bids
    function testLiquidateForcedBidFee() public {
        prepareAsk(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(0.5 ether));
        depositEth(tapp, DEFAULT_TAPP);

        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(0.5 ether), receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(0.5 ether), receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(0.5 ether), receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(0.5 ether), receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(0.5 ether), receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(0.5 ether), receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(0.5 ether), receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(0.5 ether), receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(0.5 ether), receiver);

        //6 ether from the different "fundLimit" functions
        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 1,
            _collateral: DEFAULT_PRICE.mul(DEFAULT_AMOUNT) * 6,
            _ercDebt: DEFAULT_AMOUNT,
            _ercDebtAsset: DEFAULT_AMOUNT,
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT.mul(6 ether)
        });

        // Margin Call
        MarginCallStruct memory m =
            simulateLiquidation(r, s, 2666 ether, receiver, sender);

        // + default price because of what was received from fundLimitAsk
        r.ethEscrowed = DEFAULT_PRICE.mul(DEFAULT_AMOUNT) + m.gasFee + m.callerFee;
        assertStruct(receiver, r);
        assertTrue(m.gasFee > 0);
        s.ethEscrowed = (DEFAULT_PRICE.mul(DEFAULT_AMOUNT) * 6) - m.ethFilled - m.gasFee
            - m.callerFee - m.tappFee;
        assertStruct(sender, s);

        // 5 from receiver depositing usd for fundLimitAsk (-1 from burn)
        //collateral and ercDebt are gone
        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 0,
            _collateral: 0,
            _ercDebt: 0,
            _ercDebtAsset: 0,
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT.mul(5 ether)
        });
    }

    function marketShutdown(int256 ethPrice) public {
        // Create 3 short records
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 3, sender);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, extra);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, address(4));
        assertTrue(diamond.getAssetStruct(asset).frozen == F.Unfrozen);

        // Lower c-ratio of the asset
        _setETH(ethPrice);
        uint256 cRatio = diamond.getAssetCollateralRatio(asset) >= 1 ether
            ? 1 ether
            : diamond.getAssetCollateralRatio(asset);
        uint256 assetCollateral = diamond.getAssetStruct(asset).zethCollateral;

        // Shutdown the (almost) undercollateralized asset
        diamond.shutdownMarket(asset);
        uint256 tappBalance =
            assetCollateral - diamond.getAssetStruct(asset).zethCollateral;
        assertEq(diamond.getVaultUserStruct(vault, tapp).ethEscrowed, tappBalance); // collateral over c-ratio 1 given to TAPP
        assertEq(diamond.getAssetCollateralRatio(asset), cRatio); // c-ratio shaved down to 1.0
        assertTrue(diamond.getAssetStruct(asset).frozen == F.Permanent);

        uint256 ercAmount = DEFAULT_AMOUNT.mul(diamond.getAssetPrice(asset)).mul(cRatio);

        // Receiver redeems erc from wallet
        assertEq(diamond.getVaultUserStruct(vault, receiver).ethEscrowed, 0);
        vm.prank(receiver);
        diamond.withdrawAsset(asset, DEFAULT_AMOUNT);
        redeemErc(DEFAULT_AMOUNT, 0, receiver);
        assertEq(diamond.getVaultUserStruct(vault, receiver).ethEscrowed, ercAmount);

        // Extra redeems erc from escrow
        assertEq(diamond.getVaultUserStruct(vault, extra).ethEscrowed, 0);
        redeemErc(0, DEFAULT_AMOUNT, extra);
        assertEq(diamond.getVaultUserStruct(vault, extra).ethEscrowed, ercAmount);

        // Address4 redeems erc from wallet and escrow
        assertEq(diamond.getVaultUserStruct(vault, address(4)).ethEscrowed, 0);
        vm.prank(address(4));
        diamond.withdrawAsset(asset, DEFAULT_AMOUNT / 2);
        redeemErc(DEFAULT_AMOUNT / 2, DEFAULT_AMOUNT / 2, address(4));
        assertEq(diamond.getVaultUserStruct(vault, address(4)).ethEscrowed, ercAmount);
    }

    function testMarketShutdownCRatioGt1() public {
        marketShutdown(700 ether); // c-ratio 1.05
    }

    function testMarketShutdownCRatioLt1() public {
        marketShutdown(600 ether); // c-ratio 0.90
    }
}
