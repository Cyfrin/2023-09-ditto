// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.21;

import {stdError} from "forge-std/StdError.sol";
import {U256, Math128, U88, U80} from "contracts/libraries/PRBMathHelper.sol";
import {Constants} from "contracts/libraries/Constants.sol";
import {Errors} from "contracts/libraries/Errors.sol";

import {STypes, MTypes} from "contracts/libraries/DataTypes.sol";

import {SecondaryScenarios, SecondaryType} from "test/utils/TestTypes.sol";
import {MarginCallHelper} from "test/utils/MarginCallHelper.sol";

// import {console} from "contracts/libraries/console.sol";

contract MarginCallSecondaryTest is MarginCallHelper {
    using U256 for uint256;
    using Math128 for uint128;
    using U88 for uint88;
    using U80 for uint80;

    //Batch liquidations
    bool public constant WALLET = true;
    bool public constant ERC_ESCROWED = false;

    function setUp() public override {
        super.setUp();
    }

    ////////////////C Ratio scenario testing////////////////

    /*
      //@dev: scenarios for below
        secondary
        Scenario 1: cratio < 1.5 and cratio > 1.1 (Caller gets ercDebtAtOracle. Shorter gets remaining collateral)
        Scenario 2: cratio <= 1.1 and cratio > 1 (Caller gets ercDebtAtOracle. Tapp gets remaining collateral. Shorter gets nothing)
        Scenario 3: cratio < 1 (Caller gets all collateral, but is haircut since cratio under 1. Shorter gets nothing)
    */

    //@dev helper function for setting cratio and minting, as well as the actual liquidation
    function secondaryLiquidateScenarioSetUp(
        SecondaryScenarios scenario,
        SecondaryType secondaryType,
        address caller
    ) public returns (uint256, uint256) {
        s.ethEscrowed = 0;
        s.ercEscrowed = 0;
        assertStruct(sender, s);

        uint256 cRatio;
        STypes.ShortRecord memory shortRecord =
            getShortRecord(sender, Constants.SHORT_STARTING_ID);

        //change ethPrice based on desired scenario
        if (scenario == SecondaryScenarios.CRatioBetween110And150) {
            _setETH(750 ether); //roughly get cratio between 1.1 and 1.5
            cRatio = diamond.getCollateralRatio(asset, shortRecord);
            assertTrue(cRatio > 1.1 ether && cRatio < 1.5 ether);
        } else if (scenario == SecondaryScenarios.CRatioBetween100And110) {
            _setETH(700 ether); //roughly get cratio between 1 and 1.1
            cRatio = diamond.getCollateralRatio(asset, shortRecord);
            assertTrue(cRatio > 1 ether && cRatio <= 1.1 ether);
        } else {
            _setETH(600 ether); //roughly get cratio less than 1
            cRatio = diamond.getCollateralRatio(asset, shortRecord);
            assertTrue(cRatio <= DEFAULT_AMOUNT);
        }

        uint256 ercDebtAtOraclePrice =
            shortRecord.ercDebt.mul(diamond.getAssetPrice(asset));
        uint256 remainingCollateral;
        //sanity check
        if (scenario != SecondaryScenarios.CRatioBelow100) {
            //remainingCollateral only needed for scenarios 1 and 2
            remainingCollateral = shortRecord.collateral - ercDebtAtOraclePrice;
            assertEq(ercDebtAtOraclePrice + remainingCollateral, shortRecord.collateral);
        }

        if (secondaryType == SecondaryType.LiquidateErcEscrowed) {
            //no need to depositUsd for receiver because they already have from initial Bid
            if (caller != receiver) {
                depositUsd(caller, shortRecord.ercDebt);
            }
            liquidateErcEscrowed(
                sender, Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT, caller
            );
        } else {
            vm.prank(_diamond);
            token.mint(caller, DEFAULT_AMOUNT);
            assertEq(token.balanceOf(caller), DEFAULT_AMOUNT);
            liquidateWallet(sender, Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT, caller);
            assertEq(token.balanceOf(caller), 0 ether);
        }

        return (ercDebtAtOraclePrice, remainingCollateral);
    }

    function checkEthAndErcEscrowedAfterLiquidation(
        SecondaryScenarios scenario,
        SecondaryType secondaryType,
        address caller,
        uint256 ercDebtAtOraclePrice,
        uint256 remainingCollateral
    ) public {
        //@dev: caller gives up ercEscrowed for collateral
        if (scenario == SecondaryScenarios.CRatioBetween110And150) {
            if (secondaryType == SecondaryType.LiquidateErcEscrowed) {
                if (caller == receiver) {
                    s.ethEscrowed = remainingCollateral;
                    r.ethEscrowed = ercDebtAtOraclePrice;
                    r.ercEscrowed = 0; //gave up from escrow
                } else if (caller == tapp) {
                    t.ethEscrowed = ercDebtAtOraclePrice; //sp is caller
                    t.ercEscrowed = 0; //gave up from escrow
                    s.ethEscrowed = remainingCollateral;
                    r.ercEscrowed = DEFAULT_AMOUNT; //from initial bid
                }
            } else if (secondaryType == SecondaryType.LiquidateWallet) {
                if (caller == receiver) {
                    s.ethEscrowed = remainingCollateral;
                    r.ethEscrowed = ercDebtAtOraclePrice;
                    r.ercEscrowed = DEFAULT_AMOUNT;
                } else if (caller == tapp) {
                    t.ethEscrowed = ercDebtAtOraclePrice;
                    t.ercEscrowed = 0; //gave up from wallet
                    s.ethEscrowed = remainingCollateral;
                    r.ercEscrowed = DEFAULT_AMOUNT; //from initial bid
                }
            }
        }
        //@dev caller gives up ercEscrowed for collateral. Tapp gets remaining collateral instead of shorter gets nothing back
        else if (scenario == SecondaryScenarios.CRatioBetween100And110) {
            if (secondaryType == SecondaryType.LiquidateErcEscrowed) {
                if (caller == receiver) {
                    t.ethEscrowed = remainingCollateral;
                    r.ethEscrowed = ercDebtAtOraclePrice;
                    r.ercEscrowed = 0; //gave up from escrow
                } else if (caller == tapp) {
                    t.ethEscrowed = ercDebtAtOraclePrice + remainingCollateral;
                    t.ercEscrowed = 0; //gave up from escrow
                    r.ercEscrowed = DEFAULT_AMOUNT; //from initial bid
                }
            } else if (secondaryType == SecondaryType.LiquidateWallet) {
                if (caller == receiver) {
                    t.ethEscrowed = remainingCollateral;
                    r.ethEscrowed = ercDebtAtOraclePrice;
                    r.ercEscrowed = DEFAULT_AMOUNT;
                } else if (caller == tapp) {
                    t.ethEscrowed = ercDebtAtOraclePrice + remainingCollateral;
                    t.ercEscrowed = 0; //gave up from wallet
                    r.ercEscrowed = DEFAULT_AMOUNT; //from initial bid
                }
            }
        }
        //@dev caller gives up ercEscrowed for collateral (haircut)
        else if (scenario == SecondaryScenarios.CRatioBelow100) {
            if (secondaryType == SecondaryType.LiquidateErcEscrowed) {
                if (caller == receiver) {
                    r.ethEscrowed = DEFAULT_PRICE.mulU80(DEFAULT_AMOUNT) * 6;
                    r.ercEscrowed = 0; //gave up from escrow
                } else if (caller == tapp) {
                    t.ethEscrowed = DEFAULT_PRICE.mulU80(DEFAULT_AMOUNT) * 6; //sp is caller
                    t.ercEscrowed = 0; //gave up from escrow
                    r.ercEscrowed = DEFAULT_AMOUNT; //from initial bid
                }
            } else if (secondaryType == SecondaryType.LiquidateWallet) {
                if (caller == receiver) {
                    r.ethEscrowed = DEFAULT_PRICE.mulU80(DEFAULT_AMOUNT) * 6;
                    r.ercEscrowed = DEFAULT_AMOUNT;
                } else if (caller == tapp) {
                    //caller gives up ercEscrowed for collateral
                    t.ethEscrowed = DEFAULT_PRICE.mulU80(DEFAULT_AMOUNT) * 6;
                    r.ercEscrowed = DEFAULT_AMOUNT;
                }
            }
        }
        assertStruct(tapp, t);
        assertStruct(sender, s);
        assertStruct(receiver, r);
    }

    function LiquidateShortSecondary(
        SecondaryScenarios scenario,
        SecondaryType secondaryType,
        address caller
    ) public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        //check balance before liquidate
        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 1,
            _collateral: DEFAULT_PRICE.mulU80(DEFAULT_AMOUNT) * 6,
            _ercDebt: DEFAULT_AMOUNT,
            _ercDebtAsset: DEFAULT_AMOUNT,
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT
        });

        (uint256 ercDebtAtOraclePrice, uint256 remainingCollateral) =
            secondaryLiquidateScenarioSetUp(scenario, secondaryType, caller); //sets ETH and liquidates

        checkEthAndErcEscrowedAfterLiquidation({
            scenario: scenario,
            secondaryType: secondaryType,
            caller: caller,
            ercDebtAtOraclePrice: ercDebtAtOraclePrice,
            remainingCollateral: remainingCollateral
        });
    }

    function LiquidateShortSecondaryPartial(
        SecondaryScenarios scenario,
        SecondaryType secondaryType,
        address caller
    ) public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, tapp);
        // Since the tapp already has short in position 2, combine with the newly created short 3
        // This should never happen in practice since the tapp doesnt make shorts, just for ease of testing
        vm.prank(tapp);
        combineShorts({
            id1: Constants.SHORT_STARTING_ID,
            id2: Constants.SHORT_STARTING_ID + 1
        });

        //check balance before liquidate
        checkShortsAndAssetBalance({
            _shorter: tapp,
            _shortLen: 1,
            _collateral: DEFAULT_PRICE.mulU80(DEFAULT_AMOUNT) * 6,
            _ercDebt: DEFAULT_AMOUNT,
            _ercDebtAsset: DEFAULT_AMOUNT,
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT
        });

        uint256 cRatio;
        STypes.ShortRecord memory shortRecord =
            getShortRecord(tapp, Constants.SHORT_STARTING_ID);
        //change ethPrice based on desired scenario
        if (scenario == SecondaryScenarios.CRatioBetween100And110) {
            _setETH(700 ether); //roughly get cratio between 1 and 1.1
            cRatio = diamond.getCollateralRatio(asset, shortRecord);
            assertTrue(cRatio > 1 ether && cRatio <= 1.1 ether);
        } else {
            _setETH(200 ether); //roughly get cratio less than 1
            cRatio = diamond.getCollateralRatio(asset, shortRecord);
            assertTrue(cRatio <= DEFAULT_AMOUNT);
        }

        uint256 ercDebtAtOraclePrice =
            shortRecord.ercDebt.mul(diamond.getAssetPrice(asset));

        if (secondaryType == SecondaryType.LiquidateErcEscrowed) {
            //no need to depositUsd for receiver because they already have from initial Bid
            liquidateErcEscrowed(
                tapp, Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT / 2, caller
            );
        } else {
            vm.prank(_diamond);
            token.mint(caller, DEFAULT_AMOUNT / 2);
            assertEq(token.balanceOf(caller), DEFAULT_AMOUNT / 2);
            liquidateWallet(tapp, Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT / 2, caller);
            assertEq(token.balanceOf(caller), 0 ether);
        }

        if (scenario == SecondaryScenarios.CRatioBetween100And110) {
            if (secondaryType == SecondaryType.LiquidateErcEscrowed) {
                r.ethEscrowed = (ercDebtAtOraclePrice / 2);
                r.ercEscrowed = DEFAULT_AMOUNT / 2; // gave up from escrow
            } else if (secondaryType == SecondaryType.LiquidateWallet) {
                r.ethEscrowed = (ercDebtAtOraclePrice / 2);
                r.ercEscrowed = DEFAULT_AMOUNT; // from initial bid
            }
        } else if (scenario == SecondaryScenarios.CRatioBelow100) {
            if (secondaryType == SecondaryType.LiquidateErcEscrowed) {
                r.ethEscrowed = shortRecord.collateral; // max amount
                r.ercEscrowed = DEFAULT_AMOUNT / 2; //gave up from escrow
            } else if (secondaryType == SecondaryType.LiquidateWallet) {
                r.ethEscrowed = shortRecord.collateral; // max amount
                r.ercEscrowed = DEFAULT_AMOUNT; // from initial bid
            }
        }
        assertStruct(tapp, t);
        assertStruct(receiver, r);
    }

    function LiquidateShortSecondaryFullAfterPartial(
        SecondaryScenarios scenario,
        SecondaryType secondaryType,
        address caller
    ) public {
        STypes.ShortRecord memory shortRecord =
            getShortRecord(tapp, Constants.SHORT_STARTING_ID);

        uint256 ercDebtAtOraclePrice =
            shortRecord.ercDebt.mul(diamond.getAssetPrice(asset));

        if (secondaryType == SecondaryType.LiquidateErcEscrowed) {
            //no need to depositUsd for receiver because they already have from initial Bid
            liquidateErcEscrowed(
                tapp, Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT / 2, caller
            );
        } else {
            vm.prank(_diamond);
            token.mint(caller, DEFAULT_AMOUNT / 2);
            assertEq(token.balanceOf(caller), DEFAULT_AMOUNT / 2);
            liquidateWallet(tapp, Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT / 2, caller);
            assertEq(token.balanceOf(caller), 0 ether);
        }

        if (scenario == SecondaryScenarios.CRatioBetween100And110) {
            if (secondaryType == SecondaryType.LiquidateErcEscrowed) {
                r.ethEscrowed = ercDebtAtOraclePrice * 2; // half from last time, other half from this time
                r.ercEscrowed = 0; // gave up from escrow
                t.ethEscrowed =
                    DEFAULT_AMOUNT.mul(DEFAULT_PRICE) * 6 - ercDebtAtOraclePrice * 2; // remaining collateral
            } else if (secondaryType == SecondaryType.LiquidateWallet) {
                r.ethEscrowed = ercDebtAtOraclePrice * 2; // half from last time, other half from this time
                r.ercEscrowed = DEFAULT_AMOUNT; // from initial bid
                t.ethEscrowed =
                    DEFAULT_AMOUNT.mul(DEFAULT_PRICE) * 6 - ercDebtAtOraclePrice * 2; // remaining collateral
            }
        } else if (scenario == SecondaryScenarios.CRatioBelow100) {
            // In these cases there is no collateral left so user is just burning erc
            if (secondaryType == SecondaryType.LiquidateErcEscrowed) {
                r.ethEscrowed = DEFAULT_AMOUNT.mul(DEFAULT_PRICE) * 6; // unchanged from last
                r.ercEscrowed = 0; // gave up from escrow
            } else if (secondaryType == SecondaryType.LiquidateWallet) {
                r.ethEscrowed = DEFAULT_AMOUNT.mul(DEFAULT_PRICE) * 6; // unchanged from last
                r.ercEscrowed = DEFAULT_AMOUNT; // from initial bid
            }
        }
        assertStruct(tapp, t);
        assertStruct(receiver, r);
    }

    // Secondary Liquidate Scenario Testing
    //@dev: Scenario 1: ratio < 1.5 and cratio > 1.1
    //liquidateErcEscrowed
    function testSecondaryLiquidateScenario1ErcEscrowed() public {
        LiquidateShortSecondary({
            scenario: SecondaryScenarios.CRatioBetween110And150,
            secondaryType: SecondaryType.LiquidateErcEscrowed,
            caller: receiver
        });

        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 0,
            _collateral: 0, //collateral and ercDebt are gone
            _ercDebt: 0,
            _ercDebtAsset: 0,
            _ercDebtRateAsset: 0,
            _ercAsset: 0 //vault bal = 0 because existing erc is burned
        });
    }

    function testSecondaryLiquidateScenario1ErcEscrowedCalledByTapp() public {
        LiquidateShortSecondary({
            scenario: SecondaryScenarios.CRatioBetween110And150,
            secondaryType: SecondaryType.LiquidateErcEscrowed,
            caller: tapp
        });

        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 0,
            _collateral: 0, //collateral and ercDebt are gone
            _ercDebt: 0,
            _ercDebtAsset: 0,
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT //vault bal = 1 from initial bid for receiver
        });
    }

    //liquidateWallet
    function testSecondaryLiquidateScenario1Wallet() public {
        LiquidateShortSecondary({
            scenario: SecondaryScenarios.CRatioBetween110And150,
            secondaryType: SecondaryType.LiquidateWallet,
            caller: receiver
        });

        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 0,
            _collateral: 0, //collateral and ercDebt are gone
            _ercDebt: 0,
            _ercDebtAsset: 0,
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT //vault bal = 1 from initial bid for receiver
        });
    }

    function testSecondaryLiquidateScenario1WalletCalledByTapp() public {
        LiquidateShortSecondary({
            scenario: SecondaryScenarios.CRatioBetween110And150,
            secondaryType: SecondaryType.LiquidateWallet,
            caller: tapp
        });

        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 0,
            _collateral: 0, //collateral and ercDebt are gone
            _ercDebt: 0,
            _ercDebtAsset: 0,
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT //vault bal = 1 from initial bid for receiver
        });
    }

    //@dev: Scenario 2: cratio <= 1.1 and cratio > 1
    //liquidateErcEscrowed
    function testSecondaryLiquidateScenario2ErcEscrowed() public {
        LiquidateShortSecondary({
            scenario: SecondaryScenarios.CRatioBetween100And110,
            secondaryType: SecondaryType.LiquidateErcEscrowed,
            caller: receiver
        });

        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 0,
            _collateral: 0, //collateral and ercDebt are gone
            _ercDebt: 0,
            _ercDebtAsset: 0,
            _ercDebtRateAsset: 0,
            _ercAsset: 0 //vault bal = 0 because existing erc is burned
        });
    }

    function testSecondaryLiquidateScenario2ErcEscrowedCalledByTapp() public {
        LiquidateShortSecondary({
            scenario: SecondaryScenarios.CRatioBetween100And110,
            secondaryType: SecondaryType.LiquidateErcEscrowed,
            caller: tapp
        });

        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 0,
            _collateral: 0, //collateral and ercDebt are gone
            _ercDebt: 0,
            _ercDebtAsset: 0,
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT //vault bal = 1 from initial bid for receiver
        });
    }

    //liquidateWallet
    function testSecondaryLiquidateScenario2Wallet() public {
        LiquidateShortSecondary({
            scenario: SecondaryScenarios.CRatioBetween100And110,
            secondaryType: SecondaryType.LiquidateWallet,
            caller: receiver
        });

        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 0,
            _collateral: 0, //collateral and ercDebt are gone
            _ercDebt: 0,
            _ercDebtAsset: 0,
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT //vault bal = 1 from initial bid for receiver
        });
    }

    function testSecondaryLiquidateScenario2WalletCalledByTapp() public {
        LiquidateShortSecondary({
            scenario: SecondaryScenarios.CRatioBetween100And110,
            secondaryType: SecondaryType.LiquidateWallet,
            caller: tapp
        });
        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 0,
            _collateral: 0, //collateral and ercDebt are gone
            _ercDebt: 0,
            _ercDebtAsset: 0,
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT //vault bal = 1 from initial bid for receiver
        });
    }

    //@dev:Scenario 3: cratio < 1
    //liquidateErcEscrowed
    function testSecondaryLiquidateScenario3ErcEscrowed() public {
        LiquidateShortSecondary({
            scenario: SecondaryScenarios.CRatioBelow100,
            secondaryType: SecondaryType.LiquidateErcEscrowed,
            caller: receiver
        });

        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 0,
            _collateral: 0, //collateral and ercDebt are gone
            _ercDebt: 0,
            _ercDebtAsset: 0,
            _ercDebtRateAsset: 0,
            _ercAsset: 0 //vault bal = 0 because existing erc is burned
        });
    }

    function testSecondaryLiquidateScenario3ErcEscrowedCalledByTapp() public {
        LiquidateShortSecondary({
            scenario: SecondaryScenarios.CRatioBelow100,
            secondaryType: SecondaryType.LiquidateErcEscrowed,
            caller: tapp
        });

        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 0,
            _collateral: 0, //collateral and ercDebt are gone
            _ercDebt: 0,
            _ercDebtAsset: 0,
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT //vault bal = 1 from initial bid for receiver
        });
    }

    //liquidateWallet
    function testSecondaryLiquidateScenario3Wallet() public {
        LiquidateShortSecondary({
            scenario: SecondaryScenarios.CRatioBelow100,
            secondaryType: SecondaryType.LiquidateWallet,
            caller: receiver
        });

        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 0,
            _collateral: 0, //collateral and ercDebt are gone
            _ercDebt: 0,
            _ercDebtAsset: 0,
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT //vault bal = 1 from initial bid for receiver
        });
    }

    function testSecondaryLiquidateScenario3WalletCalledByTapp() public {
        LiquidateShortSecondary({
            scenario: SecondaryScenarios.CRatioBelow100,
            secondaryType: SecondaryType.LiquidateWallet,
            caller: tapp
        });

        checkShortsAndAssetBalance({
            _shorter: sender,
            _shortLen: 0,
            _collateral: 0, //collateral and ercDebt are gone
            _ercDebt: 0,
            _ercDebtAsset: 0,
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT //vault bal = 1 from initial bid for receiver
        });
    }

    // Secondary Partial Liquidate Scenario Testing
    //@dev: Scenario 2: cratio <= 1.1 and cratio > 1
    function testSecondaryLiquidatePartialScenario2ErcEscrowed() public {
        LiquidateShortSecondaryPartial({
            scenario: SecondaryScenarios.CRatioBetween100And110,
            secondaryType: SecondaryType.LiquidateErcEscrowed,
            caller: receiver
        });

        uint256 collateralUsed = (DEFAULT_AMOUNT / 2).mul(diamond.getAssetPrice(asset));
        uint256 collateralRemain = DEFAULT_AMOUNT.mul(DEFAULT_PRICE) * 6 - collateralUsed;

        checkShortsAndAssetBalance({
            _shorter: tapp,
            _shortLen: 1,
            _collateral: collateralRemain,
            _ercDebt: DEFAULT_AMOUNT / 2,
            _ercDebtAsset: DEFAULT_AMOUNT / 2,
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT / 2 // Burned half of caller's ercEscrowed balance
        });
    }

    function testSecondaryLiquidatePartialScenario2Wallet() public {
        LiquidateShortSecondaryPartial({
            scenario: SecondaryScenarios.CRatioBetween100And110,
            secondaryType: SecondaryType.LiquidateWallet,
            caller: receiver
        });

        uint256 collateralUsed = (DEFAULT_AMOUNT / 2).mul(diamond.getAssetPrice(asset));
        uint256 collateralRemain = DEFAULT_AMOUNT.mul(DEFAULT_PRICE) * 6 - collateralUsed;

        checkShortsAndAssetBalance({
            _shorter: tapp,
            _shortLen: 1,
            _collateral: collateralRemain,
            _ercDebt: DEFAULT_AMOUNT / 2,
            _ercDebtAsset: DEFAULT_AMOUNT / 2,
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT // Didn't use caller's ercEscrowed balance, used wallet balance
        });
    }

    // Scenario 3: cratio < 1
    function testSecondaryLiquidatePartialScenario3ErcEscrowed() public {
        LiquidateShortSecondaryPartial({
            scenario: SecondaryScenarios.CRatioBelow100,
            secondaryType: SecondaryType.LiquidateErcEscrowed,
            caller: receiver
        });

        checkShortsAndAssetBalance({
            _shorter: tapp,
            _shortLen: 1,
            _collateral: 0, // All is used even though w/ partial margin call bc of the low c-ratio
            _ercDebt: DEFAULT_AMOUNT / 2,
            _ercDebtAsset: DEFAULT_AMOUNT / 2,
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT / 2 // Burned half of caller's ercEscrowed balance
        });
    }

    function testSecondaryLiquidatePartialScenario3Wallet() public {
        LiquidateShortSecondaryPartial({
            scenario: SecondaryScenarios.CRatioBelow100,
            secondaryType: SecondaryType.LiquidateWallet,
            caller: receiver
        });

        checkShortsAndAssetBalance({
            _shorter: tapp,
            _shortLen: 1,
            _collateral: 0, // All is used even though w/ partial margin call bc of the low c-ratio
            _ercDebt: DEFAULT_AMOUNT / 2,
            _ercDebtAsset: DEFAULT_AMOUNT / 2,
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT // Didn't use caller's ercEscrowed balance, used wallet balance
        });
    }

    // Secondary Partial Then Full Liquidate Scenario Testing
    //@dev: Scenario 2: cratio <= 1.1 and cratio > 1
    function testSecondaryLiquidatePartialThenFullScenario2ErcEscrowed() public {
        testSecondaryLiquidatePartialScenario2ErcEscrowed();

        LiquidateShortSecondaryFullAfterPartial({
            scenario: SecondaryScenarios.CRatioBetween100And110,
            secondaryType: SecondaryType.LiquidateErcEscrowed,
            caller: receiver
        });

        checkShortsAndAssetBalance({
            _shorter: tapp,
            _shortLen: 0,
            _collateral: 0,
            _ercDebt: 0,
            _ercDebtAsset: 0,
            _ercDebtRateAsset: 0,
            _ercAsset: 0 // Burned half of caller's ercEscrowed balance
        });
    }

    function testSecondaryLiquidatePartialThenFullScenario2Wallet() public {
        testSecondaryLiquidatePartialScenario2Wallet();

        LiquidateShortSecondaryFullAfterPartial({
            scenario: SecondaryScenarios.CRatioBetween100And110,
            secondaryType: SecondaryType.LiquidateWallet,
            caller: receiver
        });

        checkShortsAndAssetBalance({
            _shorter: tapp,
            _shortLen: 0,
            _collateral: 0,
            _ercDebt: 0,
            _ercDebtAsset: 0,
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT // Didn't use caller's ercEscrowed balance, used wallet balance
        });
    }

    // Scenario 3: cratio < 1
    function testSecondaryLiquidatePartialThenFullScenario3ErcEscrowed() public {
        testSecondaryLiquidatePartialScenario3ErcEscrowed();

        LiquidateShortSecondaryFullAfterPartial({
            scenario: SecondaryScenarios.CRatioBelow100,
            secondaryType: SecondaryType.LiquidateErcEscrowed,
            caller: receiver
        });

        checkShortsAndAssetBalance({
            _shorter: tapp,
            _shortLen: 0,
            _collateral: 0,
            _ercDebt: 0,
            _ercDebtAsset: 0,
            _ercDebtRateAsset: 0,
            _ercAsset: 0 // Burned half of caller's ercEscrowed balance
        });
    }

    function testSecondaryLiquidatePartialThenFullScenario3Wallet() public {
        testSecondaryLiquidatePartialScenario3Wallet();

        LiquidateShortSecondaryFullAfterPartial({
            scenario: SecondaryScenarios.CRatioBelow100,
            secondaryType: SecondaryType.LiquidateWallet,
            caller: receiver
        });

        checkShortsAndAssetBalance({
            _shorter: tapp,
            _shortLen: 0,
            _collateral: 0,
            _ercDebt: 0,
            _ercDebtAsset: 0,
            _ercDebtRateAsset: 0,
            _ercAsset: DEFAULT_AMOUNT // Didn't use caller's ercEscrowed balance, used wallet balance
        });
    }

    function makeShortsAndCreateBatch()
        public
        returns (MTypes.BatchMC[] memory batches)
    {
        uint8 id;
        uint256 cRatio;
        //create some active shorts
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        for (uint8 i; i < getShortRecordCount(sender); i++) {
            id = Constants.SHORT_STARTING_ID + i;
            cRatio = diamond.getCollateralRatio(asset, getShortRecord(sender, id));
            assertTrue(cRatio > 1.5 ether);
        }

        assertEq(getShortRecordCount(sender), 3);

        _setETH(750 ether); //roughly get cratio between 1.1 and 1.5

        //create array of shorts
        batches = new MTypes.BatchMC[](getShortRecordCount(sender));

        for (uint8 i; i < getShortRecordCount(sender); i++) {
            id = Constants.SHORT_STARTING_ID + i;
            cRatio = diamond.getCollateralRatio(asset, getShortRecord(sender, id));
            assertTrue(cRatio > 1.1 ether && cRatio < 1.5 ether);
            batches[i] = MTypes.BatchMC({shorter: sender, shortId: id});
        }

        return batches;
    }

    function batchLiquidateAndCheckBal(MTypes.BatchMC[] memory batches, bool isWallet)
        public
    {
        uint256 totalCollateral;
        uint256 liquidatorCollateral;

        for (uint8 i; i < 3; i++) {
            uint8 id = Constants.SHORT_STARTING_ID + i;
            totalCollateral += getShortRecord(sender, id).collateral;
            liquidatorCollateral +=
                getShortRecord(sender, id).ercDebt.mul(testFacet.getOraclePriceT(asset));
        }

        assertEq(diamond.getAssetStruct(asset).ercDebt, DEFAULT_AMOUNT * 3);

        //liquidate all of it
        if (isWallet) {
            vm.prank(_diamond);
            token.mint(extra, DEFAULT_AMOUNT * 3);
            assertEq(token.balanceOf(extra), DEFAULT_AMOUNT * 3);
        } else {
            depositUsd(extra, DEFAULT_AMOUNT * 3);
            e.ercEscrowed = DEFAULT_AMOUNT.mulU88(3 ether);
        }
        e.ethEscrowed = 0;
        assertStruct(extra, e);
        vm.prank(extra);
        diamond.liquidateSecondary(asset, batches, DEFAULT_AMOUNT * 3, isWallet);

        //margin caller gets collateral
        e.ethEscrowed = liquidatorCollateral;
        e.ercEscrowed = 0;
        assertStruct(extra, e);
        s.ethEscrowed = totalCollateral - liquidatorCollateral;
        s.ercEscrowed = 0;
        assertStruct(sender, s);
        assertEq(getShortRecordCount(sender), 0);
        assertEq(token.balanceOf(extra), 0);

        //check system debt
        assertEq(diamond.getAssetStruct(asset).ercDebt, 0);
        assertEq(diamond.getAssetStruct(asset).ercDebtRate, 0);
    }

    function testBatchLiquidateWallet() public {
        MTypes.BatchMC[] memory batches = makeShortsAndCreateBatch();
        batchLiquidateAndCheckBal({batches: batches, isWallet: WALLET});
    }

    function testBatchLiquidateErcEscrowed() public {
        MTypes.BatchMC[] memory batches = makeShortsAndCreateBatch();
        batchLiquidateAndCheckBal({batches: batches, isWallet: ERC_ESCROWED});
    }

    // Batch liquidation including the TAPP short
    function batchLiquidateTappAndCheckBal(MTypes.BatchMC[] memory batches, bool isWallet)
        public
    {
        _setETH(4000 ether); // return to normal so shorts can match
        // Create TAPP short
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, tapp);
        // Since the tapp already has short in position 2, combine with the newly created short Constants.SHORT_STARTING_ID + 1
        // This should never happen in practice since the tapp doesnt make shorts, just for ease of testing
        vm.prank(tapp);
        combineShorts({
            id1: Constants.SHORT_STARTING_ID,
            id2: Constants.SHORT_STARTING_ID + 1
        });

        _setETH(750 ether); //roughly get cratio between 1.1 and 1.5

        // Partial margin call of TAPP short, divide by 2 (half)
        uint256 liquidatorCollateralFromTapp = getShortRecord(
            tapp, Constants.SHORT_STARTING_ID
        ).ercDebt.mul(testFacet.getOraclePriceT(asset)) / 2;

        uint256 totalCollateral;
        uint256 liquidatorCollateral;
        for (uint8 i; i < 3; i++) {
            uint8 id = Constants.SHORT_STARTING_ID + i;
            totalCollateral += getShortRecord(sender, id).collateral;
            liquidatorCollateral +=
                getShortRecord(sender, id).ercDebt.mul(testFacet.getOraclePriceT(asset));
        }

        assertEq(diamond.getAssetStruct(asset).ercDebt, DEFAULT_AMOUNT * 4);

        MTypes.BatchMC[] memory batchesTapp =
            new MTypes.BatchMC[](getShortRecordCount(sender) + 1);
        batchesTapp[0] = batches[0];
        batchesTapp[1] = batches[1];
        batchesTapp[2] = batches[2];
        batchesTapp[3] =
            MTypes.BatchMC({shorter: tapp, shortId: Constants.SHORT_STARTING_ID});

        // liquidate 3/3 sender shorts, 0.5/1 tapp short
        if (isWallet) {
            vm.prank(_diamond);
            token.mint(extra, DEFAULT_AMOUNT * 7 / 2);
            assertEq(token.balanceOf(extra), DEFAULT_AMOUNT * 7 / 2);
        } else {
            depositUsd(extra, DEFAULT_AMOUNT * 7 / 2);
            e.ercEscrowed = DEFAULT_AMOUNT.mulU88(3.5 ether);
        }
        e.ethEscrowed = 0;
        assertStruct(extra, e);
        vm.prank(extra);
        diamond.liquidateSecondary(asset, batchesTapp, DEFAULT_AMOUNT * 7 / 2, isWallet);

        //margin caller gets collateral
        e.ethEscrowed = liquidatorCollateral + liquidatorCollateralFromTapp;
        e.ercEscrowed = 0;
        assertStruct(extra, e);
        assertEq(token.balanceOf(extra), 0);
        s.ethEscrowed = totalCollateral - liquidatorCollateral;
        s.ercEscrowed = 0;
        assertStruct(sender, s);
        assertEq(getShortRecordCount(sender), 0);
        t.ethEscrowed = 0;
        t.ercEscrowed = 0;
        assertStruct(tapp, t);
        assertEq(getShortRecordCount(tapp), 1);

        // check system debt
        assertEq(diamond.getAssetStruct(asset).ercDebt, DEFAULT_AMOUNT / 2); // Leftover from TAPP short
        assertEq(diamond.getAssetStruct(asset).ercDebtRate, 0);
    }

    function testBatchLiquidateWalletTappShort() public {
        MTypes.BatchMC[] memory batches = makeShortsAndCreateBatch();
        batchLiquidateTappAndCheckBal({batches: batches, isWallet: WALLET});
    }

    function testBatchLiquidateErcEscrowedTappShort() public {
        MTypes.BatchMC[] memory batches = makeShortsAndCreateBatch();
        batchLiquidateTappAndCheckBal({batches: batches, isWallet: ERC_ESCROWED});
    }

    //function test skip conditions
    function testRevertNoValidShortsCantLiquidateCancelled() public {
        MTypes.BatchMC[] memory batches = makeShortsAndCreateBatch();

        vm.prank(_diamond);
        token.mint(sender, DEFAULT_AMOUNT * 3);
        exitShortWallet(Constants.SHORT_STARTING_ID, DEFAULT_AMOUNT, sender);
        exitShortWallet(Constants.SHORT_STARTING_ID + 1, DEFAULT_AMOUNT, sender);
        exitShortWallet(Constants.SHORT_STARTING_ID + 2, DEFAULT_AMOUNT, sender);

        vm.expectRevert(Errors.MarginCallSecondaryNoValidShorts.selector);
        diamond.liquidateSecondary(asset, batches, DEFAULT_AMOUNT * 3, WALLET);
        vm.expectRevert(Errors.MarginCallSecondaryNoValidShorts.selector);
        diamond.liquidateSecondary(asset, batches, DEFAULT_AMOUNT * 3, ERC_ESCROWED);
    }

    function testRevertNoValidShortsCratioNotLowEnough() public {
        MTypes.BatchMC[] memory batches = makeShortsAndCreateBatch();

        //increase collateral of short Constants.SHORT_STARTING_ID + 1
        depositEth(sender, 0.015 ether);
        vm.startPrank(sender);
        increaseCollateral(Constants.SHORT_STARTING_ID, 0.005 ether);
        increaseCollateral(Constants.SHORT_STARTING_ID + 1, 0.005 ether);
        increaseCollateral(Constants.SHORT_STARTING_ID + 2, 0.005 ether);
        vm.stopPrank();

        vm.expectRevert(Errors.MarginCallSecondaryNoValidShorts.selector);
        diamond.liquidateSecondary(asset, batches, DEFAULT_AMOUNT * 3, WALLET);
        vm.expectRevert(Errors.MarginCallSecondaryNoValidShorts.selector);
        diamond.liquidateSecondary(asset, batches, DEFAULT_AMOUNT * 3, ERC_ESCROWED);
    }

    function testRevertNoValidShortsCantLiquidateSelf() public {
        MTypes.BatchMC[] memory batches = makeShortsAndCreateBatch();
        vm.prank(sender);
        vm.expectRevert(Errors.MarginCallSecondaryNoValidShorts.selector);
        diamond.liquidateSecondary(asset, batches, DEFAULT_AMOUNT * 3, WALLET);
        vm.expectRevert(Errors.MarginCallSecondaryNoValidShorts.selector);
        diamond.liquidateSecondary(asset, batches, DEFAULT_AMOUNT * 3, ERC_ESCROWED);
    }

    function testRevertNoValidShortsNotEnoughWalletBal() public {
        MTypes.BatchMC[] memory batches = makeShortsAndCreateBatch();
        assertEq(token.balanceOf(extra), 0);
        vm.prank(extra);
        vm.expectRevert(Errors.MarginCallSecondaryNoValidShorts.selector);
        diamond.liquidateSecondary(asset, batches, DEFAULT_AMOUNT * 3, WALLET);
        vm.expectRevert(Errors.MarginCallSecondaryNoValidShorts.selector);
        diamond.liquidateSecondary(asset, batches, DEFAULT_AMOUNT * 3, ERC_ESCROWED);
    }

    function testRevertNoValidShortsErcDebtTooHigh() public {
        MTypes.BatchMC[] memory batches = makeShortsAndCreateBatch();
        vm.prank(_diamond);
        token.mint(extra, DEFAULT_AMOUNT * 3);
        assertEq(token.balanceOf(extra), DEFAULT_AMOUNT * 3);
        vm.prank(extra);
        vm.expectRevert(Errors.MarginCallSecondaryNoValidShorts.selector);
        diamond.liquidateSecondary(asset, batches, 0.5 ether, WALLET);
        vm.expectRevert(Errors.MarginCallSecondaryNoValidShorts.selector);
        diamond.liquidateSecondary(asset, batches, 0.5 ether, ERC_ESCROWED);
    }

    function testRevertNoValidShortsIdGtMaxId() public {
        makeShortsAndCreateBatch();
        //make new batch
        MTypes.BatchMC[] memory batches = new MTypes.BatchMC[](1);
        batches[0] = MTypes.BatchMC({shorter: extra, shortId: 110});

        vm.prank(sender);
        vm.expectRevert(stdError.divisionError);
        diamond.liquidateSecondary(asset, batches, DEFAULT_AMOUNT * 3, WALLET);
        vm.expectRevert(stdError.divisionError);
        diamond.liquidateSecondary(asset, batches, DEFAULT_AMOUNT * 3, ERC_ESCROWED);
    }

    function testRevertNoValidShortsIdLtStartingId() public {
        makeShortsAndCreateBatch();
        //make new batch
        MTypes.BatchMC[] memory batches = new MTypes.BatchMC[](1);
        batches[0] = MTypes.BatchMC({shorter: extra, shortId: 1});

        vm.prank(sender);
        vm.expectRevert(stdError.divisionError);
        diamond.liquidateSecondary(asset, batches, DEFAULT_AMOUNT * 3, WALLET);
        vm.expectRevert(stdError.divisionError);
        diamond.liquidateSecondary(asset, batches, DEFAULT_AMOUNT * 3, ERC_ESCROWED);
    }

    //Testing when liquidator hits their desired liquidationAmount

    function checkEarlyBreakBal(bool isWallet) public {
        //margin caller gets collateral
        e.ethEscrowed = getShortRecord(sender, Constants.SHORT_STARTING_ID).ercDebt.mul(
            testFacet.getOraclePriceT(asset)
        )
            + getShortRecord(sender, Constants.SHORT_STARTING_ID + 1).ercDebt.mul(
                testFacet.getOraclePriceT(asset)
            );

        if (isWallet) {
            e.ercEscrowed = 0;
            assertEq(token.balanceOf(extra), DEFAULT_AMOUNT);
        } else {
            e.ercEscrowed = DEFAULT_AMOUNT;
        }

        assertStruct(extra, e);
        s.ethEscrowed = getShortRecord(sender, Constants.SHORT_STARTING_ID).collateral
            + getShortRecord(sender, Constants.SHORT_STARTING_ID + 1).collateral
            - (
                getShortRecord(sender, Constants.SHORT_STARTING_ID).ercDebt.mul(
                    testFacet.getOraclePriceT(asset)
                )
                    + getShortRecord(sender, Constants.SHORT_STARTING_ID + 1).ercDebt.mul(
                        testFacet.getOraclePriceT(asset)
                    )
            );

        s.ercEscrowed = 0;
        assertStruct(sender, s);
        assertEq(getShortRecordCount(sender), 1);

        //check system debt
        assertEq(diamond.getAssetStruct(asset).ercDebt, DEFAULT_AMOUNT);
        assertEq(diamond.getAssetStruct(asset).ercDebtRate, 0);
    }

    function testBatchLiquidateWalletEarlyBreak() public {
        MTypes.BatchMC[] memory batches = makeShortsAndCreateBatch();
        vm.prank(_diamond);
        token.mint(extra, DEFAULT_AMOUNT * 3);
        assertEq(token.balanceOf(extra), DEFAULT_AMOUNT * 3);
        vm.prank(extra);

        diamond.liquidateSecondary(asset, batches, DEFAULT_AMOUNT * 2, WALLET);

        checkEarlyBreakBal({isWallet: WALLET});
    }

    function testBatchLiquidateErcEscrowedEarlyBreak() public {
        MTypes.BatchMC[] memory batches = makeShortsAndCreateBatch();

        depositUsd(extra, DEFAULT_AMOUNT * 3);
        e.ercEscrowed = DEFAULT_AMOUNT * 3;
        vm.prank(extra);

        diamond.liquidateSecondary(asset, batches, DEFAULT_AMOUNT * 2, ERC_ESCROWED);

        checkEarlyBreakBal({isWallet: ERC_ESCROWED});
    }

    function testBatchLiquidateWalletSkipShortWithErcDebtGtLiquidationAmount() public {
        MTypes.BatchMC[] memory batches = makeShortsAndCreateBatch();
        vm.prank(_diamond);
        token.mint(extra, DEFAULT_AMOUNT * 3);
        assertEq(token.balanceOf(extra), DEFAULT_AMOUNT * 3);
        vm.prank(extra);
        diamond.liquidateSecondary(asset, batches, DEFAULT_AMOUNT * 2 + 1 wei, WALLET);

        checkEarlyBreakBal({isWallet: WALLET});
    }

    function testBatchLiquidateErcEscrowedSkipShortWithErcDebtGtLiquidationAmount()
        public
    {
        MTypes.BatchMC[] memory batches = makeShortsAndCreateBatch();
        depositUsd(extra, DEFAULT_AMOUNT * 3);
        e.ercEscrowed = DEFAULT_AMOUNT * 3;
        vm.prank(extra);
        diamond.liquidateSecondary(
            asset, batches, DEFAULT_AMOUNT * 2 + 1 wei, ERC_ESCROWED
        );

        checkEarlyBreakBal({isWallet: ERC_ESCROWED});
    }
}
