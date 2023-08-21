// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {STypes, MTypes, O} from "contracts/libraries/DataTypes.sol";

library Events {
    event CreateShortRecord(address indexed asset, address indexed user, uint16 id);
    event DeleteShortRecord(address indexed asset, address indexed user, uint16 id);
    event CancelOrder(address indexed asset, uint16 id, O indexed orderType);

    event DepositEth(address indexed bridge, address indexed user, uint256 amount);
    event Deposit(address indexed bridge, address indexed user, uint256 amount);
    event UnstakeEth(
        address indexed bridge, address indexed user, uint256 amount, uint256 fee
    );
    event Withdraw(
        address indexed bridge, address indexed user, uint256 amount, uint256 fee
    );
    event WithdrawTapp(address indexed bridge, address indexed recipient, uint256 amount);

    event IncreaseCollateral(
        address indexed asset, address indexed user, uint8 id, uint256 amount
    );
    event DecreaseCollateral(
        address indexed asset, address indexed user, uint8 id, uint256 amount
    );
    event CombineShorts(address indexed asset, address indexed user, uint8[] ids);

    event ExitShortWallet(
        address indexed asset, address indexed user, uint8 id, uint256 amount
    );
    event ExitShortErcEscrowed(
        address indexed asset, address indexed user, uint8 id, uint256 amount
    );
    event ExitShort(
        address indexed asset, address indexed user, uint8 id, uint256 amount
    );

    event CreateAsk(
        address indexed asset, address indexed user, uint16 id, uint32 creationTime
    );
    event CreateBid(
        address indexed asset, address indexed user, uint16 id, uint32 creationTime
    );
    event CreateShort(
        address indexed asset, address indexed user, uint16 id, uint32 creationTime
    );

    event FlagShort(
        address indexed asset,
        address indexed shorter,
        uint8 id,
        address indexed caller,
        uint256 timestamp
    );
    event Liquidate(
        address indexed asset,
        address indexed shorter,
        uint8 id,
        address indexed caller,
        uint256 amount
    );
    event LiquidateSecondary(
        address indexed asset,
        MTypes.BatchMC[] batches,
        address indexed caller,
        bool isWallet
    );

    event UpdateYield(uint256 indexed vault);
    event DistributeYield(
        uint256 indexed vault,
        address indexed user,
        uint256 yield,
        uint256 dittoYieldShares
    );
    event ClaimDittoMatchedReward(uint256 indexed vault, address indexed user);

    event ShutdownMarket(address indexed asset);
    event RedeemErc(
        address indexed asset, address indexed user, uint256 amtWallet, uint256 amtEscrow
    );

    event CreateMarket(address indexed asset, STypes.Asset assetStruct);
    event ChangeMarketSetting(address indexed asset);
    event CreateVault(address indexed zeth, uint256 indexed vault);
    event ChangeVaultSetting(uint256 indexed vault);
    event CreateBridge(address indexed bridge, STypes.Bridge bridgeStruct);
    event ChangeBridgeSetting(address indexed bridge);
    event DeleteBridge(address indexed bridge);
    event NewOwnerCandidate(address newOwnerCandidate);
    event UpdateBaseOracle(address baseOracle);
    event UpdateAssetOracle(address indexed asset, address newOracle);

    //move to test events / test types
    event FindOrderHintId(uint16 scenario);

    // ERC-721
    event Transfer(address indexed from, address indexed to, uint256 indexed id);
    event Approval(address indexed owner, address indexed spender, uint256 indexed id);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
}
