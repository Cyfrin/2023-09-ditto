// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.21;

import {U256, Math128, U88, U80} from "contracts/libraries/PRBMathHelper.sol";

import {Constants} from "contracts/libraries/Constants.sol";
import {STypes} from "contracts/libraries/DataTypes.sol";

import {PrimaryScenarios} from "test/utils/TestTypes.sol";
import {MarginCallGeneralTest} from "test/MarginCallGeneral.t.sol";
import {console} from "contracts/libraries/console.sol";

//@dev Test what happens when we perform forced bid on a short instead of an ask
contract MarginCallShortsTest is MarginCallGeneralTest {
    using U256 for uint256;
    using Math128 for uint128;
    using U88 for uint88;
    using U80 for uint80;

    function fullyLiquidateShortPrimary(PrimaryScenarios scenario, address caller)
        public
        returns (MarginCallStruct memory m, STypes.ShortRecord memory shortRecord)
    {
        int256 ethPrice;
        if (scenario == PrimaryScenarios.CRatioBetween110And200) ethPrice = 1000 ether;
        else if (scenario == PrimaryScenarios.CRatioBelow110) ethPrice = 730 ether;

        prepareShort({askAmount: DEFAULT_AMOUNT, ethPrice: ethPrice});
        shortRecord = getShortRecord(sender, Constants.SHORT_STARTING_ID);

        //give eth to tapp for buyback
        depositEth(tapp, FUNDED_TAPP);
        t.ethEscrowed = FUNDED_TAPP;
        t.ercEscrowed = 0;
        assertStruct(tapp, t);

        //check balance before liquidate
        //1 from short minting
        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 1,
            _collateral: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT) * 6,
            _ercDebt: DEFAULT_AMOUNT,
            _ercDebtAsset: DEFAULT_AMOUNT,
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT
        });

        //Margin Call
        m = simulateLiquidation(r, s, ethPrice, caller, sender); //roughly get cratio between 1.1 and 2

        if (scenario == PrimaryScenarios.CRatioBetween110And200) {
            if (caller == receiver) {
                t.ethEscrowed = FUNDED_TAPP + m.tappFee;
                s.ethEscrowed = shortRecord.collateral - m.ethFilled - m.gasFee
                    - m.tappFee - m.callerFee;
                r.ethEscrowed = m.callerFee + m.gasFee;
            } else if (caller == tapp) {
                t.ethEscrowed = FUNDED_TAPP + m.tappFee + m.callerFee + m.gasFee;
                s.ethEscrowed = shortRecord.collateral - m.ethFilled - m.gasFee
                    - m.tappFee - m.callerFee;
            }
        } else if (scenario == PrimaryScenarios.CRatioBelow110) {
            if (caller == receiver) {
                t.ethEscrowed = FUNDED_TAPP - m.ethFilled - m.gasFee - m.callerFee
                    + shortRecord.collateral;
                s.ethEscrowed = 0; //lose all collateral
                r.ethEscrowed = m.callerFee + m.gasFee;
            } else if (caller == tapp) {
                t.ethEscrowed = FUNDED_TAPP - m.ethFilled + shortRecord.collateral; //caller and gas fees offset
                s.ethEscrowed = 0; //lose all collateral
            }
        }
        e.ethEscrowed = 0; //ethEscrowed locked up as collateral for matched short
        r.ercEscrowed = DEFAULT_AMOUNT; //from first bid and short match
        //check balances
        assertStruct(tapp, t);
        assertStruct(sender, s);
        assertStruct(receiver, r);
        assertStruct(extra, e);
    }

    function testPrimaryFullLiquidateCratioScenario1FromShort() public {
        fullyLiquidateShortPrimary({
            scenario: PrimaryScenarios.CRatioBetween110And200,
            caller: receiver
        });

        // check balance after liquidate
        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 0,
            _collateral: 0, //collateral and ercDebt are gone
            _ercDebt: 0,
            _ercDebtAsset: DEFAULT_AMOUNT,
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT //1 from short minting match
        });
    }

    function testPrimaryFullLiquidateCratioScenario1CalledByTappFromShort() public {
        fullyLiquidateShortPrimary({
            scenario: PrimaryScenarios.CRatioBetween110And200,
            caller: tapp
        });

        //check balance after liquidate
        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 0,
            _collateral: 0, //collateral and ercDebt are gone
            _ercDebt: 0,
            _ercDebtAsset: DEFAULT_AMOUNT,
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT //1 from short minting match
        });
    }

    //@dev: Scenario 1: cratio < 1.1
    function testPrimaryFullLiquidateCratioScenario2FromShort() public {
        fullyLiquidateShortPrimary({
            scenario: PrimaryScenarios.CRatioBelow110,
            caller: receiver
        });
        //check balance after liquidate
        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 0,
            _collateral: 0, //collateral and ercDebt are gone
            _ercDebt: 0,
            _ercDebtAsset: DEFAULT_AMOUNT,
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT //1 from short minting match
        });
    }

    function testPrimaryFullLiquidateCratioScenario2CalledByTappFromShort() public {
        fullyLiquidateShortPrimary({
            scenario: PrimaryScenarios.CRatioBelow110,
            caller: tapp
        });

        //check balance after liquidate
        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 0,
            _collateral: 0, //collateral and ercDebt are gone
            _ercDebt: 0,
            _ercDebtAsset: DEFAULT_AMOUNT,
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT //1 from short minting match
        });
    }
}
