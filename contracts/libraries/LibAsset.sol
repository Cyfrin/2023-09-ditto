// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {AppStorage, appStorage} from "contracts/libraries/AppStorage.sol";
import {Constants} from "contracts/libraries/Constants.sol";
import {IAsset} from "interfaces/IAsset.sol";
import {Errors} from "contracts/libraries/Errors.sol";

library LibAsset {
    // @dev used in ExitShortWallet and MarketShutDown
    function burnMsgSenderDebt(address asset, uint88 debt) internal {
        IAsset tokenContract = IAsset(asset);
        uint256 walletBalance = tokenContract.balanceOf(msg.sender);
        if (walletBalance < debt) revert Errors.InsufficientWalletBalance();
        tokenContract.burnFrom(msg.sender, debt);
        assert(tokenContract.balanceOf(msg.sender) < walletBalance);
    }

    // default of 16 hours, stored in uint16 as 16
    // range of [1-48 hours],
    // 2 decimal places, divide by 100
    // i.e. 123 -> 1.23 hours
    // @dev timestamp when it's past time to liquidate a ShortRecord using primary margin call
    function resetLiquidationTime(address asset) internal view returns (uint256) {
        AppStorage storage s = appStorage();
        return uint256(s.asset[asset].resetLiquidationTime) / Constants.TWO_DECIMAL_PLACES;
    }

    // default of 12 hours, stored in uint16 as 12
    // range of [1-48 hours],
    // 2 decimal places, divide by 100
    // i.e. 123 -> 1.23 hours
    // @dev timestamp when anyone can liquidate a ShortRecord using primary margin call
    function secondLiquidationTime(address asset) internal view returns (uint256) {
        AppStorage storage s = appStorage();
        return
            uint256(s.asset[asset].secondLiquidationTime) / Constants.TWO_DECIMAL_PLACES;
    }

    // default of 10 hours, stored in uint16 as 10
    // range of [1-48 hours],
    // 2 decimal places, divide by 100
    // i.e. 123 -> 1.23 hours
    // @dev timestamp when only the flagger address can liquidate a ShortRecord using primary margin call
    function firstLiquidationTime(address asset) internal view returns (uint256) {
        AppStorage storage s = appStorage();
        return uint256(s.asset[asset].firstLiquidationTime) / Constants.TWO_DECIMAL_PLACES;
    }

    // default of 5 ether, stored in uint16 as 500
    // range of [1-10],
    // 2 decimal places, divide by 100
    // i.e. 123 -> 1.23 ether
    // @dev cRatio that a short order has to begin at
    function initialMargin(address asset) internal view returns (uint256) {
        AppStorage storage s = appStorage();
        return (uint256(s.asset[asset].initialMargin) * 1 ether)
            / Constants.TWO_DECIMAL_PLACES;
    }

    // default of 4 ether, stored in uint16 as 400
    // range of [1-5],
    // 2 decimal places, divide by 100
    // i.e. 120 -> 1.2 ether
    // less than initialMargin
    // @dev cRatio that a short order can be liquidated at
    function primaryLiquidationCR(address asset) internal view returns (uint256) {
        AppStorage storage s = appStorage();
        return (uint256(s.asset[asset].primaryLiquidationCR) * 1 ether)
            / Constants.TWO_DECIMAL_PLACES;
    }

    // default of 1.5 ether, stored in uint16 as 150
    // range of [1-5],
    // 2 decimal places, divide by 100
    // i.e. 120 -> 1.2 ether
    // @dev cRatio that allows for secondary liquidations to happen
    // @dev via wallet or ercEscrowed (vault deposited usd)
    function secondaryLiquidationCR(address asset) internal view returns (uint256) {
        AppStorage storage s = appStorage();
        return (uint256(s.asset[asset].secondaryLiquidationCR) * 1 ether)
            / Constants.TWO_DECIMAL_PLACES;
    }

    // default of 1.1 ether, stored in uint8 as 110
    // range of [1-2],
    // 2 decimal places, divide by 100
    // i.e. 120 -> 1.2 ether
    // less than primaryLiquidationCR
    // @dev buffer/slippage for forcedBid price
    function forcedBidPriceBuffer(address asset) internal view returns (uint256) {
        AppStorage storage s = appStorage();
        return (uint256(s.asset[asset].forcedBidPriceBuffer) * 1 ether)
            / Constants.TWO_DECIMAL_PLACES;
    }

    // default of 1.1 ether, stored in uint8 as 110
    // range of [1-2],
    // 2 decimal places, divide by 100
    // i.e. 120 -> 1.2 ether
    // @dev cRatio where a shorter loses all collateral on liquidation
    function minimumCR(address asset) internal view returns (uint256) {
        AppStorage storage s = appStorage();
        return
            (uint256(s.asset[asset].minimumCR) * 1 ether) / Constants.TWO_DECIMAL_PLACES;
    }

    // default of .025 ether, stored in uint8 as 25
    // range of [1-2],
    // 3 decimal places, divide by 1000
    // i.e. 1234 -> 1.234 ether
    // @dev percentage of fees given to TAPP during liquidations
    function tappFeePct(address asset) internal view returns (uint256) {
        AppStorage storage s = appStorage();
        return (uint256(s.asset[asset].tappFeePct) * 1 ether)
            / Constants.THREE_DECIMAL_PLACES;
    }

    // default of .005 ether, stored in uint8 as 5
    // range of [1-2],
    // 3 decimal places, divide by 1000
    // i.e. 1234 -> 1.234 ether
    // @dev percentage of fees given to the margin caller during liquidations
    function callerFeePct(address asset) internal view returns (uint256) {
        AppStorage storage s = appStorage();
        return (uint256(s.asset[asset].callerFeePct) * 1 ether)
            / Constants.THREE_DECIMAL_PLACES;
    }

    // default of .001 ether, stored in uint8 as 1
    // range of [.001 - .255],
    // 3 decimal places, divide by 1000
    // i.e. 125 -> 0.125 ether
    // @dev dust amount
    function minBidEth(address asset) internal view returns (uint256) {
        AppStorage storage s = appStorage();
        return
            (uint256(s.asset[asset].minBidEth) * 1 ether) / Constants.THREE_DECIMAL_PLACES;
    }

    // default of .001 ether, stored in uint8 as 1
    // range of [.001 - .255],
    // 3 decimal places, divide by 1000
    // i.e. 125 -> 0.125 ether
    // @dev dust amount
    function minAskEth(address asset) internal view returns (uint256) {
        AppStorage storage s = appStorage();
        return
            (uint256(s.asset[asset].minAskEth) * 1 ether) / Constants.THREE_DECIMAL_PLACES;
    }

    // default of 2000 ether, stored in uint16 as 2000
    // range of [1 - 65,535 (uint16 max)],
    // i.e. 2000 -> 2000 ether
    // @dev min short record debt
    function minShortErc(address asset) internal view returns (uint256) {
        AppStorage storage s = appStorage();
        return uint256(s.asset[asset].minShortErc) * 1 ether;
    }
}
