// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U80, U88} from "contracts/libraries/PRBMathHelper.sol";
import {Constants} from "contracts/libraries/Constants.sol";
import {STypes, O, SR} from "contracts/libraries/DataTypes.sol";

import {Test} from "forge-std/Test.sol";

import {IAsset} from "interfaces/IAsset.sol";
import {IOBFixture} from "interfaces/IOBFixture.sol";
import {IDiamond} from "interfaces/IDiamond.sol";

import {LibOrders} from "contracts/libraries/LibOrders.sol";
import {Vault} from "contracts/libraries/Constants.sol";
import {Handler} from "./Handler.sol";

import {console} from "contracts/libraries/console.sol";

/* solhint-disable */
/// @dev This contract deploys the target contract, the Handler, adds the Handler's actions to the invariant fuzzing
/// @dev targets, then defines invariants that should always hold throughout any invariant run.
contract Invariants is Test {
    using U256 for uint256;
    using U80 for uint80;
    using U88 for uint88;

    Handler internal s_handler;
    IDiamond public diamond;
    uint256 public vault;
    address public asset;
    address public zeth;
    IOBFixture public s_ob;

    bytes4[] public selectors;

    //@dev Used for one test: statefulFuzz_allOrderIdsUnique
    mapping(uint16 id => uint256 cnt) orderIdMapping;

    function setUp() public {
        IOBFixture ob = IOBFixture(deployCode("OBFixture.sol"));
        ob.setUp();
        address _diamond = ob.contracts("diamond");
        asset = ob.contracts("cusd");
        zeth = ob.contracts("zeth");
        diamond = IDiamond(payable(_diamond));
        vault = Vault.CARBON;

        s_handler = new Handler(ob);
        selectors = [
            // Bridge
            Handler.deposit.selector,
            Handler.depositEth.selector,
            Handler.withdraw.selector,
            // OrderBook
            Handler.createLimitBid.selector,
            Handler.createLimitAsk.selector,
            Handler.createLimitShort.selector,
            Handler.cancelOrder.selector,
            // Yield
            Handler.fakeYield.selector,
            Handler.distributeYield.selector,
            //Vault
            Handler.depositAsset.selector,
            Handler.depositZeth.selector,
            Handler.withdrawAsset.selector,
            Handler.withdrawZeth.selector,
            // Short
            Handler.secondaryMarginCall.selector,
            Handler.primaryMarginCall.selector,
            Handler.exitShort.selector,
            Handler.increaseCollateral.selector,
            Handler.decreaseCollateral.selector,
            Handler.combineShorts.selector
        ];

        targetSelector(FuzzSelector({addr: address(s_handler), selectors: selectors}));
        targetContract(address(s_handler));

        s_ob = ob;
    }

    function statefulFuzz_boundTest() public {
        address[] memory users = s_handler.getUsers();
        for (uint256 i = 0; i < users.length; i++) {
            assertTrue(uint160(users[i]) <= type(uint160).max);
        }
    }

    function statefulFuzz_sortedBidsHighestToLowest() public {
        if (diamond.getBids(asset).length > 1) {
            STypes.Order memory firstBid = diamond.getBids(asset)[0];
            STypes.Order memory lastBid =
                diamond.getBids(asset)[diamond.getBids(asset).length - 1];

            STypes.Order memory prevBid = firstBid;
            STypes.Order memory currentBid;

            for (uint256 i = 0; i < diamond.getBids(asset).length; i++) {
                currentBid = diamond.getBids(asset)[i];
                assertTrue(
                    currentBid.orderType == O.LimitBid,
                    "statefulFuzz_sortedBidsHighestToLowest_1"
                );
                if (i == 0) {
                    assertEq(
                        currentBid.prevId,
                        Constants.HEAD,
                        "statefulFuzz_sortedBidsLowestToHighest_2"
                    );
                } else {
                    assertEq(
                        currentBid.prevId,
                        prevBid.id,
                        "statefulFuzz_sortedBidsLowestToHighest_2"
                    );
                }
                if (i == 0) {
                    assertEq(
                        diamond.getBidOrder(asset, Constants.HEAD).nextId,
                        currentBid.id,
                        "statefulFuzz_sortedBidsLowestToHighest_3"
                    );
                } else {
                    assertEq(
                        prevBid.nextId,
                        currentBid.id,
                        "statefulFuzz_sortedBidsLowestToHighest_3"
                    );
                }
                assertTrue(
                    prevBid.price >= currentBid.price,
                    "statefulFuzz_sortedBidsHighestToLowest_4"
                );
                prevBid = diamond.getBids(asset)[i];
            }
            assertEq(
                firstBid.prevId,
                Constants.HEAD,
                "statefulFuzz_sortedBidsHighestToLowest_5"
            );
            assertEq(
                lastBid.nextId, Constants.HEAD, "statefulFuzz_sortedBidsHighestToLowest_6"
            );
        }
    }

    function statefulFuzz_sortedAsksLowestToHighest() public {
        if (diamond.getAsks(asset).length > 1) {
            STypes.Order memory firstAsk = diamond.getAsks(asset)[0];
            STypes.Order memory lastAsk =
                diamond.getAsks(asset)[diamond.getAsks(asset).length - 1];

            STypes.Order memory prevAsk = firstAsk;
            STypes.Order memory currentAsk;

            for (uint256 i = 0; i < diamond.getAsks(asset).length; i++) {
                currentAsk = diamond.getAsks(asset)[i];
                assertTrue(
                    currentAsk.orderType == O.LimitAsk,
                    "statefulFuzz_sortedAsksLowestToHighest_1"
                );
                if (i == 0) {
                    assertEq(
                        currentAsk.prevId,
                        Constants.HEAD,
                        "statefulFuzz_sortedAsksLowestToHighest_2"
                    );
                } else {
                    assertEq(
                        currentAsk.prevId,
                        prevAsk.id,
                        "statefulFuzz_sortedAsksLowestToHighest_2"
                    );
                }
                if (i == 0) {
                    assertEq(
                        diamond.getAskOrder(asset, Constants.HEAD).nextId,
                        currentAsk.id,
                        "statefulFuzz_sortedAsksLowestToHighest_3"
                    );
                } else {
                    assertEq(
                        prevAsk.nextId,
                        currentAsk.id,
                        "statefulFuzz_sortedAsksLowestToHighest_3"
                    );
                }
                assertTrue(
                    prevAsk.price <= currentAsk.price,
                    "statefulFuzz_sortedAsksLowestToHighest_4"
                );
                prevAsk = diamond.getAsks(asset)[i];
            }
            assertEq(
                firstAsk.prevId,
                Constants.HEAD,
                "statefulFuzz_sortedAsksLowestToHighest_5"
            );
            assertEq(
                lastAsk.nextId, Constants.HEAD, "statefulFuzz_sortedAsksLowestToHighest_6"
            );
        }
    }

    function statefulFuzz_sortedShortsLowestToHighest() public {
        if (diamond.getShorts(asset).length > 1) {
            STypes.Order memory firstShort = diamond.getShorts(asset)[0];
            STypes.Order memory lastShort =
                diamond.getShorts(asset)[diamond.getShorts(asset).length - 1];

            STypes.Order memory prevShort = diamond.getShorts(asset)[0];
            STypes.Order memory currentShort;

            for (uint256 i = 0; i < diamond.getShorts(asset).length; i++) {
                currentShort = diamond.getShorts(asset)[i];

                assertTrue(
                    currentShort.orderType == O.LimitShort,
                    "statefulFuzz_sortedShortsLowestToHighest_1"
                );
                if (i == 0) {
                    assertEq(
                        currentShort.prevId,
                        Constants.HEAD,
                        "statefulFuzz_sortedShortsLowestToHighest_2"
                    );
                } else {
                    assertEq(
                        currentShort.prevId,
                        prevShort.id,
                        "statefulFuzz_sortedShortsLowestToHighest_2"
                    );
                }
                if (i == 0) {
                    assertEq(
                        diamond.getShortOrder(asset, Constants.HEAD).nextId,
                        currentShort.id,
                        "statefulFuzz_sortedShortsLowestToHighest_3"
                    );
                } else {
                    assertEq(
                        prevShort.nextId,
                        currentShort.id,
                        "statefulFuzz_sortedShortsLowestToHighest_3"
                    );
                }
                assertTrue(
                    prevShort.price <= currentShort.price,
                    "statefulFuzz_sortedShortsLowestToHighest_4"
                );
                prevShort = diamond.getShorts(asset)[i];
            }

            assertEq(
                firstShort.prevId,
                Constants.HEAD,
                "statefulFuzz_sortedShortsLowestToHighest_5"
            );
            assertEq(
                lastShort.nextId,
                Constants.HEAD,
                "statefulFuzz_sortedShortsLowestToHighest_6"
            );
        }
    }

    function statefulFuzz_bidHEAD() public {
        STypes.Order memory bidHEAD = diamond.getBidOrder(asset, Constants.HEAD);
        STypes.Order memory bidPrevHEAD = diamond.getBidOrder(asset, bidHEAD.prevId);

        while (bidPrevHEAD.id != Constants.HEAD) {
            assertTrue(
                bidPrevHEAD.orderType == O.Cancelled || bidPrevHEAD.orderType == O.Matched,
                "statefulFuzz_bidHEAD_1"
            );

            if (bidPrevHEAD.prevId != Constants.HEAD) {
                assertTrue(
                    bidPrevHEAD.prevOrderType == O.Cancelled
                        || bidPrevHEAD.prevOrderType == O.Matched
                        || bidPrevHEAD.prevOrderType == O.Uninitialized,
                    "statefulFuzz_bidHEAD_2"
                );
            }
            bidPrevHEAD = diamond.getBidOrder(asset, bidPrevHEAD.prevId);
        }

        if (diamond.getBids(asset).length > 0) {
            assertTrue(bidHEAD.nextId != Constants.HEAD, "statefulFuzz_bidHEAD_3");
        } else {
            assertEq(bidHEAD.nextId, Constants.HEAD, "statefulFuzz_bidHEAD_4");
        }
    }

    function statefulFuzz_askHEAD() public {
        STypes.Order memory askHEAD = diamond.getAskOrder(asset, Constants.HEAD);
        STypes.Order memory askPrevHEAD = diamond.getAskOrder(asset, askHEAD.prevId);

        while (askPrevHEAD.id != Constants.HEAD) {
            assertTrue(
                askPrevHEAD.orderType == O.Cancelled || askPrevHEAD.orderType == O.Matched,
                "statefulFuzz_askHEAD_1"
            );

            if (askPrevHEAD.prevId != Constants.HEAD) {
                assertTrue(
                    askPrevHEAD.prevOrderType == O.Cancelled
                        || askPrevHEAD.prevOrderType == O.Matched
                        || askPrevHEAD.prevOrderType == O.Uninitialized,
                    "statefulFuzz_askHEAD_2"
                );
            }
            askPrevHEAD = diamond.getAskOrder(asset, askPrevHEAD.prevId);
        }

        if (diamond.getAsks(asset).length > 0) {
            assertTrue(askHEAD.nextId != Constants.HEAD, "statefulFuzz_askHEAD_3");
        } else {
            assertEq(askHEAD.nextId, Constants.HEAD, "statefulFuzz_askHEAD_4");
        }
    }

    function statefulFuzz_shortHEAD() public {
        STypes.Order memory shortHEAD = diamond.getShortOrder(asset, Constants.HEAD);
        STypes.Order memory shortPrevHEAD = diamond.getShortOrder(asset, shortHEAD.prevId);

        while (shortPrevHEAD.id != Constants.HEAD) {
            assertTrue(
                shortPrevHEAD.orderType == O.Cancelled
                    || shortPrevHEAD.orderType == O.Matched,
                "statefulFuzz_shortHEAD_1"
            );

            if (shortPrevHEAD.prevId != Constants.HEAD) {
                assertTrue(
                    shortPrevHEAD.prevOrderType == O.Cancelled
                        || shortPrevHEAD.prevOrderType == O.Matched
                        || shortPrevHEAD.prevOrderType == O.Uninitialized,
                    "statefulFuzz_shortHEAD_2"
                );
            }
            shortPrevHEAD = diamond.getShortOrder(asset, shortPrevHEAD.prevId);
        }

        if (diamond.getShorts(asset).length > 0) {
            assertTrue(shortHEAD.nextId != Constants.HEAD, "statefulFuzz_shortHEAD_3");
        } else {
            assertEq(shortHEAD.nextId, Constants.HEAD, "statefulFuzz_shortHEAD_4");
        }
    }

    //@dev assumes no price changes in the invariant tests
    // function statefulFuzz_shortRecordCRatioAlwaysAbove1() public {
    //     address[] memory users = s_handler.getUsers();
    //     for (uint256 i = 0; i < users.length; i++) {
    //         STypes.ShortRecord[] memory shorts = diamond.getShortRecords(asset, users[i]);
    //         if (shorts.length > 0) {
    //             for (uint256 j = 0; j < shorts.length; j++) {
    //                 uint256 cRatio = diamond.getCollateralRatio(asset, shorts[j]);
    //                 assertGt(
    //                     cRatio, 1 ether, "statefulFuzz_shortRecordCRatioAlwaysAbove1_1"
    //                 );
    //             }
    //         }
    //     }
    // }

    function statefulFuzz_orderIdGtMarketDepth() public {
        uint256 marketDepth = diamond.getBids(asset).length
            + diamond.getAsks(asset).length + diamond.getShorts(asset).length;

        assertTrue(
            diamond.getAssetNormalizedStruct(asset).orderId > marketDepth,
            "statefulFuzz_orderIdGtMarketDepth_1"
        );
        assertGe(
            diamond.getAssetNormalizedStruct(asset).orderId,
            s_handler.getGhostOrderId(),
            "statefulFuzz_orderIdGtMarketDepth_2"
        );
    }

    function statefulFuzz_oracleTimeAlwaysIncrease() public {
        assertGe(
            diamond.getOracleTimeT(asset),
            s_handler.getGhostOracleTime(),
            "statefulFuzz_oracleTimeAlwaysIncrease_1"
        );
    }

    function statefulFuzz_startingShortPriceGteOraclePrice() public {
        uint16 startingShortId = diamond.getAssetNormalizedStruct(asset).startingShortId;
        STypes.Order memory startingShort = diamond.getShortOrder(asset, startingShortId);
        if (startingShortId > Constants.HEAD) {
            assertGe(
                startingShort.price,
                s_handler.getGhostOraclePrice(),
                "statefulFuzz_startingShortPriceGteOraclePrice_1"
            );
        }
    }

    function statefulFuzz_allOrderIdsUnique() public {
        //@dev Unmatched Bids, Asks, Shorts
        uint256 marketDepth = diamond.getBids(asset).length
            + diamond.getAsks(asset).length + diamond.getShorts(asset).length;

        //@dev Cancelled/Matched Bids, Asks, Shorts
        STypes.Order memory bidHEAD = diamond.getBidOrder(asset, Constants.HEAD);
        STypes.Order memory bidPrevHEAD = diamond.getBidOrder(asset, bidHEAD.prevId);
        STypes.Order memory askHEAD = diamond.getAskOrder(asset, Constants.HEAD);
        STypes.Order memory askPrevHEAD = diamond.getAskOrder(asset, askHEAD.prevId);
        STypes.Order memory shortHEAD = diamond.getShortOrder(asset, Constants.HEAD);
        STypes.Order memory shortPrevHEAD = diamond.getShortOrder(asset, shortHEAD.prevId);

        uint256 counter = 0;
        while (bidPrevHEAD.id != Constants.HEAD) {
            counter++;
            bidPrevHEAD = diamond.getBidOrder(asset, bidPrevHEAD.prevId);
        }
        while (askPrevHEAD.id != Constants.HEAD) {
            counter++;
            askPrevHEAD = diamond.getAskOrder(asset, askPrevHEAD.prevId);
        }
        while (shortPrevHEAD.id != Constants.HEAD) {
            counter++;
            shortPrevHEAD = diamond.getShortOrder(asset, shortPrevHEAD.prevId);
        }
        marketDepth += counter;

        uint16[] memory allOrderIds = new uint16[](marketDepth);

        //@dev Reuse counter to use as index
        counter = 0;
        //@dev Add all orders in OB to allOrdersId
        if (diamond.getBids(asset).length > 0) {
            for (uint256 i = 0; i < diamond.getBids(asset).length; i++) {
                allOrderIds[counter] = diamond.getBids(asset)[i].id;
                counter++;
            }
        }
        if (diamond.getAsks(asset).length > 0) {
            for (uint256 i = 0; i < diamond.getAsks(asset).length; i++) {
                allOrderIds[counter] = diamond.getAsks(asset)[i].id;
                counter++;
            }
        }
        if (diamond.getShorts(asset).length > 0) {
            for (uint256 i = 0; i < diamond.getShorts(asset).length; i++) {
                allOrderIds[counter] = diamond.getShorts(asset)[i].id;
                counter++;
            }
        }

        //@dev Add all cancelled/Matched ids to allOrdersId
        bidPrevHEAD = diamond.getBidOrder(asset, bidHEAD.prevId);
        askPrevHEAD = diamond.getAskOrder(asset, askHEAD.prevId);
        shortPrevHEAD = diamond.getShortOrder(asset, shortHEAD.prevId);

        while (bidPrevHEAD.id != Constants.HEAD) {
            allOrderIds[counter] = bidPrevHEAD.id;
            bidPrevHEAD = diamond.getBidOrder(asset, bidPrevHEAD.prevId);
            counter++;
        }
        while (askPrevHEAD.id != Constants.HEAD) {
            allOrderIds[counter] = askPrevHEAD.id;
            askPrevHEAD = diamond.getAskOrder(asset, askPrevHEAD.prevId);
            counter++;
        }

        while (shortPrevHEAD.id != Constants.HEAD) {
            allOrderIds[counter] = shortPrevHEAD.id;
            shortPrevHEAD = diamond.getShortOrder(asset, shortPrevHEAD.prevId);
            counter++;
        }

        assertEq(
            marketDepth + Constants.STARTING_ID,
            diamond.getAssetNormalizedStruct(asset).orderId
        );

        for (uint256 i = 0; i < allOrderIds.length; i++) {
            uint16 orderId = allOrderIds[i];
            orderIdMapping[orderId]++;
            if (orderIdMapping[orderId] > 1) {
                revert("Order Id is not unique");
            }
        }
    }

    function statefulFuzz_shortRecordExists() public {
        address[] memory users = s_handler.getUsers();

        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            STypes.ShortRecord[] memory shortRecords =
                diamond.getShortRecords(asset, user);
            STypes.ShortRecord memory shortRecordHEAD =
                diamond.getShortRecord(asset, user, Constants.HEAD);

            if (diamond.getAssetUserStruct(asset, user).shortRecordId == 0) {
                assertEq(shortRecordHEAD.prevId, 0, "statefulFuzz_shortRecordExists_1");
            } else {
                //@dev check all cancelled shorts are indeed canceled
                while (shortRecordHEAD.prevId != Constants.HEAD) {
                    STypes.ShortRecord memory shortRecordPrevHEAD =
                        diamond.getShortRecord(asset, user, shortRecordHEAD.prevId);
                    assertTrue(
                        shortRecordPrevHEAD.status == SR.Cancelled,
                        "statefulFuzz_shortRecordExists_2"
                    );
                    shortRecordHEAD =
                        diamond.getShortRecord(asset, user, shortRecordHEAD.prevId);
                }
            }

            if (shortRecords.length > 0) {
                //@dev check that all active shortRecords are either full or partial;
                for (uint256 j = 0; j < shortRecords.length; j++) {
                    assertTrue(
                        shortRecords[j].status == SR.PartialFill
                            || shortRecords[j].status == SR.FullyFilled,
                        "statefulFuzz_shortRecordExists_3"
                    );
                }

                //@dev check that all short orders with shortRecordId > 0 is a partial fill
                STypes.Order[] memory shortOrders = diamond.getShorts(asset);

                for (uint256 k = 0; k < shortOrders.length; k++) {
                    if (shortOrders[k].addr == user && shortOrders[k].shortRecordId > 0) {
                        assertTrue(
                            diamond.getShortRecord(
                                asset, user, shortOrders[k].shortRecordId
                            ).status != SR.FullyFilled,
                            "statefulFuzz_shortRecordExists_4"
                        );
                    }
                }
            }
        }
    }

    // @dev Vault zethTotal = sum of users ethEscrowed
    function statefulFuzz_Vault_ZethTotal() public {
        IAsset tokenContract = IAsset(zeth);
        uint256 zethTotal = diamond.getVaultStruct(vault).zethTotal;
        assertEq(zethTotal, diamond.getZethTotal(vault), "statefulFuzz_Vault_ZethTotal_1");

        address[] memory users = s_handler.getUsers();

        //@dev Collateral of matched shorts
        uint256 userZethTotal;
        uint256 zethCollateralTotal;
        for (uint256 i = 0; i < users.length; i++) {
            //@dev wallet balance for zeth
            userZethTotal += tokenContract.balanceOf(users[i]);

            STypes.ShortRecord[] memory shorts = diamond.getShortRecords(asset, users[i]);
            for (uint256 j = 0; j < shorts.length; j++) {
                // Collateral in shortRecord
                zethCollateralTotal += shorts[j].collateral;
                // Undistributed yield
                userZethTotal += shorts[j].collateral.mulU88(
                    diamond.getZethYieldRate(vault) - shorts[j].zethYieldRate
                );
            }
        }

        assertEq(
            diamond.getVaultStruct(vault).zethCollateral,
            zethCollateralTotal,
            "statefulFuzz_Vault_ZethTotal_2"
        );

        assertEq(
            diamond.getAssetStruct(asset).zethCollateral,
            zethCollateralTotal,
            "statefulFuzz_Vault_ZethTotal_3"
        );

        //@dev ...and eth locked up on bid on ob...
        for (uint256 i = 0; i < diamond.getBids(asset).length; i++) {
            uint256 eth =
                diamond.getBids(asset)[i].price.mul(diamond.getBids(asset)[i].ercAmount);
            userZethTotal += eth;
        }

        //@dev ...and collateral locked up on short on ob...
        for (uint256 i = 0; i < diamond.getShorts(asset).length; i++) {
            uint256 collateral = diamond.getShorts(asset)[i].price.mul(
                diamond.getShorts(asset)[i].ercAmount
            ).mul(LibOrders.convertCR(diamond.getShorts(asset)[i].initialMargin));
            userZethTotal += collateral;
        }

        //@dev ...and ethEscrowed of a user...
        for (uint256 i = 0; i < users.length; i++) {
            userZethTotal += diamond.getVaultUserStruct(vault, users[i]).ethEscrowed;
        }

        //@dev ...and ethEscrowed of Tapp...
        userZethTotal += diamond.getVaultUserStruct(vault, address(diamond)).ethEscrowed;
        //@dev ...and zethCollateral from matched shortRecords...
        userZethTotal += zethCollateralTotal;

        //@dev it is not perfectly equal due to rounding error
        assertApproxEqAbs(
            zethTotal, userZethTotal, s_ob.MAX_DELTA(), "statefulFuzz_Vault_ZethTotal_4"
        );
    }

    //  @dev Vault dittoMatchedShares = sum of users dittoMatchedShares
    function statefulFuzz_dittoMatchedShares() public {
        uint256 vaultShares = diamond.getVaultStruct(vault).dittoMatchedShares;
        uint256 totalUserShares;
        address[] memory users = s_handler.getUsers();
        for (uint256 i = 0; i < users.length; i++) {
            totalUserShares +=
                diamond.getVaultUserStruct(vault, users[i]).dittoMatchedShares;
        }
        assertEq(vaultShares, totalUserShares, "statefulFuzz_dittoMatchedShares_1");
    }

    function statefulFuzz_Vault_ErcEscrowedPlusAssetBalanceEqTotalDebt() public {
        address[] memory users = s_handler.getUsers();
        IAsset assetContract = IAsset(asset);
        uint256 ercEscrowed;
        uint256 assetBalance;
        uint256 totalDebt;

        STypes.Order[] memory asks = diamond.getAsks(asset);
        for (uint256 i = 0; i < asks.length; i++) {
            ercEscrowed += asks[i].ercAmount;
        }

        for (uint256 i = 0; i < users.length; i++) {
            ercEscrowed += diamond.getAssetUserStruct(asset, users[i]).ercEscrowed;
            assetBalance += assetContract.balanceOf(users[i]);

            STypes.ShortRecord[] memory shorts = diamond.getShortRecords(asset, users[i]);
            for (uint256 j = 0; j < shorts.length; j++) {
                totalDebt += shorts[j].ercDebt;
            }
        }

        console.log("ercEscrowed:", ercEscrowed);
        console.log("assetBalance:", assetBalance);
        console.log("totalDebt:", totalDebt);
        assertEq(ercEscrowed + assetBalance, totalDebt);
    }

    // @dev this will be zero until we put updateYield() in handler
    // function statefulFuzz_zethCollateralRewardAlwaysIncreases() public {
    // vm.writeLine(
    //     "./test/invariants/inputs",
    //     vm.toString(
    //         diamond.getVaultStruct(vault).zethCollateralReward
    //     )
    // );
    // vm.writeLine(
    //     "./test/invariants/inputs",
    //     vm.toString(s_handler.getGhostZethCollateralReward())
    // );
    // vm.writeLine("./test/invariants/inputs", "----");
    // assertGe(
    //     diamond.getVaultStruct(vault).zethCollateralReward,
    //     s_handler.getGhostZethCollateralReward()
    // );
    // }

    //@dev this will be zero until we put updateYield() in handler
    // function statefulFuzz_zethYieldRateAlwaysIncreases() public {
    //     vm.writeLine(
    //         "./test/invariants/inputs", vm.toString(s_handler.getGhostZethYieldRate())
    //     );
    //     vm.writeLine(
    //         "./test/invariants/inputs",
    //         vm.toString(diamond.getVaultStruct(vault).zethYieldRate)
    //     );
    //     vm.writeLine("./test/invariants/inputs", "----");
    //     assertGe(
    //         diamond.getVaultStruct(vault).zethYieldRate,
    //         s_handler.getGhostZethYieldRate()
    //     );
    // }
}
