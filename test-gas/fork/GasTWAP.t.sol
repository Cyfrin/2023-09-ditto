// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {Constants} from "contracts/libraries/Constants.sol";
import {MTypes} from "contracts/libraries/DataTypes.sol";
import {GasHelper} from "test-gas/GasHelper.sol";
import {IMockAggregatorV3} from "interfaces/IMockAggregatorV3.sol";
import {U256} from "contracts/libraries/PRBMathHelper.sol";

// import {console} from "contracts/libraries/console.sol";

contract GasTWAPTest is GasHelper {
    using U256 for uint256;

    uint256 public mainnetFork;
    uint256 public forkBlock = 17_373_211;
    IMockAggregatorV3 public ethAggregator;

    function setUp() public virtual override {
        try vm.envString("MAINNET_RPC_URL") returns (string memory rpcUrl) {
            mainnetFork = vm.createSelectFork(rpcUrl, forkBlock);
        } catch {
            revert("env: MAINNET_RPC_URL failure");
        }
        assertEq(vm.activeFork(), mainnetFork);
        super.setUp();

        ethAggregator = IMockAggregatorV3(ob.contracts("ethAggregator"));

        ob.depositUsd(receiver, 100 ether);
        ob.depositEth(receiver, 100 ether);
        ob.depositUsd(sender, 100 ether);
        ob.depositEth(sender, 100 ether);
    }

    function test_gas_Uniswap_TWAP() public {
        //@dev make a situation where chainlink's price is off by 50%
        //@dev increase spot price without saving it
        ethAggregator.setRoundData(
            92233720368547778906 wei,
            1000 ether,
            block.timestamp - 1 wei,
            block.timestamp - 1 wei,
            92233720368547778906 wei
        );
        ethAggregator.setRoundData(
            92233720368547778907 wei,
            8000 ether + 1 wei,
            block.timestamp,
            block.timestamp,
            92233720368547778907 wei
        );

        startMeasuringGas("Oracle-CheckingTWAP");
        diamond.getAssetPrice(asset);
        stopMeasuringGas();
    }

    function test_gas_Uniswap_TWAP_CreateBid() public {
        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: ZERO});
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        //@dev make a situation where chainlink's price is off by 50%
        //@dev increase spot price without saving it
        ethAggregator.setRoundData(
            92233720368547778906 wei,
            1000 ether,
            block.timestamp - 1 wei,
            block.timestamp - 1 wei,
            92233720368547778906 wei
        );
        ethAggregator.setRoundData(
            92233720368547778907 wei,
            8000 ether + 1 wei,
            block.timestamp,
            block.timestamp,
            92233720368547778907 wei
        );
        skip(1 hours);
        vm.prank(receiver);
        startMeasuringGas("Oracle-CheckingTWAP-createBid");
        diamond.createBid(
            _asset,
            DEFAULT_PRICE,
            DEFAULT_AMOUNT,
            Constants.LIMIT_ORDER,
            orderHintArray,
            shortHintArray
        );
        stopMeasuringGas();
    }
}
