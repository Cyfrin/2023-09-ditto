// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {AggregatorV3Interface} from
    "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {TestTypes} from "test/utils/TestTypes.sol";

// import {console} from "contracts/libraries/console.sol";

// https://etherscan.io/address/0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
// https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol
// https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.7/dev/AggregatorProxy.sol

contract MockAggregatorV3 is AggregatorV3Interface {
    address public owner;
    uint8 internal _decimals = 8;
    string internal _description = "ETH/USD";
    uint256 internal _version = 3;

    constructor() {
        owner = msg.sender;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function description() external view returns (string memory) {
        return _description;
    }

    function version() external view returns (uint256) {
        return _version;
    }

    uint80 public latestRoundId;
    int256 public latestAnswer;
    uint256 public latestStartedAt;
    uint256 public latestUpdatedAt;
    uint80 public latestAnsweredInRound;

    mapping(uint256 roundID => TestTypes.MockOracleData oracleData) internal roundData;

    // getRoundData and latestRoundData should both raise "No data present"
    // if they do not have data to report, instead of returning unset values
    // which could be misinterpreted as actual reported values.
    function getRoundData(uint80 round)
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (
            roundData[round].roundId,
            roundData[round].answer,
            roundData[round].startedAt,
            roundData[round].updatedAt,
            roundData[round].answeredInRound
        );
    }

    function setRoundData(
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) external {
        // require(msg.sender == owner, "not owner");
        // mock error with no id
        if (roundId >= latestRoundId) {
            latestRoundId = roundId;
            latestAnswer = answer;
            latestStartedAt = startedAt;
            latestUpdatedAt = updatedAt;
            latestAnsweredInRound = answeredInRound;
        }

        roundData[roundId] = TestTypes.MockOracleData({
            roundId: roundId,
            answer: answer,
            startedAt: startedAt,
            updatedAt: updatedAt,
            answeredInRound: answeredInRound
        });
    }

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (
            latestRoundId,
            latestAnswer,
            latestStartedAt,
            latestUpdatedAt,
            latestAnsweredInRound
        );
    }

    function deleteRoundData() external {
        latestRoundId = 0;
        latestAnswer = 0;
        latestStartedAt = 0;
        latestUpdatedAt = 0;
        latestAnsweredInRound = 0;
    }
}
