// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256} from "contracts/libraries/PRBMathHelper.sol";
import {OBFixture} from "test/utils/OBFixture.sol";
import {Constants, Vault} from "contracts/libraries/Constants.sol";

import {IRocketTokenRETH} from "interfaces/IRocketTokenRETH.sol";

import {BridgeReth} from "contracts/bridges/BridgeReth.sol";
import {BridgeSteth} from "contracts/bridges/BridgeSteth.sol";

// import {console} from "contracts/libraries/console.sol";

contract ForkHelper is OBFixture {
    using U256 for uint256;

    address[] public persistentAddresses;
    uint256 public forkBlock = 15_333_111;

    uint256 public liquidationBlock = 16_020_111;
    uint256 public bridgeBlock = 17_273_111;

    uint256 public mainnetFork;
    uint256 public liquidationFork;
    uint256 public bridgeFork;

    function setUp() public virtual override {
        try vm.envString("MAINNET_RPC_URL") returns (string memory rpcUrl) {
            mainnetFork = vm.createSelectFork(rpcUrl, forkBlock);
            liquidationFork = vm.createFork(rpcUrl, liquidationBlock);
            bridgeFork = vm.createFork(rpcUrl, bridgeBlock);
            assertEq(vm.activeFork(), mainnetFork);
        } catch {
            revert("env: MAINNET_RPC_URL failure");
        }

        _ethAggregator = address(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
        _steth = address(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
        _unsteth = address(0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1);
        _rocketStorage = address(0x1d8f8f00cfa6758d7bE78336684788Fb0ee0Fa46);

        isMock = false;
        super.setUp();

        rewind(Constants.STARTING_TIME);
        vm.startPrank(owner);

        //remove mock bridges deployed in DeployHelper
        diamond.deleteBridge(_bridgeSteth);
        diamond.deleteBridge(_bridgeReth);

        bridgeSteth = new BridgeSteth(steth, unsteth, _diamond);
        _bridgeSteth = address(bridgeSteth);

        _reth = rocketStorage.getAddress(
            keccak256(abi.encodePacked("contract.address", "rocketTokenRETH"))
        );
        reth = IRocketTokenRETH(_reth);

        bridgeReth = new BridgeReth(rocketStorage, _diamond);
        _bridgeReth = address(bridgeReth);

        diamond.createBridge({
            bridge: _bridgeReth,
            vault: Vault.CARBON,
            withdrawalFee: 50,
            unstakeFee: 0
        });

        diamond.createBridge({
            bridge: _bridgeSteth,
            vault: Vault.CARBON,
            withdrawalFee: 0,
            unstakeFee: 0
        });

        diamond.setAssetOracle(_cusd, _ethAggregator);
        diamond.setSecondaryLiquidationCR(_cusd, 140);
        diamond.setPrimaryLiquidationCR(_cusd, 170);
        diamond.setInitialMargin(_cusd, 200);

        diamond.setOracleTimeAndPrice(
            _cusd, uint256(ethAggregator.latestAnswer() * ORACLE_DECIMALS).inv()
        );

        vm.stopPrank();
        persistentAddresses = [
            //deployed
            _diamond,
            _bridgeSteth,
            _bridgeReth,
            _zeth,
            _cusd,
            _ditto,
            _dittoTimelockController,
            _dittoGovernor,
            _diamondCut,
            _diamondLoupe,
            _ownerFacet,
            _viewFacet,
            _yield,
            _vaultFacet,
            _bridgeRouter,
            _shortRecord,
            _askOrders,
            _shortOrders,
            _bidOrders,
            _orders,
            _exitShort,
            _marginCallPrimary,
            _marginCallSecondary,
            _marketShutdown,
            _twapFacet,
            _testFacet,
            //external
            _steth,
            _reth,
            _unsteth,
            //users
            sender,
            receiver
        ];
        vm.makePersistent(persistentAddresses);
    }
}
