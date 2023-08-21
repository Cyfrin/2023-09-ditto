// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {mulDiv as _mulDiv, mulDiv18, UNIT} from "@prb/math/src/Common.sol";
import {Errors} from "contracts/libraries/Errors.sol";

library U256 {
    function mul(uint256 x, uint256 y) internal pure returns (uint256 result) {
        result = mulDiv18(x, y);
    }

    function div(uint256 x, uint256 y) internal pure returns (uint256 result) {
        result = _mulDiv(x, UNIT, y);
    }

    function mulDiv(uint256 x, uint256 y, uint256 denominator)
        internal
        pure
        returns (uint256 result)
    {
        return _mulDiv(x, y, denominator);
    }

    function inv(uint256 x) internal pure returns (uint256 result) {
        unchecked {
            // 1e36 is UNIT * UNIT.
            result = 1e36 / x;
        }
    }

    function divU80(uint256 x, uint256 y) internal pure returns (uint80 result) {
        uint256 _result = _mulDiv(x, UNIT, y);
        if (_result > type(uint80).max) revert Errors.InvalidAmount(); // assume amount?
        result = uint80(_result);
    }

    function divU64(uint256 x, uint256 y) internal pure returns (uint64 result) {
        uint256 _result = _mulDiv(x, UNIT, y);
        if (_result > type(uint64).max) revert Errors.InvalidAmount(); // assume amount?
        result = uint64(_result);
    }

    // test
    function divU88(uint256 x, uint256 y) internal pure returns (uint88 result) {
        uint256 _result = _mulDiv(x, UNIT, y);
        if (_result > type(uint88).max) revert Errors.InvalidAmount(); // assume amount?
        result = uint88(_result);
    }
}

// uint128
library Math128 {
    // just passing the result of casting the first param to 256
    function mul(uint128 x, uint256 y) internal pure returns (uint256 result) {
        result = mulDiv18(x, y);
    }

    function div(uint128 x, uint256 y) internal pure returns (uint256 result) {
        result = _mulDiv(x, UNIT, y);
    }
}

// uint104
library Math104 {
    // just passing the result of casting the first param to 256
    function mul(uint104 x, uint256 y) internal pure returns (uint256 result) {
        result = mulDiv18(x, y);
    }

    function div(uint104 x, uint256 y) internal pure returns (uint256 result) {
        result = _mulDiv(x, UNIT, y);
    }
}

// uint96
library U96 {
    // just passing the result of casting the first param to 256
    function mul(uint96 x, uint256 y) internal pure returns (uint256 result) {
        result = mulDiv18(x, y);
    }

    function div(uint96 x, uint256 y) internal pure returns (uint256 result) {
        result = _mulDiv(x, UNIT, y);
    }

    function divU64(uint96 x, uint256 y) internal pure returns (uint64 result) {
        uint256 _result = _mulDiv(x, UNIT, y);
        if (_result > type(uint64).max) revert Errors.InvalidAmount(); // assume amount?
        result = uint64(_result);
    }
}

// uint88
library U88 {
    // just passing the result of casting the first param to 256
    function mul(uint88 x, uint256 y) internal pure returns (uint256 result) {
        result = mulDiv18(x, y);
    }

    function mulU88(uint88 x, uint256 y) internal pure returns (uint88 result) {
        uint256 _result = mulDiv18(x, y);
        if (_result > type(uint88).max) revert Errors.InvalidAmount(); // assume amount?
        result = uint88(_result);
    }

    function div(uint88 x, uint256 y) internal pure returns (uint256 result) {
        result = _mulDiv(x, UNIT, y);
    }

    function divU88(uint88 x, uint256 y) internal pure returns (uint88 result) {
        uint256 _result = _mulDiv(x, UNIT, y);
        if (_result > type(uint88).max) revert Errors.InvalidAmount(); // assume amount?
        result = uint88(_result);
    }

    function divU80(uint88 x, uint256 y) internal pure returns (uint80 result) {
        uint256 _result = _mulDiv(x, UNIT, y);
        if (_result > type(uint80).max) revert Errors.InvalidAmount(); // assume amount?
        result = uint80(_result);
    }
}

// uint80
library U80 {
    // just passing the result of casting the first param to 256
    function mul(uint80 x, uint256 y) internal pure returns (uint256 result) {
        result = mulDiv18(x, y);
    }

    function mulU80(uint80 x, uint256 y) internal pure returns (uint80 result) {
        uint256 _result = mulDiv18(x, y);
        if (_result > type(uint80).max) revert Errors.InvalidPrice(); // assume price?
        result = uint80(_result);
    }

    function mulU88(uint80 x, uint256 y) internal pure returns (uint88 result) {
        uint256 _result = mulDiv18(x, y);
        if (_result > type(uint80).max) revert Errors.InvalidPrice(); // assume price?
        result = uint88(_result);
    }

    function div(uint80 x, uint256 y) internal pure returns (uint256 result) {
        result = _mulDiv(x, UNIT, y);
    }

    // test
    function inv(uint80 x) internal pure returns (uint256 result) {
        unchecked {
            // 1e36 is UNIT * UNIT.
            result = 1e36 / x;
        }
    }
}
