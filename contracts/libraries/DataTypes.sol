// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

// import {console} from "contracts/libraries/console.sol";

//@dev leave room for others frozen types
//@dev Asset frozen status
enum F {
    Unfrozen,
    Permanent
}

// @dev if this is changed, modify orderTypetoString in libraries/console.sol
// @dev Order types
enum O {
    Uninitialized,
    LimitBid,
    LimitAsk,
    MarketBid,
    MarketAsk,
    LimitShort,
    Cancelled,
    Matched
}

// @dev ShortRecord status
enum SR {
    PartialFill,
    FullyFilled,
    Cancelled
}

// @dev oracle frequency
enum OF {
    OneHour,
    FifteenMinutes
}

// 2**n-1 with 18 decimals (prices, amount)
// uint64 = 18.45
// uint72 = 4.722k
// uint80 = 1.2m
// uint88 = 300m
// uint96 = 79B
// uint104 = 1.2t

// DataTypes used in storage
library STypes {
    // 2 slots
    struct Order {
        // SLOT 1: 88 + 80 + 16 + 16 + 16 + 8 + 8 + 16 + 8 = 256
        uint88 ercAmount; // max 300m erc
        uint80 price; // max 1.2m eth
        // max orders 65k, with id re-use
        uint16 prevId;
        uint16 id;
        uint16 nextId;
        O orderType;
        O prevOrderType;
        // @dev storing as 500 with 2 decimals -> 5.00 ether
        uint16 initialMargin; // @dev only used for LimitShort
        uint8 shortRecordId; // @dev only used for LimitShort
        // SLOT 2: 160 + 32 = 192 (64 unused)
        address addr; // 160
        // @dev to prevent overflow in 2106, we diff against contract creation timestamp
        uint32 creationTime; // seconds
        uint64 filler;
    }

    // 2 slots
    // @dev zethYieldRate should match Vault
    struct ShortRecord {
        // SLOT 1: 88 + 88 + 8 + 8 + 8 + 8 = 208 (48 remaining)
        uint88 collateral; // price * ercAmount * initialMargin
        uint88 ercDebt; // same as Order.ercAmount
        SR status;
        uint8 prevId;
        uint8 id;
        uint8 nextId;
        // SLOT 2: 80 + 64 + 40 + 24 + 24 = 224 (24 remaining)
        uint80 zethYieldRate;
        uint64 ercDebtRate; // socialized penalty rate
        uint40 tokenId; //As of 2023, Ethereum had ~2B total tx. Uint40 max value is 1T, which is more than enough
        uint24 flaggerId;
        uint24 updatedAt; // hours
    }

    struct NFT {
        // SLOT 1: 160 + 8 + 8 = 176 (80 unused)
        address owner;
        uint8 assetId;
        uint8 shortRecordId;
    }

    // uint8:  [0-255]
    // uint16: [0-65_535]
    // @dev see testMultiAssetSettings()
    struct Asset {
        // SLOT 1: 104 + 88 + 16 + 16 + 16 + 8 + 8 = 256 (0 unused)
        uint104 ercDebt; // max 20.2T
        uint88 zethCollateral;
        uint16 startingShortId;
        uint16 orderId; // max is uint16 but need to throw/handle that?
        uint16 initialMargin; // 5 ether -> [1-10, 2 decimals]
        F frozen; // 0 or 1
        uint8 vault;
        // SLOT 2 (Liquidation Parameters)
        // 64 + 16*6 + 8*7 = 216 (40 unused)
        // socialized penalty rate
        uint64 ercDebtRate; // max 18x
        uint16 minShortErc; // 2000 -> (2000 * 10**18) -> 2000 ether
        uint16 resetLiquidationTime; // 16 hours -> [1-48 hours, 2 decimals]
        uint16 secondLiquidationTime; // 12 hours -> [1-48 hours, 2 decimals]
        uint16 firstLiquidationTime; // 10 hours -> [1-48 hours, 2 decimals]
        uint16 primaryLiquidationCR; // 4 ether -> [1-5, 2 decimals]
        uint16 secondaryLiquidationCR; // 1.5 ether -> [1-5, 2 decimals]
        uint8 minimumCR; // 1.1 ether -> [1-2, 2 decimals]
        uint8 assetId;
        uint8 minBidEth; // 1 -> (1 * 10**18 / 10**3) = .001 ether
        uint8 minAskEth; // 1 -> (1 * 10**18 / 10**3) = .001 ether
        uint8 forcedBidPriceBuffer; // 1.1 ether -> [1-2, 2 decimals]
        uint8 tappFeePct;
        uint8 callerFeePct;
        uint40 filler2;
        // SLOT 3 (Chainlink)
        address oracle; // for non-usd asset
        uint96 filler; // keep slots distinct
    }

    // 3 slots
    // @dev zethYieldRate should match ShortRecord
    struct Vault {
        // SLOT 1: 88 + 88 + 80 = 256 (0 unused)
        uint88 zethCollateral; // max 309m, 18 decimals
        uint88 zethTotal; // max 309m, 18 decimals
        uint80 zethYieldRate; // onlyUp
        // SLOT 2: 88 + 32 + 16 = 136 (120 unused)
        // tracked for shorter ditto rewards
        uint88 zethCollateralReward; // onlyUp
        uint32 dittoShorterRate; // per unit of zethCollateral
        uint16 zethTithePercent; // [0-100, 2 decimals]
        uint120 filler2;
        // SLOT 3: 128 + 96 + 16 + 16 = 256
        uint128 dittoMatchedShares;
        uint96 dittoMatchedReward; // max 79B, 18 decimals
        uint16 dittoMatchedRate;
        uint16 dittoMatchedTime; // last claim (in days) from STARTING_TIME
    }

    // 1 slots
    struct AssetUser {
        // SLOT 1: 104 + 24 + 24 + 8 = 160 (96 unused)
        uint104 ercEscrowed;
        uint24 g_flaggerId;
        uint24 g_updatedAt; // represents the most recent flag - in hours
        uint8 shortRecordId;
        uint96 filler;
    }

    // 1 slots
    struct VaultUser {
        // SLOT 1: 88 + 88 + 80 = 256 (0 unused)
        uint88 ethEscrowed;
        uint88 dittoMatchedShares;
        uint80 dittoReward; // max 1.2m, 18 decimals
    }

    struct Bridge {
        // SLOT 1: 16 + 8 + 8 = 32 (224 unused)
        uint16 withdrawalFee;
        uint8 unstakeFee;
        uint8 vault;
    }
}

