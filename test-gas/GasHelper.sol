// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {U256} from "contracts/libraries/PRBMathHelper.sol";

import {IAsset} from "interfaces/IAsset.sol";
import {IOBFixture} from "interfaces/IOBFixture.sol";
import {IDiamond} from "interfaces/IDiamond.sol";
import {ITestFacet} from "interfaces/ITestFacet.sol";
import {IRocketStorage} from "interfaces/IRocketStorage.sol";
import {IRocketTokenRETH} from "interfaces/IRocketTokenRETH.sol";
import {ISTETH} from "interfaces/ISTETH.sol";
import {IUNSTETH} from "interfaces/IUNSTETH.sol";

import {BridgeReth} from "contracts/bridges/BridgeReth.sol";
import {BridgeSteth} from "contracts/bridges/BridgeSteth.sol";

import {MTypes} from "contracts/libraries/DataTypes.sol";
import {Vault} from "contracts/libraries/Constants.sol";

import {ConstantsTest} from "test/utils/ConstantsTest.sol";
import {console} from "contracts/libraries/console.sol";

//DO NOT REMOVE. WIll BREAK CI
import {ImmutableCreate2Factory} from "deploy/ImmutableCreate2Factory.sol";

function slice(string memory s, uint256 start, uint256 end)
    pure
    returns (string memory)
{
    bytes memory s_bytes = bytes(s);
    require(start <= end && end <= s_bytes.length, "invalid");

    bytes memory sliced = new bytes(end - start);
    for (uint256 i = start; i < end; i++) {
        sliced[i - start] = s_bytes[i];
    }
    return string(sliced);
}

function eq(string memory s1, string memory s2) pure returns (bool) {
    return keccak256(bytes(s1)) == keccak256(bytes(s2));
}

contract Gas is ConstantsTest {
    using U256 for uint256;
    using stdJson for string;

    string private constant SNAPSHOT_DIRECTORY = "./.forge-snapshots/";
    string private constant JSON_PATH = "./.gas.json";
    bool private overwrite = false;
    string private checkpointLabel;
    uint256 private checkpointGasLeft = 12;

    constructor() {
        string[] memory cmd = new string[](3);
        cmd[0] = "mkdir";
        cmd[1] = "-p";
        cmd[2] = SNAPSHOT_DIRECTORY;
        vm.ffi(cmd);

        try vm.envBool("OVERWRITE") returns (bool _check) {
            overwrite = _check;
        } catch {}
    }

    function startMeasuringGas(string memory label) internal virtual {
        checkpointLabel = label;
        checkpointGasLeft = gasleft(); // 5000 gas to set storage first time, set to make first call consistent
        checkpointGasLeft = gasleft(); // 100
    }

    function stringToUint(string memory s) private pure returns (uint256 result) {
        bytes memory b = bytes(s);
        uint256 i;
        result = 0;
        for (i = 0; i < b.length; i++) {
            uint8 c = uint8(b[i]);
            if (c >= 48 && c <= 57) {
                result = result * 10 + (c - 48);
            }
        }
    }

    function stopMeasuringGas() internal virtual returns (uint256) {
        uint256 checkpointGasLeft2 = gasleft();

        // Subtract 146 to account for startMeasuringGas/stopMeasuringGas
        // 100 for cost of setting checkpointGasLeft to same value
        // 40 to call function?
        uint256 gasUsed = checkpointGasLeft - checkpointGasLeft2 - 140;

        // @dev take the average if test is like `DistributeYieldx100`
        // if the last 4 char of a label == `x100`
        if (
            eq(
                slice(
                    checkpointLabel,
                    bytes(checkpointLabel).length - 4,
                    bytes(checkpointLabel).length
                ),
                "x100"
            )
        ) {
            gasUsed = gasUsed.div(100 ether);
        }

        string memory gasJson = string(abi.encodePacked(JSON_PATH));

        string memory snapFile =
            string(abi.encodePacked(SNAPSHOT_DIRECTORY, checkpointLabel, ".snap"));

        if (overwrite) {
            vm.writeFile(snapFile, vm.toString(gasUsed));
        } else {
            // if snap file exists
            try vm.readLine(snapFile) returns (string memory oldValue) {
                uint256 oldGasUsed = stringToUint(oldValue);
                bool gasIncrease = gasUsed >= oldGasUsed;
                string memory sign = gasIncrease ? "+" : "-";
                string memory diff = string.concat(
                    sign,
                    Strings.toString(
                        gasIncrease ? gasUsed - oldGasUsed : oldGasUsed - gasUsed
                    )
                );

                if (gasUsed != oldGasUsed) {
                    vm.writeFile(snapFile, vm.toString(gasUsed));
                    if (gasUsed > oldGasUsed + 10000) {
                        console.log(
                            string.concat(
                                string(abi.encodePacked(checkpointLabel)),
                                vm.toString(gasUsed),
                                vm.toString(oldGasUsed),
                                diff
                            )
                        );
                    }
                }
            } catch {
                // if not, read gas.json
                try vm.readFile(gasJson) returns (string memory json) {
                    bytes memory parsed =
                        vm.parseJson(json, string.concat(".", checkpointLabel));

                    // if no key
                    if (parsed.length == 0) {
                        // write new file
                        vm.writeFile(snapFile, vm.toString(gasUsed));
                    } else {
                        // otherwise use this value as the old
                        uint256 oldGasUsed = abi.decode(parsed, (uint256));
                        bool gasIncrease = gasUsed >= oldGasUsed;
                        string memory sign = gasIncrease ? "+" : "-";
                        string memory diff = string.concat(
                            sign,
                            Strings.toString(
                                gasIncrease ? gasUsed - oldGasUsed : oldGasUsed - gasUsed
                            )
                        );

                        if (gasUsed != oldGasUsed) {
                            vm.writeFile(snapFile, vm.toString(gasUsed));
                            if (gasUsed > oldGasUsed + 10000) {
                                console.log(
                                    string.concat(
                                        string(abi.encodePacked(checkpointLabel)),
                                        vm.toString(gasUsed),
                                        vm.toString(oldGasUsed),
                                        diff
                                    )
                                );
                            }
                        }
                    }
                } catch {
                    vm.writeFile(snapFile, vm.toString(gasUsed));
                }
            }
        }

        return gasUsed;
    }
}

