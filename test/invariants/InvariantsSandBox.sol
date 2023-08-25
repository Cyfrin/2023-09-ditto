// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U88, U80} from "contracts/libraries/PRBMathHelper.sol";
import {Vault, Constants} from "contracts/libraries/Constants.sol";
import {STypes, SR} from "contracts/libraries/DataTypes.sol";

import {Test} from "forge-std/Test.sol";

import {IOBFixture} from "interfaces/IOBFixture.sol";
import {IDiamond} from "interfaces/IDiamond.sol";

import {Handler} from "./Handler.sol";

import {console} from "contracts/libraries/console.sol";

contract InvariantsSandbox is Test {
    using U256 for uint256;
    using U88 for uint88;
    using U80 for uint80;

    Handler internal s_handler;
    IDiamond public diamond;
    uint256 public vault;
    address public asset;
    IOBFixture public s_ob;

    mapping(uint16 id => uint256 cnt) orderIdMapping;

    function setUp() public {
        IOBFixture ob = IOBFixture(deployCode("OBFixture.sol"));
        ob.setUp();
        address _diamond = ob.contracts("diamond");
        asset = ob.contracts("cusd");
        diamond = IDiamond(payable(_diamond));
        vault = Vault.CARBON;

        s_handler = new Handler(ob);

        s_ob = ob;
    }

    function testInvariantScenario() public {
        s_handler.createLimitBid(240000000000000, 9000000000000000000, 252);
        s_handler.createLimitBid(300000000000000, 9000000000000000000, 20);
        // s_handler.cancelOrder(0, 0);
        // s_handler.secondaryMarginCall(24395, 47);
        // s_handler.cancelOrder(0, 0);
        s_handler.createLimitShort(250000000000000, 1000000000000000000, 238);
        // s_handler.cancelOrder(9158, 0);
        s_handler.createLimitShort(250000000000000, 9000000000000000000, 242);
        s_handler.secondaryMarginCall(21041, 183);

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

                //@dev check that all short orders with shortRecordId > 0 is not fully filled
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
}
