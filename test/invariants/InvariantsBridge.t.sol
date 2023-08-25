// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U80, U88} from "contracts/libraries/PRBMathHelper.sol";
import {Constants} from "contracts/libraries/Constants.sol";

import {Test} from "forge-std/Test.sol";

import {IOBFixture} from "interfaces/IOBFixture.sol";
import {IDiamond} from "interfaces/IDiamond.sol";

import {Vault} from "contracts/libraries/Constants.sol";
import {Handler} from "./Handler.sol";

// import {console} from "contracts/libraries/console.sol";

contract InvariantsBridge is Test {
    using U256 for uint256;
    using U80 for uint80;
    using U88 for uint88;

    Handler internal s_handler;
    address public _diamond;
    IDiamond public diamond;
    uint256 public vault;
    address public asset;
    IOBFixture public s_ob;

    bytes4[] public selectors;

    //@dev Used for one test: statefulFuzz_allOrderIdsUnique
    mapping(uint16 id => uint256 cnt) orderIdMapping;

    function setUp() public {
        IOBFixture ob = IOBFixture(deployCode("OBFixture.sol"));
        ob.setUp();
        _diamond = ob.contracts("diamond");
        asset = ob.contracts("cusd");
        diamond = IDiamond(payable(_diamond));
        vault = Vault.CARBON;

        s_handler = new Handler(ob);
        selectors = [
            Handler.depositEth.selector,
            Handler.deposit.selector,
            Handler.withdraw.selector,
            Handler.unstakeEth.selector,
            Handler.fakeYield.selector
        ];

        targetSelector(FuzzSelector({addr: address(s_handler), selectors: selectors}));
        targetContract(address(s_handler));

        s_ob = ob;
    }

    function accumulateEthEscrowed(uint256 balance, address user)
        external
        view
        returns (uint256)
    {
        return balance + diamond.getVaultUserStruct(vault, user).ethEscrowed;
    }

    function statefulFuzz_ZethTotalMatchesEthEscrowed() public {
        uint256 bridgeValue = diamond.getZethTotal(vault);
        uint256 zethTotal = diamond.getVaultStruct(vault).zethTotal;
        assertApproxEqAbs(bridgeValue, zethTotal, s_ob.MAX_DELTA());

        uint256 sumOfEthEscrowed = s_handler.reduceUsers(0, this.accumulateEthEscrowed);
        sumOfEthEscrowed += diamond.getVaultUserStruct(vault, _diamond).ethEscrowed;
        assertApproxEqAbs(zethTotal, sumOfEthEscrowed, s_ob.MAX_DELTA());
    }
}
