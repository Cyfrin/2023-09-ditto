// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.21;

import {U256, Math128, U88, U80} from "contracts/libraries/PRBMathHelper.sol";
import {Constants} from "contracts/libraries/Constants.sol";
import {STypes, SR} from "contracts/libraries/DataTypes.sol";
import {Constants, Vault} from "contracts/libraries/Constants.sol";

import {MarginCallHelper} from "test/utils/MarginCallHelper.sol";
import {PrimaryScenarios} from "test/utils/TestTypes.sol";

import {console} from "contracts/libraries/console.sol";

contract MarginCallPrimaryTest is MarginCallHelper {
    using U256 for uint256;
    using Math128 for uint128;
    using U88 for uint88;
    using U80 for uint80;

    function setUp() public override {
        super.setUp();
    }

    ////////////////C Ratio scenario testing////////////////

    /*
      //@dev: scenarios for below
        primary
        Scenario 1: cratio < 2 and cratio >= 1.1
            a: Short covers all fees
            b: Short covers all fees except gas fee, tapp covers
        Scenario 2: cratio < 1.1
            a: Short covers all fees
            b: Short covers all fees except gas fee, tapp covers
        Scenario 3: cratio < 1.1 and black swan
            a: Black Swan but short covers all fees
            b: Black Swan but short covers all fees except gas fee, tapp covers
    */

    // Primary Liquidate Scenario Testing
    ///////Full///////
    //@dev: Scenario A: Short covers all fees
    function fullyLiquidateShortPrimaryScenarioA(
        PrimaryScenarios scenario,
        address caller
    ) public returns (MarginCallStruct memory m, STypes.ShortRecord memory shortRecord) {
        if (scenario == PrimaryScenarios.CRatioBelow110BlackSwan) {
            // Dummy short to make sure ercDebtAsset > 0 during liquidation
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, address(4));
            fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, address(4));
        }

        prepareAsk({askPrice: DEFAULT_PRICE, askAmount: DEFAULT_AMOUNT});
        shortRecord = getShortRecord(sender, Constants.SHORT_STARTING_ID);

        uint256 ercDebtAsset;
        if (scenario != PrimaryScenarios.CRatioBelow110BlackSwan) {
            depositEth(tapp, FUNDED_TAPP);
            t.ethEscrowed = FUNDED_TAPP;
            assertStruct(tapp, t);
            ercDebtAsset = DEFAULT_AMOUNT;
        } else {
            ercDebtAsset = DEFAULT_AMOUNT.mulU88(2 ether);
        }

        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 1,
            _collateral: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT).mul(6 ether),
            _ercDebt: DEFAULT_AMOUNT.mulU88(1 ether),
            _ercDebtAsset: ercDebtAsset,
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT.mulU88(2 ether) //1 from short minting, 1 from receiver depositing usd for fundLimitAsk
        });

        int256 ethPrice;
        if (scenario == PrimaryScenarios.CRatioBetween110And200) ethPrice = 734 ether;
        else ethPrice = 733 ether;
        //Margin Call
        m = simulateLiquidation(r, s, ethPrice, caller, sender);

        if (scenario == PrimaryScenarios.CRatioBetween110And200) {
            if (caller == receiver) {
                t.ethEscrowed = FUNDED_TAPP + m.tappFee;
                s.ethEscrowed = shortRecord.collateral - m.ethFilled - m.gasFee
                    - m.tappFee - m.callerFee;
                r.ethEscrowed = m.ethFilled + m.callerFee + m.gasFee;
            } else if (caller == tapp) {
                t.ethEscrowed = FUNDED_TAPP + m.tappFee + m.callerFee + m.gasFee;
                s.ethEscrowed = shortRecord.collateral - m.ethFilled - m.gasFee
                    - m.tappFee - m.callerFee;
                r.ethEscrowed = m.ethFilled; //receiver was asker for margin call
            }
        } else if (scenario == PrimaryScenarios.CRatioBelow110) {
            if (caller == receiver) {
                t.ethEscrowed = FUNDED_TAPP - m.ethFilled - m.gasFee - m.callerFee
                    + shortRecord.collateral;
                s.ethEscrowed = 0; //lose all collateral
                r.ethEscrowed = m.ethFilled + m.callerFee + m.gasFee;
            } else if (caller == tapp) {
                t.ethEscrowed = FUNDED_TAPP - m.ethFilled + shortRecord.collateral; //caller and gas fees offset
                s.ethEscrowed = 0; //lose all collateral
                r.ethEscrowed = m.ethFilled;
            }
        } else if (scenario == PrimaryScenarios.CRatioBelow110BlackSwan) {
            if (caller == receiver) {
                t.ethEscrowed =
                    (shortRecord.collateral - m.ethFilled) - m.gasFee - m.callerFee;
                s.ethEscrowed = 0; //lose all collateral
                r.ethEscrowed = m.ethFilled + m.callerFee + m.gasFee;
            } else if (caller == tapp) {
                t.ethEscrowed = (shortRecord.collateral - m.ethFilled);
                s.ethEscrowed = 0; //lose all collateral
                r.ethEscrowed = m.ethFilled;
            }
        }

        r.ercEscrowed = DEFAULT_AMOUNT; //from first bid and short match
        //check balances
        assertStruct(tapp, t);
        assertStruct(sender, s);
        assertStruct(receiver, r);
    }

    //@dev: Scenario 1: cratio < 2 and cratio >= 1.1
    function testPrimaryFullLiquidateCratioScenario1A() public {
        fullyLiquidateShortPrimaryScenarioA({
            scenario: PrimaryScenarios.CRatioBetween110And200,
            caller: receiver
        });

        //check balance after liquidate
        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 0,
            _collateral: 0,
            _ercDebt: 0,
            _ercDebtAsset: 0,
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT //1 from short minting
        });
    }

    function testPrimaryFullLiquidateCratioScenario1ACalledBytapp() public {
        fullyLiquidateShortPrimaryScenarioA({
            scenario: PrimaryScenarios.CRatioBetween110And200,
            caller: tapp
        });

        //check balance after liquidate
        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 0,
            _collateral: 0,
            _ercDebt: 0,
            _ercDebtAsset: 0,
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT //1 from short minting
        });
    }

    //@dev: Scenario 2: cratio < 1.1
    function testPrimaryFullLiquidateCratioScenario2A() public {
        fullyLiquidateShortPrimaryScenarioA({
            scenario: PrimaryScenarios.CRatioBelow110,
            caller: receiver
        });

        //check balance after liquidate
        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 0,
            _collateral: 0,
            _ercDebt: 0,
            _ercDebtAsset: 0,
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT //1 from short minting
        });
    }

    function testPrimaryFullLiquidateCratioScenario2ACalledBytapp() public {
        fullyLiquidateShortPrimaryScenarioA({
            scenario: PrimaryScenarios.CRatioBelow110,
            caller: tapp
        });
        //check balance after liquidate
        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 0,
            _collateral: 0,
            _ercDebt: 0,
            _ercDebtAsset: 0,
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT //1 from short minting
        });
    }

    //@dev: Scenario 3: cratio < 1.1 black swan
    function testPrimaryFullLiquidateCratioScenario3A() public {
        (MarginCallStruct memory m,) = fullyLiquidateShortPrimaryScenarioA({
            scenario: PrimaryScenarios.CRatioBelow110BlackSwan,
            caller: receiver
        });

        //check balance after liquidate
        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 0,
            _collateral: 0,
            _ercDebt: 0,
            _ercDebtAsset: m.ercDebtSocialized + DEFAULT_AMOUNT, // 1 from dummy short
            _ercDebtRateAsset: m.ercDebtRate,
            _ercAsset: DEFAULT_AMOUNT + m.ercDebtSocialized //1 from short minting
        });
    }

    function testPrimaryFullLiquidateCratioScenario3ACalledBytapp() public {
        (MarginCallStruct memory m,) = fullyLiquidateShortPrimaryScenarioA({
            scenario: PrimaryScenarios.CRatioBelow110BlackSwan,
            caller: tapp
        });
        //check balance after liquidate
        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 0,
            _collateral: 0,
            _ercDebt: 0,
            _ercDebtAsset: m.ercDebtSocialized + DEFAULT_AMOUNT, // 1 from dummy short
            _ercDebtRateAsset: m.ercDebtRate,
            _ercAsset: DEFAULT_AMOUNT + m.ercDebtSocialized //1 from short minting
        });
    }

    //@dev: Scenario B: Short covers all fees except gas fee, tapp covers
    function fullyLiquidateShortPrimaryScenarioB(
        PrimaryScenarios scenario,
        address caller
    ) public returns (MarginCallStruct memory m, STypes.ShortRecord memory shortRecord) {
        if (scenario == PrimaryScenarios.CRatioBelow110BlackSwan) {
            // Dummy short to make sure ercDebtAsset > 0 during liquidation
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, address(4));
            fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, address(4));
        }

        prepareAsk({askPrice: DEFAULT_PRICE, askAmount: DEFAULT_AMOUNT});
        shortRecord = getShortRecord(sender, Constants.SHORT_STARTING_ID);

        uint256 ercDebtAsset;
        if (scenario != PrimaryScenarios.CRatioBelow110BlackSwan) {
            depositEth(tapp, DEFAULT_TAPP);
            t.ethEscrowed = DEFAULT_TAPP;
            assertStruct(tapp, t);
            ercDebtAsset = DEFAULT_AMOUNT;
        } else {
            ercDebtAsset = DEFAULT_AMOUNT.mulU88(2 ether);
        }

        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 1,
            _collateral: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT).mul(6 ether),
            _ercDebt: DEFAULT_AMOUNT.mulU88(1 ether),
            _ercDebtAsset: ercDebtAsset,
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT.mulU88(2 ether) //1 from short minting, 1 from receiver depositing usd for fundLimitAsk
        });

        int256 ethPrice;
        if (scenario == PrimaryScenarios.CRatioBetween110And200) ethPrice = 734 ether;
        else ethPrice = 733 ether;

        // Fake massive gas fee
        vm.fee(1 ether);
        // Margin Call
        m = simulateLiquidation(r, s, ethPrice, caller, sender);

        if (scenario == PrimaryScenarios.CRatioBetween110And200) {
            if (caller == receiver) {
                t.ethEscrowed = DEFAULT_TAPP;
                s.ethEscrowed =
                    shortRecord.collateral - m.ethFilled - m.tappFee - m.callerFee;
                r.ethEscrowed = m.ethFilled + m.callerFee + m.tappFee;
            } else if (caller == tapp) {
                t.ethEscrowed = DEFAULT_TAPP + m.tappFee + m.callerFee;
                s.ethEscrowed =
                    shortRecord.collateral - m.ethFilled - m.tappFee - m.callerFee;
                r.ethEscrowed = m.ethFilled; //receiver was asker for margin call
            }
        } else if (scenario == PrimaryScenarios.CRatioBelow110) {
            if (caller == receiver) {
                t.ethEscrowed = DEFAULT_TAPP + shortRecord.collateral - m.ethFilled
                    - m.callerFee - m.tappFee;
                s.ethEscrowed = 0; //lose all collateral
                r.ethEscrowed = m.ethFilled + m.callerFee + m.tappFee;
            } else if (caller == tapp) {
                t.ethEscrowed = DEFAULT_TAPP + shortRecord.collateral - m.ethFilled; //caller and gas fees offset
                s.ethEscrowed = 0; //lose all collateral
                r.ethEscrowed = m.ethFilled;
            }
        } else if (scenario == PrimaryScenarios.CRatioBelow110BlackSwan) {
            if (caller == receiver) {
                t.ethEscrowed =
                    shortRecord.collateral - m.ethFilled - m.callerFee - m.tappFee;
                s.ethEscrowed = 0; //lose all collateral
                r.ethEscrowed = m.ethFilled + m.callerFee + m.tappFee;
            } else if (caller == tapp) {
                t.ethEscrowed = shortRecord.collateral - m.ethFilled;
                s.ethEscrowed = 0; //lose all collateral
                r.ethEscrowed = m.ethFilled;
            }
        }

        r.ercEscrowed = DEFAULT_AMOUNT; //from first bid and short match
        //check balances
        assertStruct(tapp, t);
        assertStruct(sender, s);
        assertStruct(receiver, r);
    }

    //@dev: Scenario 1: cratio < 2 and cratio >= 1.1
    function testPrimaryFullLiquidateCratioScenario1B() public {
        fullyLiquidateShortPrimaryScenarioB({
            scenario: PrimaryScenarios.CRatioBetween110And200,
            caller: receiver
        });

        //check balance after liquidate
        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 0,
            _collateral: 0,
            _ercDebt: 0,
            _ercDebtAsset: 0,
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT //1 from short minting
        });
    }

    function testPrimaryFullLiquidateCratioScenario1BCalledBytapp() public {
        fullyLiquidateShortPrimaryScenarioB({
            scenario: PrimaryScenarios.CRatioBetween110And200,
            caller: tapp
        });

        //check balance after liquidate
        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 0,
            _collateral: 0,
            _ercDebt: 0,
            _ercDebtAsset: 0,
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT //1 from short minting
        });
    }

    //@dev: Scenario 2: cratio < 1.1
    function testPrimaryFullLiquidateCratioScenario2B() public {
        fullyLiquidateShortPrimaryScenarioB({
            scenario: PrimaryScenarios.CRatioBelow110,
            caller: receiver
        });

        //check balance after liquidate
        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 0,
            _collateral: 0,
            _ercDebt: 0,
            _ercDebtAsset: 0,
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT //1 from short minting
        });
    }

    function testPrimaryFullLiquidateCratioScenario2BCalledBytapp() public {
        fullyLiquidateShortPrimaryScenarioB({
            scenario: PrimaryScenarios.CRatioBelow110,
            caller: tapp
        });
        //check balance after liquidate
        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 0,
            _collateral: 0,
            _ercDebt: 0,
            _ercDebtAsset: 0,
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT //1 from short minting
        });
    }

    //@dev: Scenario 3: cratio < 1.1 black swan
    function testPrimaryFullLiquidateCratioScenario3B() public {
        (MarginCallStruct memory m,) = fullyLiquidateShortPrimaryScenarioB({
            scenario: PrimaryScenarios.CRatioBelow110BlackSwan,
            caller: receiver
        });

        //check balance after liquidate
        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 0,
            _collateral: 0,
            _ercDebt: 0,
            _ercDebtAsset: m.ercDebtSocialized + DEFAULT_AMOUNT, // 1 from dummy short
            _ercDebtRateAsset: m.ercDebtRate,
            _ercAsset: DEFAULT_AMOUNT + m.ercDebtSocialized //1 from short minting
        });
    }

    function testPrimaryFullLiquidateCratioScenario3BCalledBytapp() public {
        (MarginCallStruct memory m,) = fullyLiquidateShortPrimaryScenarioB({
            scenario: PrimaryScenarios.CRatioBelow110BlackSwan,
            caller: tapp
        });
        //check balance after liquidate
        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 0,
            _collateral: 0,
            _ercDebt: 0,
            _ercDebtAsset: m.ercDebtSocialized + DEFAULT_AMOUNT, // 1 from dummy short
            _ercDebtRateAsset: m.ercDebtRate,
            _ercAsset: DEFAULT_AMOUNT + m.ercDebtSocialized //1 from short minting
        });
    }

    ///////Partial///////

    function partiallyLiquidateShortPrimary(PrimaryScenarios scenario, address caller)
        public
        returns (MarginCallStruct memory m, STypes.ShortRecord memory shortRecord)
    {
        if (scenario == PrimaryScenarios.CRatioBelow110BlackSwan) {
            // Dummy short to make sure ercDebtAsset > 0 during liquidation
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, address(4));
            fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, address(4));
        }
        prepareAsk({askPrice: DEFAULT_PRICE, askAmount: DEFAULT_AMOUNT.mulU88(0.5 ether)});
        shortRecord = getShortRecord(sender, Constants.SHORT_STARTING_ID);

        uint256 ercDebtAsset;
        if (scenario != PrimaryScenarios.CRatioBelow110BlackSwan) {
            depositEth(tapp, FUNDED_TAPP);
            t.ethEscrowed = FUNDED_TAPP;
            assertStruct(tapp, t);
            ercDebtAsset = DEFAULT_AMOUNT;
        } else {
            ercDebtAsset = DEFAULT_AMOUNT.mulU88(2 ether);
        }

        //check balance before liquidate
        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 1,
            _collateral: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT).mul(6 ether),
            _ercDebt: DEFAULT_AMOUNT.mulU88(1 ether),
            _ercDebtAsset: ercDebtAsset,
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT.mulU88(1.5 ether) //1 from short minting, .5 from receiver depositing usd for fundLimitAsk
        });

        int256 ethPrice;
        if (scenario == PrimaryScenarios.CRatioBetween110And200) ethPrice = 1000 ether;
        else ethPrice = 730 ether;
        //Margin Call
        m = simulateLiquidation(r, s, ethPrice, caller, sender); //roughly get cratio between 1.1 and 2

        if (scenario == PrimaryScenarios.CRatioBetween110And200) {
            if (caller == receiver) {
                t.ethEscrowed = FUNDED_TAPP + m.tappFee;
                s.ethEscrowed = 0; //still locked up in short collateral
                r.ethEscrowed = m.ethFilled + m.callerFee + m.gasFee;
            } else if (caller == tapp) {
                t.ethEscrowed = FUNDED_TAPP + m.tappFee + m.callerFee + m.gasFee;
                s.ethEscrowed = 0; //still locked up in short collateral
                r.ethEscrowed = m.ethFilled; //receiver was asker for margin call
            }
        } else if (scenario == PrimaryScenarios.CRatioBelow110) {
            if (caller == receiver) {
                //But here, shorter had enough collateral to cover partial fill + fees
                t.ethEscrowed = FUNDED_TAPP + m.tappFee;
                s.ethEscrowed = 0; //collateral still locked up
                r.ethEscrowed = m.ethFilled + m.callerFee + m.gasFee;
            } else if (caller == tapp) {
                t.ethEscrowed = FUNDED_TAPP + m.callerFee + m.gasFee + m.tappFee;
                s.ethEscrowed = 0; //collateral still locked up
                r.ethEscrowed = m.ethFilled;
            }
        } else if (scenario == PrimaryScenarios.CRatioBelow110BlackSwan) {
            if (caller == receiver) {
                //But here, shorter had enough collateral to cover partial fill + fees
                t.ethEscrowed = m.tappFee;
                s.ethEscrowed = 0; //collateral still locked up
                r.ethEscrowed = m.ethFilled + m.callerFee + m.gasFee;
            } else if (caller == tapp) {
                t.ethEscrowed = m.callerFee + m.gasFee + m.tappFee;
                s.ethEscrowed = 0; //collateral still locked up
                r.ethEscrowed = m.ethFilled;
            }
        }
        r.ercEscrowed = DEFAULT_AMOUNT; //from first bid and short match
        //check balances
        assertStruct(tapp, t);
        assertStruct(sender, s);
        assertStruct(receiver, r);
    }

    //@dev: Scenario 1: cratio < 2 and cratio >= 1.1
    function testPrimaryPartialLiquidateCratioScenario1() public {
        (MarginCallStruct memory m,) = partiallyLiquidateShortPrimary({
            scenario: PrimaryScenarios.CRatioBetween110And200,
            caller: receiver
        });

        // check balance after liquidate
        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 1,
            _collateral: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT).mul(6 ether) - m.ethFilled
                - m.tappFee - m.gasFee - m.callerFee, //used collateral to pay
            _ercDebt: DEFAULT_AMOUNT.mulU88(0.5 ether),
            _ercDebtAsset: DEFAULT_AMOUNT.mulU88(0.5 ether),
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT //1 from short minting
        });
    }

    function testPrimaryPartialLiquidateCratioScenario1CalledBytapp() public {
        (MarginCallStruct memory m,) = partiallyLiquidateShortPrimary({
            scenario: PrimaryScenarios.CRatioBetween110And200,
            caller: tapp
        });

        // check balance after liquidate
        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 1,
            _collateral: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT).mul(6 ether) - m.ethFilled
                - m.tappFee - m.gasFee - m.callerFee, //used collateral to pay
            _ercDebt: DEFAULT_AMOUNT.mulU88(0.5 ether),
            _ercDebtAsset: DEFAULT_AMOUNT.mulU88(0.5 ether),
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT //1 from short minting
        });
    }

    //@dev: Scenario 2: cratio < 1.1
    function testPrimaryPartialLiquidateCratioScenario2() public {
        (MarginCallStruct memory m,) = partiallyLiquidateShortPrimary({
            scenario: PrimaryScenarios.CRatioBelow110,
            caller: receiver
        });

        // check balance after liquidate
        checkShortsAndAssetBalance({
            _shorter: tapp,
            _shortLen: 1,
            _collateral: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT).mul(6 ether) - m.ethFilled
                - m.tappFee - m.gasFee - m.callerFee, //used collateral to pay
            _ercDebt: DEFAULT_AMOUNT.mulU88(0.5 ether),
            _ercDebtAsset: DEFAULT_AMOUNT.mulU88(0.5 ether),
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT //1 from short minting
        });
    }

    function testPrimaryPartialLiquidateCratioScenario2CalledBytapp() public {
        (MarginCallStruct memory m,) = partiallyLiquidateShortPrimary({
            scenario: PrimaryScenarios.CRatioBelow110,
            caller: tapp
        });

        // check balance after liquidate
        checkShortsAndAssetBalance({
            _shorter: tapp,
            _shortLen: 1,
            _collateral: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT).mul(6 ether) - m.ethFilled
                - m.tappFee - m.gasFee - m.callerFee, //used collateral to pay
            _ercDebt: DEFAULT_AMOUNT.mulU88(0.5 ether),
            _ercDebtAsset: DEFAULT_AMOUNT.mulU88(0.5 ether),
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT //1 from short minting
        });
    }

    //@dev: Scenario 3: cratio < 1.1 black swan
    function testPrimaryPartialLiquidateCratioScenario3() public {
        (MarginCallStruct memory m,) = partiallyLiquidateShortPrimary({
            scenario: PrimaryScenarios.CRatioBelow110BlackSwan,
            caller: receiver
        });

        // check balance after liquidate
        checkShortsAndAssetBalance({
            _shorter: tapp,
            _shortLen: 1,
            _collateral: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT).mul(6 ether) - m.ethFilled
                - m.tappFee - m.gasFee - m.callerFee, //used collateral to pay
            _ercDebt: DEFAULT_AMOUNT.mulU88(0.5 ether) - m.ercDebtSocialized, // Shorter still owes .5
            _ercDebtAsset: DEFAULT_AMOUNT.mulU88(0.5 ether) + DEFAULT_AMOUNT, // 0.5 from tapp short, 1 from dummy short
            _ercDebtRateAsset: m.ercDebtRate,
            _ercAsset: DEFAULT_AMOUNT //1 from short minting
        });
    }

    function testPrimaryPartialLiquidateCratioScenario3CalledBytapp() public {
        (MarginCallStruct memory m,) = partiallyLiquidateShortPrimary({
            scenario: PrimaryScenarios.CRatioBelow110BlackSwan,
            caller: tapp
        });

        // check balance after liquidate
        checkShortsAndAssetBalance({
            _shorter: tapp,
            _shortLen: 1,
            _collateral: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT).mul(6 ether) - m.ethFilled
                - m.tappFee - m.gasFee - m.callerFee, //used collateral to pay
            _ercDebt: DEFAULT_AMOUNT.mulU88(0.5 ether) - m.ercDebtSocialized,
            _ercDebtAsset: DEFAULT_AMOUNT.mulU88(0.5 ether) + DEFAULT_AMOUNT, // 0.5 from tapp short, 1 from dummy short
            _ercDebtRateAsset: m.ercDebtRate,
            _ercAsset: DEFAULT_AMOUNT //1 from short minting
        });
    }

    ///////Partial, then Fully filled///////

    function secondFullyLiquidateShortPrimary(
        PrimaryScenarios scenario,
        address caller,
        address shorter,
        MarginCallStruct memory m
    ) public {
        //reset data
        STypes.ShortRecord memory short =
            getShortRecord(sender, Constants.SHORT_STARTING_ID);
        vm.stopPrank(); //stop prank
        skip(SIXTEEN_HRS_PLUS); //unflag
        //save fee data from first partial liquidation
        uint256 ethFilled1 = m.ethFilled;
        uint256 tappFee1 = m.tappFee;
        uint256 callerFee1 = m.callerFee;
        uint256 gasFee1 = m.gasFee;

        //create another ask to fully fill the rest of the order
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(0.5 ether), receiver);

        int256 ethPrice;
        if (scenario == PrimaryScenarios.CRatioBetween110And200) ethPrice = 1000 ether;
        else if (scenario == PrimaryScenarios.CRatioBelow110) ethPrice = 300 ether;
        //Margin Call
        m = simulateLiquidation(r, s, ethPrice, caller, shorter); //roughly get cratio between 1.1 and 2

        if (scenario == PrimaryScenarios.CRatioBetween110And200) {
            if (caller == receiver) {
                t.ethEscrowed = FUNDED_TAPP + tappFee1 + m.tappFee; //including fee gained from partial fill
                s.ethEscrowed =
                    short.collateral - m.ethFilled - m.gasFee - m.tappFee - m.callerFee;
                r.ethEscrowed = (ethFilled1 + m.ethFilled) + (callerFee1 + m.callerFee)
                    + (gasFee1 + m.gasFee); //including fee gained from partial fill
            } else if (caller == tapp) {
                t.ethEscrowed = FUNDED_TAPP + (tappFee1 + m.tappFee)
                    + (callerFee1 + m.callerFee) + (gasFee1 + m.gasFee); //including fee gained from partial fill
                s.ethEscrowed =
                    short.collateral - m.ethFilled - m.gasFee - m.tappFee - m.callerFee;
                r.ethEscrowed = (ethFilled1 + m.ethFilled); //including fee gained from partial fill
            }
        } else if (scenario == PrimaryScenarios.CRatioBelow110) {
            if (caller == receiver) {
                t.ethEscrowed = FUNDED_TAPP + tappFee1 - m.ethFilled - m.gasFee
                    - m.callerFee + short.collateral;
                //including fee gained from partial fill
                s.ethEscrowed = 0; //lose all collateral
                r.ethEscrowed = (ethFilled1 + m.ethFilled) + (callerFee1 + m.callerFee)
                    + (gasFee1 + m.gasFee); //including fee gained from partial fill
            } else if (caller == sender) {
                t.ethEscrowed = FUNDED_TAPP + tappFee1 + gasFee1 + callerFee1
                    - m.ethFilled - m.gasFee - m.callerFee + short.collateral;
                //including fee gained from partial fill. Fees offset for fully filled part.
                s.ethEscrowed = m.gasFee + m.callerFee; //lose all collateral
                r.ethEscrowed = (ethFilled1 + m.ethFilled);
            }
        }
        r.ercEscrowed = DEFAULT_AMOUNT; //from first bid and short match
        //check balances
        assertStruct(tapp, t);
        assertStruct(sender, s);
        assertStruct(receiver, r);
    }

    //@dev: Scenario 1: cratio < 2 and cratio >= 1.1
    function testPrimaryPartialThenFullyLiquidateCratioScenario1() public {
        /////Partial Liquidation/////

        (MarginCallStruct memory m,) = partiallyLiquidateShortPrimary({
            scenario: PrimaryScenarios.CRatioBetween110And200,
            caller: receiver
        });

        // check balance after liquidate
        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 1,
            _collateral: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT).mul(6 ether) - m.ethFilled
                - m.tappFee - m.gasFee - m.callerFee, //used collateral to pay
            _ercDebt: DEFAULT_AMOUNT.mulU88(0.5 ether),
            _ercDebtAsset: DEFAULT_AMOUNT.mulU88(0.5 ether),
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT //1 from short minting
        });

        /////Second Liquidation/////
        secondFullyLiquidateShortPrimary({
            scenario: PrimaryScenarios.CRatioBetween110And200,
            caller: receiver,
            shorter: sender,
            m: m
        });
        //check balance after liquidate
        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 0,
            _collateral: 0,
            _ercDebt: 0,
            _ercDebtAsset: 0,
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT //1 from short minting
        });
    }

    function testPrimaryPartialThenFullyLiquidateCratioScenario1CalledBytapp() public {
        /////Partial Liquidation/////
        (MarginCallStruct memory m,) = partiallyLiquidateShortPrimary({
            scenario: PrimaryScenarios.CRatioBetween110And200,
            caller: tapp
        });

        // check balance after liquidate
        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 1,
            _collateral: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT).mul(6 ether) - m.ethFilled
                - m.tappFee - m.gasFee - m.callerFee, //used collateral to pay
            _ercDebt: DEFAULT_AMOUNT.mulU88(0.5 ether),
            _ercDebtAsset: DEFAULT_AMOUNT.mulU88(0.5 ether),
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT //1 from short minting
        });

        /////Second Liquidation/////
        secondFullyLiquidateShortPrimary({
            scenario: PrimaryScenarios.CRatioBetween110And200,
            caller: tapp,
            shorter: sender,
            m: m
        });

        //check balance after liquidate
        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 0,
            _collateral: 0,
            _ercDebt: 0,
            _ercDebtAsset: 0,
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT //1 from short minting
        });
    }

    //@dev: Scenario 2: cratio < 1.1
    function testPrimaryPartialThenFullyLiquidateCratioScenario2() public {
        /////Partial Liquidation/////
        (MarginCallStruct memory m,) = partiallyLiquidateShortPrimary({
            scenario: PrimaryScenarios.CRatioBelow110,
            caller: receiver
        });

        // check balance after liquidate
        checkShortsAndAssetBalance({
            _shorter: tapp,
            _shortLen: 1,
            _collateral: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT).mul(6 ether) - m.ethFilled
                - m.tappFee - m.gasFee - m.callerFee, //used collateral to pay
            _ercDebt: DEFAULT_AMOUNT.mulU88(0.5 ether),
            _ercDebtAsset: DEFAULT_AMOUNT.mulU88(0.5 ether),
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT //1 from short minting
        });

        /////Second Liquidation/////
        secondFullyLiquidateShortPrimary({
            scenario: PrimaryScenarios.CRatioBelow110,
            caller: receiver,
            shorter: tapp,
            m: m
        });

        //check balance after liquidate
        checkShortsAndAssetBalance({
            _shorter: tapp,
            _shortLen: 0,
            _collateral: 0,
            _ercDebt: 0,
            _ercDebtAsset: 0,
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT //1 from short minting
        });
    }

    function testPrimaryPartialThenFullyLiquidateCratioScenario2CalledBytapp() public {
        /////Partial Liquidation/////
        (MarginCallStruct memory m,) = partiallyLiquidateShortPrimary({
            scenario: PrimaryScenarios.CRatioBelow110,
            caller: tapp
        });

        // check balance after liquidate
        checkShortsAndAssetBalance({
            _shorter: tapp,
            _shortLen: 1,
            _collateral: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT).mul(6 ether) - m.ethFilled
                - m.tappFee - m.gasFee - m.callerFee, //used collateral to pay
            _ercDebt: DEFAULT_AMOUNT.mulU88(0.5 ether),
            _ercDebtAsset: DEFAULT_AMOUNT.mulU88(0.5 ether),
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT //1 from short minting
        });

        /////Second Liquidation/////
        secondFullyLiquidateShortPrimary({
            scenario: PrimaryScenarios.CRatioBelow110,
            caller: sender,
            shorter: tapp,
            m: m
        });

        //check balance after liquidate
        checkShortsAndAssetBalance({
            _shorter: tapp,
            _shortLen: 0,
            _collateral: 0,
            _ercDebt: 0,
            _ercDebtAsset: 0,
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT //1 from short minting
        });
    }

    ///////Partial, then Partial fill again///////

    function secondPartiallyLiquidateShortPrimary(
        address caller,
        address shorter,
        MarginCallStruct memory m
    ) public returns (MarginCallStruct memory m2) {
        //reset data
        vm.stopPrank(); //stop prank
        skip(SIXTEEN_HRS_PLUS); //unflag
        //save fee data from first partial liquidation
        uint256 ethFilled1 = m.ethFilled;
        uint256 tappFee1 = m.tappFee;
        uint256 callerFee1 = m.callerFee;
        uint256 gasFee1 = m.gasFee;

        //create another ask to partially fill
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(0.4 ether), receiver);

        int256 ethPrice = 300 ether;
        //Margin Call
        m2 = simulateLiquidation(r, s, ethPrice, caller, shorter); //roughly get cratio between 1.1 and 2

        if (caller == receiver) {
            t.ethEscrowed = FUNDED_TAPP + tappFee1 + m2.tappFee;
            //including fee gained from partial fill
            s.ethEscrowed = 0; //lose all collateral
            r.ethEscrowed = (ethFilled1 + m2.ethFilled) + (callerFee1 + m2.callerFee)
                + (gasFee1 + m2.gasFee); //including fee gained from partial fill
        } else if (caller == sender) {
            t.ethEscrowed = FUNDED_TAPP + tappFee1 + gasFee1 + callerFee1 + m2.tappFee;
            //including fee gained from partial fill. Fees offset for fully filled part.
            s.ethEscrowed = m2.gasFee + m2.callerFee; //lose all collateral
            r.ethEscrowed = (ethFilled1 + m2.ethFilled);
        }

        r.ercEscrowed = DEFAULT_AMOUNT; //from first bid and short match
        //check balances
        assertStruct(tapp, t);
        assertStruct(sender, s);
        assertStruct(receiver, r);
    }

    //@dev: Scenario 2: cratio < 1.1
    function testPrimaryPartialThenPartialLiquidateCratioScenario2() public {
        /////Partial Liquidation/////
        (MarginCallStruct memory m,) = partiallyLiquidateShortPrimary({
            scenario: PrimaryScenarios.CRatioBelow110,
            caller: receiver
        });

        // check balance after liquidate
        checkShortsAndAssetBalance({
            _shorter: tapp,
            _shortLen: 1,
            _collateral: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT).mul(6 ether) - m.ethFilled
                - m.tappFee - m.gasFee - m.callerFee, //used collateral to pay
            _ercDebt: DEFAULT_AMOUNT.mulU88(0.5 ether),
            _ercDebtAsset: DEFAULT_AMOUNT.mulU88(0.5 ether),
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT //1 from short minting
        });
        uint256 colLeft = DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT).mul(6 ether) - m.ethFilled
            - m.tappFee - m.gasFee - m.callerFee;

        /////Second Liquidation///// CRatioBelow110
        MarginCallStruct memory m2 =
            secondPartiallyLiquidateShortPrimary({caller: receiver, shorter: tapp, m: m});

        //check balance after liquidate
        checkShortsAndAssetBalance({
            _shorter: tapp,
            _shortLen: 1,
            _collateral: colLeft - m2.ethFilled - m2.tappFee - m2.gasFee - m2.callerFee,
            _ercDebt: DEFAULT_AMOUNT.mulU88(0.1 ether),
            _ercDebtAsset: DEFAULT_AMOUNT.mulU88(0.1 ether),
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT //1 from short minting
        });
    }

    function testPrimaryPartialThenPartialLiquidateCratioScenario2CalledBytapp() public {
        /////Partial Liquidation/////
        (MarginCallStruct memory m,) = partiallyLiquidateShortPrimary({
            scenario: PrimaryScenarios.CRatioBelow110,
            caller: tapp
        });

        // check balance after liquidate
        checkShortsAndAssetBalance({
            _shorter: tapp,
            _shortLen: 1,
            _collateral: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT).mul(6 ether) - m.ethFilled
                - m.tappFee - m.gasFee - m.callerFee, //used collateral to pay
            _ercDebt: DEFAULT_AMOUNT.mulU88(0.5 ether),
            _ercDebtAsset: DEFAULT_AMOUNT.mulU88(0.5 ether),
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT //1 from short minting
        });

        uint256 colLeft = DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT).mul(6 ether) - m.ethFilled
            - m.tappFee - m.gasFee - m.callerFee;

        /////Second Liquidation///// CRatioBelow110
        MarginCallStruct memory m2 =
            secondPartiallyLiquidateShortPrimary({caller: sender, shorter: tapp, m: m});

        //check balance after liquidate
        checkShortsAndAssetBalance({
            _shorter: tapp,
            _shortLen: 1,
            _collateral: colLeft - m2.ethFilled - m2.tappFee - m2.gasFee - m2.callerFee,
            _ercDebt: DEFAULT_AMOUNT.mulU88(0.1 ether),
            _ercDebtAsset: DEFAULT_AMOUNT.mulU88(0.1 ether),
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT //1 from short minting
        });
    }

    ////////////////Misc. Primary Liquidate Test////////////////

    function testLiquidateUsdLesslowestSellUsd() public {
        prepareAsk(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(2 ether));
        depositEth(tapp, DEFAULT_TAPP);

        //1 from short minting, 2 from receiver depositing usd for fundLimitAsk
        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 1,
            _collateral: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT).mul(6 ether),
            _ercDebt: DEFAULT_AMOUNT.mulU88(1 ether),
            _ercDebtAsset: DEFAULT_AMOUNT.mulU88(1 ether),
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT.mulU88(3 ether)
        });

        // Margin Call
        MarginCallStruct memory m =
            simulateLiquidation(r, s, 2666 ether, receiver, sender);

        r.ethEscrowed = m.ethFilled + m.gasFee + m.callerFee;
        r.ercEscrowed = DEFAULT_AMOUNT;
        assertStruct(receiver, r);

        s.ethEscrowed = DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT).mul(6 ether) - m.ethFilled
            - m.gasFee - m.callerFee - m.tappFee;
        assertStruct(sender, s);

        //2 from receiver depositing usd for fundLimitAsk
        //collateral and ercDebt are gone
        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 0,
            _collateral: 0,
            _ercDebt: 0,
            _ercDebtAsset: 0,
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT.mulU88(2 ether)
        });
    }

    function testLiquidateOBSuddenlyEmpty() public {
        prepareAsk(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(0.5 ether));
        depositEth(tapp, DEFAULT_TAPP);

        //1 from short minting, .5 from receiver depositing usd for fundLimitAsk
        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 1,
            _collateral: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT).mul(6 ether),
            _ercDebt: DEFAULT_AMOUNT.mulU88(1 ether),
            _ercDebtAsset: DEFAULT_AMOUNT.mulU88(1 ether),
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT.mulU88(1.5 ether) //1 from short minting, .5 from receiver depositing usd for fundLimitAsk
        });

        // Margin Call
        MarginCallStruct memory m =
            simulateLiquidation(r, s, 2666 ether, receiver, sender);

        t.ethEscrowed = DEFAULT_TAPP + m.tappFee;
        t.ercEscrowed = 0;
        assertStruct(tapp, t);
        // shorter's ethEscrowed should be re-locked up for partial fill
        s.ethEscrowed = 0;
        s.ercEscrowed = 0;
        assertStruct(sender, s);
        r.ethEscrowed = m.ethFilled + m.gasFee + m.callerFee;
        r.ercEscrowed = DEFAULT_AMOUNT;
        assertStruct(receiver, r);

        // check shorts after liquidation
        uint256 expectedCollateral = DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT).mul(6 ether)
            - m.ethFilled - m.gasFee - m.callerFee - m.tappFee;
        // .5 remaining from short, .5 from receiver depositing usd for fundLimitAsk
        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 1,
            _collateral: expectedCollateral,
            _ercDebt: DEFAULT_AMOUNT.mulU88(0.5 ether),
            _ercDebtAsset: DEFAULT_AMOUNT.mulU88(0.5 ether),
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT
        });
    }

    //@dev: when short.collateral < ethFilled
    function testPrimaryFullLiquidateCratioScenario2CRatioUnder1() public {
        //Don't use prepare short for custom ask pricing
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        r.ercEscrowed = DEFAULT_AMOUNT;
        assertStruct(receiver, r);
        //check initial short info
        STypes.ShortRecord memory shortRecord =
            getShortRecord(sender, Constants.SHORT_STARTING_ID);
        assertEq(getShortRecordCount(sender), 1);
        assertEq(
            shortRecord.collateral, (DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT).mul(6 ether))
        );
        skip(1);

        _setETH(300 ether); //set to black swan levels
        uint80 askPrice = uint80(diamond.getAssetPrice(asset));

        fundLimitAskOpt(askPrice, DEFAULT_AMOUNT, receiver);

        //give eth to tapp for buyback
        depositEth(tapp, FUNDED_TAPP);
        t.ethEscrowed = FUNDED_TAPP;
        t.ercEscrowed = 0;
        assertStruct(tapp, t);

        shortRecord = getShortRecord(sender, Constants.SHORT_STARTING_ID);

        //check balance before liquidateSTypes.ShortRecord memory short = getShortRecord(sender)[0];
        //1 from short minting, 1 from receiver depositing usd for fundLimitAsk
        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 1,
            _collateral: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT).mul(6 ether),
            _ercDebt: DEFAULT_AMOUNT.mulU88(1 ether),
            _ercDebtAsset: DEFAULT_AMOUNT.mulU88(1 ether),
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT.mulU88(2 ether)
        });
        //Margin Call
        MarginCallStruct memory m = simulateLiquidation(r, s, 300 ether, receiver, sender); //roughly get cratio 1x

        //check balances
        t.ethEscrowed =
            FUNDED_TAPP - m.ethFilled - m.gasFee - m.callerFee + shortRecord.collateral;
        t.ercEscrowed = 0;
        assertStruct(tapp, t);
        s.ethEscrowed = 0;
        s.ercEscrowed = 0;
        assertStruct(sender, s);
        r.ethEscrowed = m.ethFilled + m.gasFee + m.callerFee; //receiver was asker for margin call
        r.ercEscrowed = DEFAULT_AMOUNT; //from first bid and short match
        assertStruct(receiver, r);

        //check balance after liquidate
        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 0,
            _collateral: 0,
            _ercDebt: 0,
            _ercDebtAsset: 0,
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT //1 from short minting
        });
    }

    //@dev: Scenario 3: cratio < 1.1 black swan
    function testPrimaryPartialShort1ThenPartialShort2ThenFullShortTappThenPartialShort3LiquidateCratioScenario3(
    ) public {
        /////Partial Liquidation 1/////
        (MarginCallStruct memory m,) = partiallyLiquidateShortPrimary({
            scenario: PrimaryScenarios.CRatioBelow110BlackSwan,
            caller: receiver
        });

        uint256 collateral = DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT).mul(6 ether)
            - m.ethFilled - m.tappFee - m.gasFee - m.callerFee;
        uint256 ercDebt = DEFAULT_AMOUNT.mulU88(0.5 ether) - m.ercDebtSocialized;
        uint256 ercDebtAsset = DEFAULT_AMOUNT.mulU88(0.5 ether) + DEFAULT_AMOUNT; // 1 from dummy short
        uint256 ercDebtRate = m.ercDebtRate;

        // check balance after liquidate
        checkShortsAndAssetBalance({
            _shorter: tapp,
            _shortLen: 1,
            _collateral: collateral,
            _ercDebt: ercDebt,
            _ercDebtAsset: ercDebtAsset,
            _ercDebtRateAsset: ercDebtRate,
            _ercAsset: DEFAULT_AMOUNT //1 from short minting
        });

        // Bring TAPP balance to 0 for easier calculations
        vm.stopPrank();
        uint88 balanceTAPP = diamond.getVaultUserStruct(Vault.CARBON, tapp).ethEscrowed;
        depositEth(tapp, DEFAULT_AMOUNT.mulU88(DEFAULT_PRICE) - balanceTAPP);
        vm.prank(tapp);
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);

        /////Partial Liquidation 2/////
        _setETH(4000 ether); // Back to default price
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender); // Short Record Constants.SHORT_STARTING_ID gets re-used
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT / 2, receiver); // Set up partial liquidation
        // Partial Liquidation
        _setETH(730 ether); // c-ratio 1.095
        vm.prank(receiver);
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID, Constants.HEAD);
        skipTimeAndSetEth(TEN_HRS_PLUS, 730 ether); //10hrs 1 second
        vm.prank(receiver);
        (uint256 gasFee,) = diamond.liquidate(
            asset, sender, Constants.SHORT_STARTING_ID, shortHintArrayStorage
        );
        // Assert updated TAPP short
        STypes.ShortRecord memory short =
            getShortRecord(tapp, Constants.SHORT_STARTING_ID);
        assertEq(short.collateral, collateral * 2 + m.gasFee - gasFee); // almost exactly the same, just diff gas fee
        assertEq(short.ercDebt, ercDebt * 2);
        ercDebtAsset = diamond.getAssetStruct(asset).ercDebt + DEFAULT_AMOUNT / 2; // add back partial margin call
        ercDebtRate += m.ercDebtSocialized.div(ercDebtAsset - DEFAULT_AMOUNT); // entire collateral was removed in denominator
        assertApproxEqAbs(
            short.ercDebtRate, (ercDebtRate + m.ercDebtRate) / 2, MAX_DELTA_SMALL
        );

        ///////Full Liquidation///////
        uint88 amount = short.ercDebt
            + short.ercDebt.mulU88(
                diamond.getAssetStruct(asset).ercDebtRate - short.ercDebtRate
            );
        fundLimitAskOpt(DEFAULT_PRICE, amount, receiver); // Set up full liquidation
        vm.prank(receiver);
        diamond.flagShort(asset, tapp, Constants.SHORT_STARTING_ID, Constants.HEAD);
        skipTimeAndSetEth(TEN_HRS_PLUS, 730 ether); //10hrs 1 second
        vm.prank(receiver);
        diamond.liquidate(asset, tapp, Constants.SHORT_STARTING_ID, shortHintArrayStorage);
        // Assert TAPP short fully liquidated and closed
        short = getShortRecord(tapp, Constants.SHORT_STARTING_ID);
        assertTrue(short.status == SR.Cancelled);

        // Bring TAPP balance to 0 for easier calculations
        balanceTAPP = diamond.getVaultUserStruct(Vault.CARBON, tapp).ethEscrowed;
        vm.prank(tapp);
        createLimitBid(DEFAULT_PRICE, balanceTAPP.divU88(DEFAULT_PRICE));
        fundLimitAskOpt(DEFAULT_PRICE, balanceTAPP.divU88(DEFAULT_PRICE), receiver);

        //////Partial Liquidation 3//////
        _setETH(4000 ether); // Back to default price
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender); // Short Record Constants.SHORT_STARTING_ID gets re-used
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT / 2, receiver); // Set up partial liquidation
        // Partial Liquidation
        _setETH(730 ether); // c-ratio 1.095
        vm.prank(receiver);
        diamond.flagShort(asset, sender, Constants.SHORT_STARTING_ID, Constants.HEAD);
        skipTimeAndSetEth(TEN_HRS_PLUS, 730 ether); //10hrs 1 second
        vm.prank(receiver);
        (gasFee,) = diamond.liquidate(
            asset, sender, Constants.SHORT_STARTING_ID, shortHintArrayStorage
        );
        // Assert recreated TAPP short
        short = getShortRecord(tapp, Constants.SHORT_STARTING_ID);
        assertEq(short.collateral, collateral + m.gasFee - gasFee); // exactly the same, except for diff gas fee
        assertEq(short.ercDebt, ercDebt); // exactly the same
        assertApproxEqAbs(
            short.ercDebtRate, diamond.getAssetStruct(asset).ercDebtRate, MAX_DELTA_SMALL
        );
    }

    //Primary liquidate short cRatio < 1.1
    function test_PrimaryLiquidation_NoNeedToFlagShortUnder1_1Cratio() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        //@dev give tapp eth to avoid black swan
        depositEth(tapp, 100 ether);

        //@dev set cRatio below 1.1
        setETH(700 ether);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, extra);
        diamond.liquidate(
            asset, sender, Constants.SHORT_STARTING_ID, shortHintArrayStorage
        );
    }
}
