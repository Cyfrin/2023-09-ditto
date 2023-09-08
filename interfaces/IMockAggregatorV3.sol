// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;



interface IMockAggregatorV3 {
  // public getters from contracts/mocks/MockAggregatorV3.sol
  function owner() external view returns (address);
  function latestRoundId() external view returns (uint80);
  function latestAnswer() external view returns (int256);
  function latestStartedAt() external view returns (uint256);
  function latestUpdatedAt() external view returns (uint256);
  function latestAnsweredInRound() external view returns (uint80);

  // functions from contracts/mocks/MockAggregatorV3.sol
  function decimals() external view returns (uint8);
  function description() external view returns (string memory);
  function version() external view returns (uint256);
  function getRoundData(uint80 round) external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
  function setRoundData(
        uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) external;
  function latestRoundData() external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
  function deleteRoundData() external;
}