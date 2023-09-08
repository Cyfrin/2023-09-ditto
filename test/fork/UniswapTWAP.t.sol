// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {Constants} from "contracts/libraries/Constants.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {U256} from "contracts/libraries/PRBMathHelper.sol";

import {OBFixture} from "test/utils/OBFixture.sol";
import {IMockAggregatorV3} from "interfaces/IMockAggregatorV3.sol";

// import {console} from "contracts/libraries/console.sol";

contract UniswapTWAPForkTest is OBFixture {
    using U256 for uint256;

    uint256 public mainnetFork;
    address public constant USDC = Constants.USDC;
    address public constant WETH = Constants.WETH;
    uint256 public forkBlock = 17_373_211;
    uint256 public twapPrice = uint256(1902 ether).inv();

    function setUp() public override {
        try vm.envString("MAINNET_RPC_URL") returns (string memory rpcUrl) {
            mainnetFork = vm.createSelectFork(rpcUrl, forkBlock);
        } catch {
            revert("env: MAINNET_RPC_URL failure");
        }
        assertEq(vm.activeFork(), mainnetFork);
        super.setUp();
    }

    function getTWAPPrice() public view returns (uint256 twapPriceInEther) {
        uint256 _twapPrice =
            diamond.estimateWETHInUSDC(Constants.UNISWAP_WETH_BASE_AMT, 1 hours);
        twapPriceInEther = (_twapPrice / Constants.DECIMAL_USDC) * 1 ether;
    }

    function updateSavedOracle() public {
        skip(1 hours);
        fundLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
    }

    function testRevert_InvalidTWAPSecondsAgo() public {
        vm.expectRevert(Errors.InvalidTWAPSecondsAgo.selector);
        diamond.estimateWETHInUSDC(Constants.UNISWAP_WETH_BASE_AMT, 0);
    }

    //@dev if chainlink's latest price is closer to last saved price vs TWAP
    function testFork_OraclePriceDeviationTooGreatUseChainlink() public {
        ethAggregator = IMockAggregatorV3(_ethAggregator);
        //@dev increase spot price without saving it
        ethAggregator.setRoundData(
            92233720368547778907 wei,
            (8000 ether / ORACLE_DECIMALS) + 1 wei,
            block.timestamp,
            block.timestamp,
            92233720368547778907 wei
        );

        //@dev at block height 17_373_211, TWAP WETH/USD price was ~1902 ether
        assertEq(getTWAPPrice(), 1902 ether);
        uint256 chainlinkPrice = uint256(8000 ether + ORACLE_DECIMALS).inv();
        assertEq(diamond.getAssetPrice(_cusd), chainlinkPrice);
    }

    //@dev if TWAP's price is closer to last saved price vs chainlink latest round's
    function testFork_OraclePriceDeviationTooGreatUseTWAP() public {
        ethAggregator = IMockAggregatorV3(_ethAggregator);
        ethAggregator.setRoundData(
            92233720368547778907 wei,
            1000 ether / ORACLE_DECIMALS,
            block.timestamp,
            block.timestamp,
            92233720368547778907 wei
        );

        assertEq(diamond.getAssetPrice(_cusd), twapPrice);
    }

    //Circuit Breaker tests
    //@dev when chainlink price is zero, use TWAP
    function testFork_BasePriceEqZero() public {
        _setETH(0);
        assertEq(diamond.getAssetPrice(_cusd), twapPrice);
    }

    function testFork_BasePriceLtZero() public {
        _setETH(-1);
        assertEq(diamond.getAssetPrice(_cusd), twapPrice);
    }

    //@dev when chainlink roundId is zero, use TWAP
    function testFork_OracleRoundIdEqZero() public {
        ethAggregator = IMockAggregatorV3(_ethAggregator);
        ethAggregator.deleteRoundData();
        ethAggregator.setRoundData(
            0,
            9000 ether / ORACLE_DECIMALS,
            block.timestamp,
            block.timestamp,
            92233720368547778907
        );
        assertEq(diamond.getAssetPrice(_cusd), twapPrice);
    }

    //@dev when chainlink data is stale use TWAP
    function testFork_OracleStaleData() public {
        skip(1682972900 seconds + 2 hours);
        assertEq(diamond.getAssetPrice(_cusd), twapPrice);
    }

    //@dev when chainlink timestamp is stale use TWAP
    function testFork_OracleTimeStampEqZero() public {
        ethAggregator = IMockAggregatorV3(_ethAggregator);
        ethAggregator.setRoundData(
            92233720368547778907 wei,
            (8000 ether / ORACLE_DECIMALS) + 1 wei,
            block.timestamp,
            0,
            92233720368547778907 wei
        );
        assertEq(diamond.getAssetPrice(_cusd), twapPrice);
    }

    //@dev when chainlink timestamp is > current block timestamp use TWAP
    function testFork_OracleTimeStampGtCurrentTime() public {
        ethAggregator = IMockAggregatorV3(_ethAggregator);
        ethAggregator.deleteRoundData();
        ethAggregator.setRoundData(0, 0, 0, block.timestamp + 1, 0);
        assertEq(diamond.getAssetPrice(_cusd), twapPrice);
    }
}
