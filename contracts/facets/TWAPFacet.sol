// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {Modifiers} from "contracts/libraries/AppStorage.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {Constants} from "contracts/libraries/Constants.sol";
import {
    OracleLibrary, IUniswapV3Pool
} from "contracts/libraries/UniswapOracleLibrary.sol";

// import {console} from "contracts/libraries/console.sol";

contract TWAPFacet is Modifiers {
    //@dev Computes arithmetic mean of prices between current time and x seconds ago.
    //@dev Uses parts of underlying code for OracleLibrary.consult()
    function estimateWETHInUSDC(uint128 amountIn, uint32 secondsAgo)
        external
        view
        returns (uint256 amountOut)
    {
        if (secondsAgo <= 0) {
            revert Errors.InvalidTWAPSecondsAgo();
        }

        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = secondsAgo;
        secondsAgos[1] = 0;

        //@dev Returns the cumulative tick and liquidity as of each timestamp secondsAgo from the current block timestamp
        (int56[] memory tickCumulatives,) =
            IUniswapV3Pool(Constants.USDC_WETH).observe(secondsAgos);

        int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];
        int24 tick = int24(tickCumulativesDelta / int32(secondsAgo));

        // Always round to negative infinity
        if (tickCumulativesDelta < 0 && (tickCumulativesDelta % int32(secondsAgo) != 0)) {
            tick--;
        }

        //@dev Gets price using this formula: p(i) = 1.0001**i, where i is the tick
        amountOut =
            OracleLibrary.getQuoteAtTick(tick, amountIn, Constants.WETH, Constants.USDC);
    }
}
