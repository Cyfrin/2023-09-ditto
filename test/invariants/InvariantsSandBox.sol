// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U88, U80} from "contracts/libraries/PRBMathHelper.sol";
import {Vault, Constants} from "contracts/libraries/Constants.sol";
import {STypes} from "contracts/libraries/DataTypes.sol";

import {Test} from "forge-std/Test.sol";

import {IOBFixture} from "interfaces/IOBFixture.sol";
import {IDiamond} from "interfaces/IDiamond.sol";

import {Handler} from "./Handler.sol";

// import {console} from "contracts/libraries/console.sol";

contract InvariantsSandbox is Test {
    using U256 for uint256;
    using U88 for uint88;
    using U80 for uint80;

    Handler internal s_handler;
    IDiamond public diamond;
    uint256 public vault;
    address public asset;
    IOBFixture public s_ob;

    mapping(uint16 id => uint256 cnt) public orderIdMapping;

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
        s_handler.depositEth(104, 0);
        s_handler.depositEth(24, 69649606766503);
        s_handler.depositEth(7, 15621);
        s_handler.createLimitShort(37396910537273966600948, 16644, 74);
        s_handler.createLimitBid(431550529, 111601, 158);
        s_handler.deposit(78, 6939);
        s_handler.depositEth(1, 214524142197711857984406);
        s_handler.depositEth(163, 2319126729);
        s_handler.createLimitShort(23258861842914624, 309485009821345068724781055, 1);
        s_handler.depositEth(33, 143);
        s_handler.createLimitShort(0, 29999999869649606767389, 122);
        s_handler.secondaryMarginCall(
            2186917875,
            6243741738272141889229377861106738700200887508013741898715288334030804025756,
            0
        );
        s_handler.cancelOrder(53, 3);

        uint16 startingShortId = diamond.getAssetNormalizedStruct(asset).startingShortId;
        STypes.Order memory startingShort = diamond.getShortOrder(asset, startingShortId);
        if (startingShortId > Constants.HEAD) {
            assertGe(
                startingShort.price,
                s_handler.ghost_oraclePrice(),
                "statefulFuzz_startingShortPriceGteOraclePrice_1"
            );
        }
    }
}
