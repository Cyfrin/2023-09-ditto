// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {ConstantsTest} from "test/utils/ConstantsTest.sol";
import {U256} from "contracts/libraries/PRBMathHelper.sol";

import {AggregatorV3Interface} from
    "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

// import {console} from "contracts/libraries/console.sol";

contract ChainlinkForkTest is ConstantsTest {
    using U256 for uint256;

    uint256 public mainnetFork;

    AggregatorV3Interface public baseOracle =
        AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);

    uint256 public forkBlock = 17_273_111;

    function setUp() public {
        try vm.envString("MAINNET_RPC_URL") returns (string memory rpcUrl) {
            mainnetFork = vm.createSelectFork(rpcUrl, forkBlock);
        } catch {
            revert("env: MAINNET_RPC_URL failure");
        }
        assertEq(vm.activeFork(), mainnetFork);
    }

    function getOraclePrice() private view returns (uint256) {
        // prettier-ignore
        (
            ,
            // uint80 roundID,
            int256 basePrice,
            /*uint startedAt*/
            ,
            // uint256 timeStamp,
            ,
            /*uint80 answeredInRound*/
        ) = baseOracle.latestRoundData();

        // 1528.09500000
        // $1,528.10

        // emit log_named_int("basePrice", basePrice);
        // emit LogNamedUint256("roundID", roundID);
        if (basePrice == 0) revert("is 0");
        return (uint256(basePrice * ORACLE_DECIMALS)).inv();
    }

    /**
     * Returns historical price for a round id.
     * roundId is NOT incremental. Not all roundIds are valid.
     * You must know a valid roundId before consuming historical data.
     *
     * ROUNDID VALUES:
     *    InValid:      18446744073709562300
     *    Valid:        18446744073709554683
     *
     * @dev A timestamp with zero value means the round is not complete and should not be used.
     */
    function getHistoricalPrice(uint80 roundId) public view returns (uint256) {
        // prettier-ignore
        (
            /*uint80 roundID*/
            ,
            int256 price,
            /*uint startedAt*/
            ,
            uint256 timeStamp,
            /*uint80 answeredInRound*/
        ) = baseOracle.getRoundData(roundId);
        require(timeStamp > 0, "Round not complete");
        if (price == 0) revert("is 0");
        return (uint256(price * ORACLE_DECIMALS)).inv();
    }

    function getOracleData()
        private
        view
        returns (uint80, uint256, uint256, uint256, uint80)
    {
        // prettier-ignore
        (
            uint80 roundID,
            int256 basePrice,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = baseOracle.latestRoundData();

        // 1528.09500000
        // $1,528.10

        // emit log_named_int("basePrice", basePrice);
        // emit LogNamedUint256("roundID", roundID);
        if (basePrice == 0) revert("is 0");
        return (
            roundID,
            (uint256(basePrice * ORACLE_DECIMALS)).inv(),
            startedAt,
            timeStamp,
            answeredInRound
        );
    }

    function getHistoricalData(uint80 roundId)
        public
        view
        returns (uint80, uint256, uint256, uint256, uint80)
    {
        // prettier-ignore
        (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = baseOracle.getRoundData(roundId);
        require(timeStamp > 0, "Round not complete");
        if (price == 0) revert("is 0");
        return (
            roundID,
            (uint256(price * ORACLE_DECIMALS)).inv(),
            startedAt,
            timeStamp,
            answeredInRound
        );
    }

    function testFork_ChainlinkLatest() public {
        uint256 price = getOraclePrice();
        assertEq(baseOracle.decimals(), 8);

        if (block.number == forkBlock) {
            assertEq(price, 550920751096704);
        }
    }

    function testFork_ChainlinkHistorical() public {
        uint256 price = getHistoricalPrice(92233720368547799214);
        assertEq(baseOracle.decimals(), 8);

        if (block.number == forkBlock) {
            assertEq(price, 650354763320553);
        }
    }

    //@dev Also tests getPrevRoundId()
    function testFork_ChainlinkCurrentRound() public {
        (
            uint80 latestRoundID,
            uint256 latestBasePrice,
            , // uint256 latestStartedAt
            uint256 latestTimeStamp,
            // uint80 latestAnsweredInRound
        ) = getOracleData();

        uint80 prevRoundId = latestRoundID - 1;

        //confirm the prevRoundId data
        (
            uint80 historicalRoundID,
            uint256 historicalBasePrice,
            , // uint256 historicalStartedAt
            uint256 historicalTimeStamp,
            // uint80 historicalAnsweredInRound
        ) = getHistoricalData(prevRoundId);

        assertEq(latestRoundID - 1, historicalRoundID);

        if (block.number == forkBlock) {
            assertEq(latestBasePrice, 550920751096704);
            assertEq(historicalBasePrice, 550914104227439);
            assertEq(latestTimeStamp, 1684248923);
            assertEq(historicalTimeStamp, 1684245323);
        } else {
            // console.log("latestRoundID", latestRoundID);
            // console.log("historicalRoundID", historicalRoundID);
            // console.log("latestBasePrice", latestBasePrice);
            // console.log("historicalBasePrice", historicalBasePrice);
            // console.log("latestTimeStamp", latestTimeStamp);
            // console.log("historicalTimeStamp", historicalTimeStamp);
        }
    }
}
