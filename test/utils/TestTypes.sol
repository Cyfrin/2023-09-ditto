// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {F} from "contracts/libraries/DataTypes.sol";

enum PrimaryScenarios {
    CRatioBetween110And200,
    CRatioBelow110,
    CRatioBelow110BlackSwan
}
// @dev only used for testing

enum SecondaryScenarios {
    CRatioBetween110And150,
    CRatioBetween100And110,
    CRatioBelow100
}
// @dev only used for testing

enum SecondaryType {
    LiquidateErcEscrowed,
    LiquidateWallet
}

library TestTypes {
    struct StorageUser {
        address addr;
        uint256 ethEscrowed;
        uint256 ercEscrowed;
    }

    struct AssetNormalizedStruct {
        F frozen;
        uint16 orderId;
        uint256 initialMargin;
        uint256 primaryLiquidationCR;
        uint256 secondaryLiquidationCR;
        uint256 forcedBidPriceBuffer;
        uint256 minimumCR;
        uint256 tappFeePct;
        uint256 callerFeePct;
        uint256 resetLiquidationTime;
        uint256 secondLiquidationTime;
        uint256 firstLiquidationTime;
        uint16 startingShortId;
        uint256 minBidEth;
        uint256 minAskEth;
        uint256 minShortErc;
        uint8 assetId;
    }

    struct BridgeNormalizedStruct {
        uint256 withdrawalFee;
        uint256 unstakeFee;
    }

    struct MockOracleData {
        uint80 roundId;
        int256 answer;
        uint256 startedAt;
        uint256 updatedAt;
        uint80 answeredInRound;
    }
}