contract GasHelper is Gas {
    address public receiver = address(1);
    address public sender = address(2);
    address public extra = address(3);
    address public owner = address(0x71C05a4eA5E9d5b1Ac87Bf962a043f5265d4Bdc8);
    address public tapp;
    address public asset;

    IAsset public ditto;
    IAsset public zeth;
    IAsset public cusd;

    address public _ob;
    IOBFixture public ob;
    address public _diamond;
    IDiamond public diamond;
    ITestFacet public testFacet;

    uint16 initialMargin;

    function setUp() public virtual {
        _ob = deployCode("OBFixture.sol");
        ob = IOBFixture(_ob);
        ob.setUp();

        asset = ob.asset();
        _diamond = ob.contracts("diamond");
        diamond = IDiamond(payable(_diamond));
        testFacet = ITestFacet(_diamond);
        tapp = _diamond;

        ditto = IAsset(ob.contracts("ditto"));
        zeth = IAsset(ob.contracts("zeth"));
        cusd = IAsset(ob.contracts("cusd"));

        //@dev skip to make updatedAt for
        skip(1 days);
        ob.setETH(4000 ether);

        initialMargin = diamond.getAssetStruct(asset).initialMargin;
        // Mint to random address for representative gas costs
        vm.startPrank(_diamond);
        ditto.mint(address(100), 1);
        zeth.mint(address(100), 1);
        cusd.mint(address(100), 1);
        vm.stopPrank();
    }

    function createShortHintArrayGas(uint16 shortHint)
        public
        pure
        returns (uint16[] memory)
    {
        uint16[] memory shortHintArray = new uint16[](1);
        shortHintArray[0] = shortHint;
        return shortHintArray;
    }

    function createOrderHintArrayGas()
        public
        pure
        returns (MTypes.OrderHint[] memory orderHintArray)
    {
        orderHintArray = new MTypes.OrderHint[](1);
        orderHintArray[0] = MTypes.OrderHint({hintId: 0, creationTime: 0});
        return orderHintArray;
    }
}

contract GasForkHelper is GasHelper {
    uint256 public forkBlock = 17_273_111;
    uint256 public mainnetFork;
    // RocketPool
    address public rocketStorage = address(0x1d8f8f00cfa6758d7bE78336684788Fb0ee0Fa46);
    address public _reth;
    address public _bridgeReth;
    IRocketTokenRETH public reth;
    BridgeReth public bridgeReth;
    // Lido
    address public _steth;
    address public _unsteth;
    address public _bridgeSteth;
    ISTETH public steth;
    IUNSTETH public unsteth;
    BridgeSteth public bridgeSteth;

    function setUp() public virtual override {
        try vm.envString("MAINNET_RPC_URL") returns (string memory rpcUrl) {
            mainnetFork = vm.createSelectFork(rpcUrl, forkBlock);
        } catch {
            revert("env: MAINNET_RPC_URL failure");
        }
        assertEq(vm.activeFork(), mainnetFork);

        super.setUp();

        _reth = IRocketStorage(rocketStorage).getAddress(
            keccak256(abi.encodePacked("contract.address", "rocketTokenRETH"))
        );
        reth = IRocketTokenRETH(_reth);
        bridgeReth = new BridgeReth(IRocketStorage(rocketStorage), _diamond);
        _bridgeReth = address(bridgeReth);

        _steth = address(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
        steth = ISTETH(_steth);
        _unsteth = address(0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1);
        unsteth = IUNSTETH(payable(_unsteth));
        bridgeSteth = new BridgeSteth(steth, unsteth, _diamond);
        _bridgeSteth = address(bridgeSteth);

        vm.startPrank(owner);
        // Delete mock bridges
        diamond.deleteBridge(ob.contracts("bridgeSteth"));
        diamond.deleteBridge(ob.contracts("bridgeReth"));

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
        vm.stopPrank();

        deal(_reth, sender, 1000 ether);
        deal(sender, 2000 ether);
        vm.startPrank(sender);
        steth.submit{value: 1000 ether}(address(0)); // Can't deal STETH, get it the old fashioned way

        reth.approve(
            _bridgeReth,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        diamond.deposit(_bridgeReth, 500 ether);
        steth.approve(
            _bridgeSteth,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        diamond.deposit(_bridgeSteth, 500 ether);
        vm.stopPrank();
    }
}
