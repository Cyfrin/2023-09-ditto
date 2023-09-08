// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import "lib/forge-std/src/StdInvariant.sol";
import {IAsset} from "interfaces/IAsset.sol";
import {STypes,MTypes,O,SR} from "contracts/libraries/DataTypes.sol";
import {TestTypes} from "test/utils/TestTypes.sol";

interface IOBFixture {

  // functions from lib/forge-std/src/StdInvariant.sol
  function excludeArtifacts() external view returns (string[] memory excludedArtifacts_);
  function excludeContracts() external view returns (address[] memory excludedContracts_);
  function excludeSenders() external view returns (address[] memory excludedSenders_);
  function targetArtifacts() external view returns (string[] memory targetedArtifacts_);
  function targetArtifactSelectors() external view returns (StdInvariant.FuzzSelector[] memory targetedArtifactSelectors_);
  function targetContracts() external view returns (address[] memory targetedContracts_);
  function targetSelectors() external view returns (StdInvariant.FuzzSelector[] memory targetedSelectors_);
  function targetSenders() external view returns (address[] memory targetedSenders_);
  // public getters from test/utils/ConstantsTest.sol
  function DEFAULT_PRICE() external view returns (uint80);
  function LOWER_PRICE() external view returns (uint80);
  function HIGHER_PRICE() external view returns (uint80);
  function DEFAULT_AMOUNT() external view returns (uint88);
  function DEFAULT_TAPP() external view returns (uint88);
  function FUNDED_TAPP() external view returns (uint88);
  function TEN_HRS_PLUS() external view returns (uint256);
  function TWELVE_HRS_PLUS() external view returns (uint256);
  function SIXTEEN_HRS_PLUS() external view returns (uint256);
  function MIN_ETH() external view returns (uint256);
  function MAX_DELTA() external view returns (uint256);
  function MAX_DELTA_SMALL() external view returns (uint256);
  function ORACLE_DECIMALS() external view returns (int256);
  function DEFAULT_SHORT_HINT_ID() external view returns (uint16);
  function HIGHER_SHORT_HINT_ID() external view returns (uint16);
  function ZERO() external view returns (uint8);
  function ONE() external view returns (uint8);

  // functions from test/utils/ConstantsTest.sol
  function give(address received, uint256 amount) external;
  function give(address erc, address received, uint256 amount) external;
  // public getters from test/utils/OBFixture.sol
  function zero() external view returns (address);
  function receiver() external view returns (address);
  function sender() external view returns (address);
  function extra() external view returns (address);
  function owner() external view returns (address);
  function noDeposit() external view returns (address);
  function r() external view returns (address);
  function s() external view returns (address);
  function e() external view returns (address);
  function t() external view returns (address);
  function tapp() external view returns (address);
  function token() external view returns (address);
  function asset() external view returns (address);
  function vault() external view returns (uint256);
  function badOrderHintArray(uint256) external view returns (address);
  function sells(uint256) external view returns (address);
  function shortHintArrayStorage(uint256) external view returns (uint16);
  function initialMargin() external view returns (uint16);
  function contracts(string memory) external view returns (address);

  // functions from test/utils/OBFixture.sol
  function setUp() external;
  function setETH(int256 price) external;
  function setETHChainlinkOnly(int256 price) external;
  function createUserStruct(address account) external pure returns (TestTypes.StorageUser memory _s);
  function getUserStruct(address account) external view returns (TestTypes.StorageUser memory _s);
  function assertEq(O order1, O order2) external;
  function assertSR(SR sr1, SR sr2) external;
  function assertEqShort(STypes.ShortRecord memory a, STypes.ShortRecord memory b) external;
  function assertStruct(address account, TestTypes.StorageUser memory _ob) external;
  function fundOrder(O orderType, uint80 price, uint88 amount, address account) external;
  function createBid(
        uint80 price, uint88 amount, bool market, MTypes.OrderHint[] memory _orderHintArray, uint16[] memory _shortHintArray, address account) external returns (uint256 ethFilled, uint256 ercAmountLeft);
  function fundLimitBid(uint80 price, uint88 amount, address account) external returns (uint256 ethFilled, uint256 ercAmountLeft);
  function fundLimitBidOpt(uint80 price, uint88 amount, address account) external returns (uint256 ethFilled, uint256 ercAmountLeft);
  function fundMarketBid(uint80 price, uint88 amount, address account) external returns (uint256 ethFilled, uint256 ercAmountLeft);
  function createLimitBid(uint80 price, uint88 amount) external returns (uint256 ethFilled, uint256 ercAmountLeft);
  function createAsk(
        uint80 price, uint88 amount, bool market, MTypes.OrderHint[] memory _orderHintArray, address account) external;
  function fundLimitAsk(uint80 price, uint88 amount, address account) external;
  function fundLimitAskOpt(uint80 price, uint88 amount, address account) external;
  function fundMarketAsk(uint80 price, uint88 amount, address account) external;
  function createLimitAsk(uint80 price, uint88 amount) external;
  function createShort(
        uint80 price, uint88 amount, MTypes.OrderHint[] memory _orderHintArray, uint16[] memory _shortHintArray, address account) external;
  function fundLimitShort(uint80 price, uint88 amount, address account) external;
  function fundLimitShortOpt(uint80 price, uint88 amount, address account) external;
  function createLimitShort(uint80 price, uint88 amount) external;
  function getShortRecord(address shorter, uint8 id) external view returns (STypes.ShortRecord memory);
  function getShortRecordCount(address shorter) external view returns (uint256);
  function depositEth(address account, uint88 amount) external;
  function depositUsd(address account, uint88 amount) external;
  function transferUsd(address from, address to, uint104 amount) external;
  function depositEthAndPrank(address account, uint88 amount) external;
  function depositUsdAndPrank(address account, uint88 amount) external;
  function getBids() external view returns (STypes.Order[] memory bids);
  function getAsks() external view returns (STypes.Order[] memory asks);
  function getShorts() external view returns (STypes.Order[] memory shorts);
  function increaseCollateral(uint8 id, uint80 amount) external;
  function decreaseCollateral(uint8 id, uint80 amount) external;
  function cancelAsk(uint16 id) external;
  function cancelShort(uint16 id) external;
  function cancelBid(uint16 id) external;
  function combineShorts(uint8 id1, uint8 id2) external;
  function exitShort(uint8 id, uint88 amount, uint80 price, address account) external;
  function exitShort(uint8 id, uint88 amount, uint80 price) external;
  function exitShortWallet(uint8 id, uint88 amount, address account) external;
  function exitShortErcEscrowed(uint8 id, uint88 amount, address account) external;
  function liquidate(address shorter, uint8 id, address account) external;
  function liquidateErcEscrowed(
        address shorter, uint8 id, uint88 amount, address account) external;
  function liquidateWallet(address shorter, uint8 id, uint88 amount, address account) external;
  function redeemErc(uint88 amtWallet, uint88 amtEscrow, address account) external;
  function min(uint256 a, uint256 b) external pure returns (uint256);
  function submitBalances(uint256 _ethSupply, uint256 _rethSupply) external;
  function getExchangeRate() external view returns (uint256);
  function checkOrdersPriceValidity() external;
  function getErcInMarket() external view returns (uint256);
  function getTotalErc() external view returns (uint256);
  function setShortHintArray() external view returns (uint16[] memory);
  function skipTimeAndSetEth(uint256 skipTime, int256 ethPrice) external;
}