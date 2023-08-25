// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U88} from "contracts/libraries/PRBMathHelper.sol";

import {STypes} from "contracts/libraries/DataTypes.sol";
import {OBFixture} from "test/utils/OBFixture.sol";

// import {console} from "contracts/libraries/console.sol";

contract AskOrdersSortingTest is OBFixture {
    using U88 for uint88;

    uint256 private startGas;
    uint256 private gasUsed;
    uint256 private gasUsedOptimized;

    bool internal constant ASK = true;
    bool internal constant SHORT = false;

    //@dev: Technically, this test file might not be necessary since we split up ask and short into separate mappings

    function setUp() public override {
        super.setUp();
    }

    function assertEqSellDifferentPricesDifferentAmounts(STypes.Order[] memory order)
        public
    {
        assertEq(order[0].price, 4 ether);
        assertEq(order[1].price, 5 ether);
        assertEq(order[2].price, 6 ether);
        assertEq(order[3].price, 7 ether);
        assertEq(order[4].price, 8 ether);
        assertEq(order[5].price, 9 ether);

        assertEq(order[0].ercAmount, DEFAULT_AMOUNT.mulU88(4 ether));
        assertEq(order[1].ercAmount, DEFAULT_AMOUNT.mulU88(5 ether));
        assertEq(order[2].ercAmount, DEFAULT_AMOUNT.mulU88(6 ether));
        assertEq(order[3].ercAmount, DEFAULT_AMOUNT.mulU88(7 ether));
        assertEq(order[4].ercAmount, DEFAULT_AMOUNT.mulU88(8 ether));
        assertEq(order[5].ercAmount, DEFAULT_AMOUNT.mulU88(9 ether));
    }

    function assertEqSellSamePricesDifferentAmounts(
        STypes.Order[] memory order,
        uint256 price
    ) public {
        assertEq(order[0].price, price);
        assertEq(order[1].price, price);
        assertEq(order[2].price, price);
        assertEq(order[3].price, price);
        assertEq(order[4].price, price);
        assertEq(order[5].price, price);

        assertEq(order[0].ercAmount, DEFAULT_AMOUNT.mulU88(4 ether));
        assertEq(order[1].ercAmount, DEFAULT_AMOUNT.mulU88(5 ether));
        assertEq(order[2].ercAmount, DEFAULT_AMOUNT.mulU88(6 ether));
        assertEq(order[3].ercAmount, DEFAULT_AMOUNT.mulU88(7 ether));
        assertEq(order[4].ercAmount, DEFAULT_AMOUNT.mulU88(8 ether));
        assertEq(order[5].ercAmount, DEFAULT_AMOUNT.mulU88(9 ether));
    }

    function createSellsDifferentPricesDifferentAmounts(bool sellType) public {
        if (sellType == ASK) {
            fundLimitAskOpt(5 ether, DEFAULT_AMOUNT.mulU88(5 ether), receiver);
            fundLimitAskOpt(6 ether, DEFAULT_AMOUNT.mulU88(6 ether), receiver);
            fundLimitAskOpt(7 ether, DEFAULT_AMOUNT.mulU88(7 ether), receiver);
            fundLimitAskOpt(4 ether, DEFAULT_AMOUNT.mulU88(4 ether), receiver);
            fundLimitAskOpt(8 ether, DEFAULT_AMOUNT.mulU88(8 ether), receiver);
            fundLimitAskOpt(9 ether, DEFAULT_AMOUNT.mulU88(9 ether), receiver);
        } else {
            fundLimitShortOpt(5 ether, DEFAULT_AMOUNT.mulU88(5 ether), receiver);
            fundLimitShortOpt(6 ether, DEFAULT_AMOUNT.mulU88(6 ether), receiver);
            fundLimitShortOpt(7 ether, DEFAULT_AMOUNT.mulU88(7 ether), receiver);
            fundLimitShortOpt(4 ether, DEFAULT_AMOUNT.mulU88(4 ether), receiver);
            fundLimitShortOpt(8 ether, DEFAULT_AMOUNT.mulU88(8 ether), receiver);
            fundLimitShortOpt(9 ether, DEFAULT_AMOUNT.mulU88(9 ether), receiver);
        }
    }

    function createSellsSamePricesDifferentAmounts(bool sellType, uint80 price) public {
        if (sellType == ASK) {
            fundLimitAskOpt(price, DEFAULT_AMOUNT.mulU88(4 ether), receiver);
            fundLimitAskOpt(price, DEFAULT_AMOUNT.mulU88(5 ether), receiver);
            fundLimitAskOpt(price, DEFAULT_AMOUNT.mulU88(6 ether), receiver);
            fundLimitAskOpt(price, DEFAULT_AMOUNT.mulU88(7 ether), receiver);
            fundLimitAskOpt(price, DEFAULT_AMOUNT.mulU88(8 ether), receiver);
            fundLimitAskOpt(price, DEFAULT_AMOUNT.mulU88(9 ether), receiver);
        } else {
            fundLimitShortOpt(price, DEFAULT_AMOUNT.mulU88(4 ether), receiver);
            fundLimitShortOpt(price, DEFAULT_AMOUNT.mulU88(5 ether), receiver);
            fundLimitShortOpt(price, DEFAULT_AMOUNT.mulU88(6 ether), receiver);
            fundLimitShortOpt(price, DEFAULT_AMOUNT.mulU88(7 ether), receiver);
            fundLimitShortOpt(price, DEFAULT_AMOUNT.mulU88(8 ether), receiver);
            fundLimitShortOpt(price, DEFAULT_AMOUNT.mulU88(9 ether), receiver);
        }
    }

    //backend/fallback/non-optimized (no hint or bad hint)
    //adding asks

    function testAddingAskToOBWithExistingAsksDifferentPriceNoShorts() public {
        createSellsDifferentPricesDifferentAmounts(ASK);
        assertEqSellDifferentPricesDifferentAmounts(getAsks());
    }

    function testAddingAskToOBWithExistingAsksSamePriceNoShorts() public {
        createSellsSamePricesDifferentAmounts(ASK, 5 ether);
        assertEqSellSamePricesDifferentAmounts(getAsks(), 5 ether);
    }

    function testAddingAskToOBWithExistingShortsSamePriceNoAsks() public {
        //fill market with shorts
        createSellsSamePricesDifferentAmounts(SHORT, 5 ether);
        //create one ask
        fundLimitAskOpt(5 ether, DEFAULT_AMOUNT.mulU88(10 ether), receiver);

        assertEqSellSamePricesDifferentAmounts(getShorts(), 5 ether);
        STypes.Order[] memory asks = getAsks();
        assertEq(asks[0].ercAmount, DEFAULT_AMOUNT.mulU88(10 ether));
    }

    //adding short
    function testAddingShortToOBWithExistingAskDifferentPriceNoShorts() public {
        //fill market with asks
        createSellsDifferentPricesDifferentAmounts(ASK);
        //create one short
        fundLimitShortOpt(9 ether, DEFAULT_AMOUNT.mulU88(10 ether), receiver);

        assertEqSellDifferentPricesDifferentAmounts(getAsks());
        STypes.Order[] memory shorts = getShorts();
        assertEq(shorts[0].ercAmount, DEFAULT_AMOUNT.mulU88(10 ether));
    }

    function testAddingShortToOBWithExistingAskSamePriceNoShorts() public {
        //fill market with asks
        createSellsSamePricesDifferentAmounts(ASK, 5 ether);
        //create one short
        fundLimitShortOpt(5 ether, DEFAULT_AMOUNT.mulU88(10 ether), receiver);

        assertEqSellSamePricesDifferentAmounts(getAsks(), 5 ether);
        STypes.Order[] memory shorts = getShorts();
        assertEq(shorts[0].ercAmount, DEFAULT_AMOUNT.mulU88(10 ether));
    }

    function testAddingShortToOBWithExistingShortsDifferentPriceNoAsks() public {
        createSellsDifferentPricesDifferentAmounts(SHORT);
        assertEqSellDifferentPricesDifferentAmounts(getShorts());
    }

    function testAddingShortToOBWithExistingShortsSamePriceNoAsks() public {
        createSellsSamePricesDifferentAmounts(SHORT, 5 ether);
        assertEqSellSamePricesDifferentAmounts(getShorts(), 5 ether);
    }

    //optimized
    function testAddingAsksShortTomarketOptimized() public {
        fundLimitShortOpt(5 ether, DEFAULT_AMOUNT.mulU88(5 ether), receiver);
        fundLimitShortOpt(6 ether, DEFAULT_AMOUNT.mulU88(6 ether), receiver);
        fundLimitShortOpt(7 ether, DEFAULT_AMOUNT.mulU88(7 ether), receiver);
        fundLimitShortOpt(4 ether, DEFAULT_AMOUNT.mulU88(4 ether), receiver);
        fundLimitShortOpt(8 ether, DEFAULT_AMOUNT.mulU88(8 ether), receiver);
        fundLimitShortOpt(9 ether, DEFAULT_AMOUNT.mulU88(9 ether), receiver);

        assertEqSellDifferentPricesDifferentAmounts(getShorts());
    }

    function testAddingAsksSellTomarketOptimized() public {
        fundLimitAskOpt(5 ether, DEFAULT_AMOUNT.mulU88(5 ether), receiver);
        fundLimitAskOpt(6 ether, DEFAULT_AMOUNT.mulU88(6 ether), receiver);
        fundLimitAskOpt(7 ether, DEFAULT_AMOUNT.mulU88(7 ether), receiver);
        fundLimitAskOpt(4 ether, DEFAULT_AMOUNT.mulU88(4 ether), receiver);
        fundLimitAskOpt(8 ether, DEFAULT_AMOUNT.mulU88(8 ether), receiver);
        fundLimitAskOpt(9 ether, DEFAULT_AMOUNT.mulU88(9 ether), receiver);

        assertEqSellDifferentPricesDifferentAmounts(getAsks());
    }
}
