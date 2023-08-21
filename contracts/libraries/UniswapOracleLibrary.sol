// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

// https://github.com/Uniswap/v3-periphery/blob/b325bb0905d922ae61fcc7df85ee802e8df5e96c/contracts/libraries/OracleLibrary.sol

import {TickMath} from "contracts/libraries/UniswapTickMath.sol";
import {U256} from "contracts/libraries/PRBMathHelper.sol";

interface IUniswapV3Pool {
    function observe(uint32[] calldata secondsAgos)
        external
        view
        returns (
            int56[] memory tickCumulatives,
            uint160[] memory secondsPerLiquidityCumulativeX128s
        );
}

/* solhint-disable */

/// @title Oracle library
/// @notice Provides functions to integrate with V3 pool oracle
library OracleLibrary {
    /// @notice Given a tick and a token amount, calculates the amount of token received in exchange
    /// @param tick Tick value used to calculate the quote
    /// @param baseAmount Amount of token to be converted
    /// @param baseToken Address of an ERC20 token contract used as the baseAmount denomination
    /// @param quoteToken Address of an ERC20 token contract used as the quoteAmount denomination
    /// @return quoteAmount Amount of quoteToken received for baseAmount of baseToken
    function getQuoteAtTick(
        int24 tick,
        uint128 baseAmount,
        address baseToken,
        address quoteToken
    ) internal pure returns (uint256 quoteAmount) {
        uint160 sqrtRatioX96 = TickMath.getSqrtRatioAtTick(tick);

        // Calculate quoteAmount with better precision if it doesn't overflow when multiplied by itself
        if (sqrtRatioX96 <= type(uint128).max) {
            uint256 ratioX192 = uint256(sqrtRatioX96) * sqrtRatioX96;
            quoteAmount = baseToken < quoteToken
                ? U256.mulDiv(ratioX192, baseAmount, 1 << 192)
                : U256.mulDiv(1 << 192, baseAmount, ratioX192);
        } else {
            uint256 ratioX128 = U256.mulDiv(sqrtRatioX96, sqrtRatioX96, 1 << 64);
            quoteAmount = baseToken < quoteToken
                ? U256.mulDiv(ratioX128, baseAmount, 1 << 128)
                : U256.mulDiv(1 << 128, baseAmount, ratioX128);
        }
    }
}