// @dev DataTypes only used in memory
library MTypes {
    struct OrderHint {
        uint16 hintId;
        uint256 creationTime;
    }

    struct BatchMC {
        address shorter;
        uint8 shortId;
    }

    struct Match {
        uint88 fillEth;
        uint88 fillErc;
        uint88 colUsed;
        uint88 dittoMatchedShares;
        // Below used only for bids
        uint88 shortFillEth; // Includes colUsed + fillEth from shorts
        uint96 askFillErc; // Subset of fillErc
        bool ratesQueried; // Save gas when matching shorts
        uint80 zethYieldRate;
        uint64 ercDebtRate;
    }

    struct ExitShort {
        address asset;
        uint256 ercDebt;
        uint88 collateral;
        uint88 ethFilled;
        uint88 ercAmountLeft;
        uint88 ercFilled;
        uint256 beforeExitCR;
    }

    struct CombineShorts {
        bool shortFlagExists;
        uint24 shortUpdatedAt;
    }

    struct MarginCallPrimary {
        address asset;
        uint256 vault;
        STypes.ShortRecord short;
        address shorter;
        uint256 cRatio;
        uint80 oraclePrice;
        uint256 forcedBidPriceBuffer;
        uint256 ethDebt;
        uint88 ethFilled;
        uint88 ercDebtMatched;
        bool loseCollateral;
        uint256 tappFeePct;
        uint256 callerFeePct;
        uint88 gasFee;
        uint88 totalFee; // gasFee + tappFee + callerFee
        uint256 minimumCR;
    }

    struct MarginCallSecondary {
        address asset;
        uint256 vault;
        STypes.ShortRecord short;
        address shorter;
        uint256 cRatio;
        uint256 minimumCR;
        uint88 liquidatorCollateral;
    }

    struct BidMatchAlgo {
        uint16 askId;
        uint16 shortHintId;
        uint16 shortId;
        uint16 prevShortId;
        uint16 firstShortIdBelowOracle;
        uint16 matchedAskId;
        uint16 matchedShortId;
        bool isMovingBack;
        bool isMovingFwd;
        uint256 oraclePrice;
    }

    struct CreateVaultParams {
        uint16 zethTithePercent;
        uint16 dittoMatchedRate;
        uint16 dittoShorterRate;
    }

    struct CreateLimitShortParam {
        address asset;
        uint256 eth;
        uint256 minShortErc;
        uint256 minAskEth;
        uint16 startingId;
        uint256 oraclePrice;
    }
}
