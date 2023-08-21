// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

library Constants {
    // @dev mark head of orders mapping
    // for all order types, starting point of orders
    uint8 internal constant HEAD = 1;
    uint8 internal constant TAIL = 1;
    uint8 internal constant STARTING_ID = 100;
    uint8 internal constant SHORT_MAX_ID = 254;
    uint8 internal constant SHORT_STARTING_ID = 2;

    uint256 internal constant MIN_DURATION = 14 days;
    uint256 internal constant CRATIO_MAX = 15 ether;
    uint256 internal constant YIELD_DELAY_HOURS = 1;
    uint256 internal constant BRIDGE_YIELD_UPDATE_THRESHOLD = 1000 ether;
    uint256 internal constant BRIDGE_YIELD_PERCENT_THRESHOLD = 0.01 ether; // 1%

    //Bridge
    uint88 internal constant MIN_DEPOSIT = 0.0001 ether;

    // re-entrancy
    uint8 internal constant NOT_ENTERED = 1;
    uint8 internal constant ENTERED = 2;
    uint256 internal constant ONE_DECIMAL_PLACES = 10;
    uint256 internal constant TWO_DECIMAL_PLACES = 100;
    uint256 internal constant THREE_DECIMAL_PLACES = 1000;
    uint256 internal constant FOUR_DECIMAL_PLACES = 10000;
    uint256 internal constant FIVE_DECIMAL_PLACES = 100000;
    uint256 internal constant SIX_DECIMAL_PLACES = 1000000;

    //set this to a datetime closer to deployment
    //changing this will likely break the end to end fork test
    uint256 internal constant STARTING_TIME = 1660353637;

    int256 internal constant PREV = -1;
    int256 internal constant EXACT = 0;
    int256 internal constant NEXT = 1;

    bool internal constant MARKET_ORDER = true;
    bool internal constant LIMIT_ORDER = false;

    //Oracle
    //Base Oracle needs to be adjust 10**10 to have full 18 precision
    int256 internal constant BASE_ORACLE_DECIMALS = 10 ** 10;

    //Mainnet TWAP
    address internal constant USDC_WETH =
        address(0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640);
    address internal constant USDC = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address internal constant WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    uint128 internal constant UNISWAP_WETH_BASE_AMT = 1 ether;
    uint256 internal constant DECIMAL_USDC = 10 ** 6; //USDC's ERC contract sets to 6 decimals
}

library Vault {
    // carbon is the default vault
    uint256 internal constant CARBON = 1;
}
