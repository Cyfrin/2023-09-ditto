// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U80} from "contracts/libraries/PRBMathHelper.sol";

import {Errors} from "contracts/libraries/Errors.sol";
import {Events} from "contracts/libraries/Events.sol";
import {STypes, MTypes, O} from "contracts/libraries/DataTypes.sol";
import {Modifiers} from "contracts/libraries/AppStorage.sol";
import {LibAsset} from "contracts/libraries/LibAsset.sol";
import {LibOrders} from "contracts/libraries/LibOrders.sol";

// import {console} from "contracts/libraries/console.sol";

contract AskOrdersFacet is Modifiers {
    using U256 for uint256;
    using U80 for uint80;

    /**
     * @notice Creates ask order in market
     * @dev IncomingAsk created here instead of AskMatchAlgo to prevent stack too deep
     *
     * @param asset The market that will be impacted
     * @param price Unit price in eth for erc sold
     * @param ercAmount Amount of erc sold
     * @param isMarketOrder Boolean for whether the ask is limit or market
     * @param orderHintArray Array of hint ID for gas-optimized sorted placement on market
     */
    function createAsk(
        address asset,
        uint80 price,
        uint88 ercAmount,
        bool isMarketOrder,
        MTypes.OrderHint[] calldata orderHintArray
    ) external isNotFrozen(asset) onlyValidAsset(asset) nonReentrant {
        uint256 eth = price.mul(ercAmount);
        uint256 minAskEth = LibAsset.minAskEth(asset);
        if (eth < minAskEth) revert Errors.OrderUnderMinimumSize();

        if (s.assetUser[asset][msg.sender].ercEscrowed < ercAmount) {
            revert Errors.InsufficientERCEscrowed();
        }

        STypes.Order memory incomingAsk;
        incomingAsk.addr = msg.sender;
        incomingAsk.price = price;
        incomingAsk.ercAmount = ercAmount;
        incomingAsk.id = s.asset[asset].orderId;
        incomingAsk.orderType = isMarketOrder ? O.MarketAsk : O.LimitAsk;
        incomingAsk.creationTime = LibOrders.getOffsetTime();

        //@dev asks don't need to be concerned with shortHintId
        LibOrders.sellMatchAlgo(asset, incomingAsk, orderHintArray, minAskEth);
        emit Events.CreateAsk(asset, msg.sender, incomingAsk.id, incomingAsk.creationTime);
    }
}
