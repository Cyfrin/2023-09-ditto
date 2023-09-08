// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {OBFixture} from "test/utils/OBFixture.sol";

contract MockAggregatorTest is OBFixture {
    function setUp() public override {
        super.setUp();
    }

    function testCanSetOraclePrice() public {
        uint80 roundId = 92233720368547778907 wei;
        int256 answer = 10 ether;
        uint256 startedAt = 1646942160 wei;
        uint256 updatedAt = 1646942160 wei;
        uint80 answeredInRound = 92233720368547778907 wei;

        ethAggregator.setRoundData(roundId, answer, startedAt, updatedAt, answeredInRound);
        (
            uint80 getroundId,
            int256 getanswer,
            uint256 getstartedAt,
            uint256 getupdatedAt,
            uint80 getansweredInRound
        ) = ethAggregator.latestRoundData();

        assertEq(roundId, getroundId);
        assertEq(answer, getanswer);
        assertEq(startedAt, getstartedAt);
        assertEq(updatedAt, getupdatedAt);
        assertEq(answeredInRound, getansweredInRound);
    }
}
