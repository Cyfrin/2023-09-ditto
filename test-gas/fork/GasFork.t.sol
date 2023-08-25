// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {ConstantsTest} from "test/utils/ConstantsTest.sol";
import {U256} from "contracts/libraries/PRBMathHelper.sol";

import {AggregatorV3Interface} from
    "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract GasForkTest is ConstantsTest {
    using U256 for uint256;

    uint256 public mainnetFork;
    uint256 public goerliFork;

    AggregatorV3Interface public baseOracle =
        AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);

    //@dev: foundry test crashes unless we use latest block height
    uint256 public forkBlock = 17_273_111;

    function setUp() public {
        try vm.envString("MAINNET_RPC_URL") returns (string memory rpcUrl) {
            mainnetFork = vm.createSelectFork(rpcUrl, forkBlock);
        } catch {
            revert("env: MAINNET_RPC_URL failure");
        }
        // emit log_uint(block.number);
        assertEq(vm.activeFork(), mainnetFork);

        // goerliFork = vm.createSelectFork(GOERLI_RPC_URL);
        // assertEq(vm.activeFork(), goerliFork);

        // creates a new fork and also selects it
        // uint256 anotherFork = vm.createSelectFork(MAINNET_RPC_URL);
        // assertEq(vm.activeFork(), anotherFork);

        // block
        // vm.rollFork(1_337_000);
        // assertEq(block.number, 1_337_000);
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
        // emit log_named_uint("roundID", roundID);
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
        // emit log_named_uint("roundID", roundID);
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

    function skipTestGasChainlinkLatest() public {
        uint256 gas = gasleft();
        uint256 price = getOraclePrice();
        gas = gas - gasleft();
        emit log_named_uint("gas latest", gas);
        gas = gasleft();
        price = getOraclePrice();
        gas = gas - gasleft();
        emit log_named_uint("gas latest 2nd call", gas);
        emit log_named_uint("price", price);
        emit log_named_uint("decimals", baseOracle.decimals());
    }

    // 4x = 20266+7248*3 = 42010
    // 2x = 20266+7248 = 27514
    function skipTestGasChainlinkHistorical() public {
        uint256 gas = gasleft();
        uint256 price = getHistoricalPrice(92233720368547799214);
        gas = gas - gasleft();
        emit log_named_uint("gas round", gas); // 20266
        gas = gasleft();
        price = getHistoricalPrice(92233720368547799214 - 1);
        gas = gas - gasleft();
        emit log_named_uint("gas round 2nd call", gas); // 7248
        emit log_named_uint("price", price);
        emit log_named_uint("decimals", baseOracle.decimals());
    }

    //@dev Also tests getPrevRoundId()
    function skipTestGasChainlinkCurrentRound() public {
        (
            uint80 latestRoundID,
            uint256 latestBasePrice,
            // uint256 latestStartedAt
            ,
            uint256 latestTimeStamp,
            // uint80 latestAnsweredInRound
        ) = getOracleData();

        uint80 prevRoundId = latestRoundID - 1;

        //confirm the prevRoundId data
        (
            uint80 historicalRoundID,
            uint256 historicalBasePrice,
            // uint256 historicalStartedAt
            ,
            uint256 historicalTimeStamp,
            // uint80 historicalAnsweredInRound
        ) = getHistoricalData(prevRoundId);

        emit log_named_uint("latestRoundID", latestRoundID);
        emit log_named_uint("historicalRoundID", historicalRoundID);

        emit log_named_uint("latestBasePrice", latestBasePrice);
        emit log_named_uint("historicalBasePrice", historicalBasePrice);

        emit log_named_uint("latestTimeStamp", latestTimeStamp);
        emit log_named_uint("historicalTimeStamp", historicalTimeStamp);

        /*

        //Height 17_273_390;
        latestRoundID: 110680464442257311227
        latestBasePrice: 548970953946826
        latestTimeStamp: 1684252535

        historicalRoundID: 110680464442257311226
        historicalBasePrice: 550920751096704
        historicalTimeStamp: 1684248923

        //Height 17_273_111
        latestRoundID: 110680464442257311226
        latestBasePrice: 550920751096704 (181514310000)
        latestTimeStamp: 1684248923

        historicalRoundID: 110680464442257311225
        historicalBasePrice: 550914104227439 (181516500000)
        historicalTimeStamp: 1684245323

        //Height 17_272_950
        latestRoundID: 110680464442257311225
        latestBasePrice: 550914104227439
        latestTimeStamp: 1684245323

        historicalRoundID: 110680464442257311224
        historicalBasePrice: 549622279233686
        historicalTimeStamp: 1684241723
        */
    }
}
