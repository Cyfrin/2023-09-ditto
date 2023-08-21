// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U88} from "contracts/libraries/PRBMathHelper.sol";

import {Modifiers} from "contracts/libraries/AppStorage.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {STypes, O, SR} from "contracts/libraries/DataTypes.sol";
import {LibDiamond} from "contracts/libraries/LibDiamond.sol";
import {LibOrders} from "contracts/libraries/LibOrders.sol";
import {LibOracle} from "contracts/libraries/LibOracle.sol";
import {LibShortRecord} from "contracts/libraries/LibShortRecord.sol";
import {Constants} from "contracts/libraries/Constants.sol";

// import {console} from "contracts/libraries/console.sol";

contract OrdersFacet is Modifiers {
    using U256 for uint256;
    using U88 for uint88;
    using LibOrders for mapping(address => mapping(uint16 => STypes.Order));

    /**
     * @notice Cancels unfilled bid on market
     *
     * @param asset The market that will be impacted
     * @param id Id of bid
     */

    function cancelBid(address asset, uint16 id)
        external
        onlyValidAsset(asset)
        nonReentrant
    {
        STypes.Order storage bid = s.bids[asset][id];
        if (msg.sender != bid.addr) revert Errors.NotOwner();
        O orderType = bid.orderType;
        if (orderType == O.Cancelled || orderType == O.Matched) {
            revert Errors.NotActiveOrder();
        }

        uint256 vault = s.asset[asset].vault;
        uint88 eth = bid.ercAmount.mulU88(bid.price);
        s.vaultUser[vault][msg.sender].ethEscrowed += eth;

        s.bids.cancelOrder(asset, id);
    }

    /**
     * @notice Cancels unfilled ask on market
     *
     * @param asset The market that will be impacted
     * @param id Id of ask
     */

    function cancelAsk(address asset, uint16 id)
        external
        onlyValidAsset(asset)
        nonReentrant
    {
        STypes.Order storage ask = s.asks[asset][id];
        if (msg.sender != ask.addr) revert Errors.NotOwner();
        O orderType = ask.orderType;
        if (orderType == O.Cancelled || orderType == O.Matched) {
            revert Errors.NotActiveOrder();
        }

        s.assetUser[asset][msg.sender].ercEscrowed += ask.ercAmount;

        s.asks.cancelOrder(asset, id);
    }

    /**
     * @notice Cancels unfilled short on market
     *
     * @param asset The market that will be impacted
     * @param id Id of short
     */

    function cancelShort(address asset, uint16 id)
        external
        onlyValidAsset(asset)
        nonReentrant
    {
        STypes.Order storage short = s.shorts[asset][id];
        if (msg.sender != short.addr) revert Errors.NotOwner();
        O orderType = short.orderType;
        if (orderType == O.Cancelled || orderType == O.Matched) {
            revert Errors.NotActiveOrder();
        }

        STypes.Asset storage Asset = s.asset[asset];
        uint88 eth = short.ercAmount.mulU88(short.price).mulU88(
            LibOrders.convertCR(short.initialMargin)
        );
        s.vaultUser[Asset.vault][msg.sender].ethEscrowed += eth;

        // Update ShortRecord if exists
        uint8 shortRecordId = short.shortRecordId;
        if (shortRecordId >= Constants.SHORT_STARTING_ID) {
            STypes.ShortRecord storage shortRecord =
                s.shortRecords[asset][msg.sender][shortRecordId];
            if (shortRecord.status == SR.Cancelled) {
                LibShortRecord.deleteShortRecord(asset, msg.sender, shortRecordId);
            } else {
                shortRecord.status = SR.FullyFilled;
            }
        }

        // Approximating the startingShortId, rather than expecting exact match
        if (id == Asset.startingShortId) {
            uint256 oraclePrice = LibOracle.getPrice(asset);
            uint256 prevPrice = s.shorts[asset][short.prevId].price;
            if (short.price >= oraclePrice && prevPrice < oraclePrice) {
                Asset.startingShortId = short.nextId;
            } else if (prevPrice >= oraclePrice) {
                Asset.startingShortId = short.prevId;
            }
        }

        s.shorts.cancelOrder(asset, id);
    }

    //@dev public function to handle when orderId has hit limit. Used to deter attackers
    function cancelOrderFarFromOracle(
        address asset,
        O orderType,
        uint16 lastOrderId,
        uint16 numOrdersToCancel
    ) external onlyValidAsset(asset) nonReentrant {
        if (s.asset[asset].orderId < 65000) {
            revert Errors.OrderIdCountTooLow();
        }

        if (numOrdersToCancel > 1000) {
            revert Errors.CannotCancelMoreThan1000Orders();
        }

        if (msg.sender == LibDiamond.diamondStorage().contractOwner) {
            if (
                orderType == O.LimitBid
                    && s.bids[asset][lastOrderId].nextId == Constants.TAIL
            ) {
                s.bids.cancelManyOrders(asset, lastOrderId, numOrdersToCancel);
            } else if (
                orderType == O.LimitAsk
                    && s.asks[asset][lastOrderId].nextId == Constants.TAIL
            ) {
                s.asks.cancelManyOrders(asset, lastOrderId, numOrdersToCancel);
            } else if (
                orderType == O.LimitShort
                    && s.shorts[asset][lastOrderId].nextId == Constants.TAIL
            ) {
                s.shorts.cancelManyOrders(asset, lastOrderId, numOrdersToCancel);
            } else {
                revert Errors.NotLastOrder();
            }
        } else {
            //@dev if address is not DAO, you can only cancel last order of a side
            if (
                orderType == O.LimitBid
                    && s.bids[asset][lastOrderId].nextId == Constants.TAIL
            ) {
                s.bids.cancelOrder(asset, lastOrderId);
            } else if (
                orderType == O.LimitAsk
                    && s.asks[asset][lastOrderId].nextId == Constants.TAIL
            ) {
                s.asks.cancelOrder(asset, lastOrderId);
            } else if (
                orderType == O.LimitShort
                    && s.shorts[asset][lastOrderId].nextId == Constants.TAIL
            ) {
                s.shorts.cancelOrder(asset, lastOrderId);
            } else {
                revert Errors.NotLastOrder();
            }
        }
    }
}
