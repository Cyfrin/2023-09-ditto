// https://docs.rocketpool.net/developers/usage/contracts/contracts.html#implementation
// https://github.com/rocket-pool/rocketpool/blob/master/contracts/contract/token/RocketTokenRETH.sol

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {IRocketStorage} from "interfaces/IRocketStorage.sol";
import {IRocketTokenRETH} from "interfaces/IRocketTokenRETH.sol";
import {IRocketDepositPool} from "interfaces/IRocketDepositPool.sol";
import {IBridge} from "contracts/interfaces/IBridge.sol";

// import {console} from "contracts/libraries/console.sol";

contract BridgeReth is IBridge {
    bytes32 private immutable RETH_TYPEHASH;
    bytes32 private immutable ROCKET_DEPOSIT_POOL_TYPEHASH;
    IRocketStorage private immutable rocketStorage;
    address private immutable diamond;

    constructor(IRocketStorage rocketStorageAddress, address diamondAddr) {
        rocketStorage = IRocketStorage(rocketStorageAddress);
        diamond = diamondAddr;
        // @dev (gas) use immutable instead of constant
        // See https://github.com/ethereum/solidity/issues/9232#issuecomment-646131646
        RETH_TYPEHASH = keccak256(abi.encodePacked("contract.address", "rocketTokenRETH"));
        ROCKET_DEPOSIT_POOL_TYPEHASH =
            keccak256(abi.encodePacked("contract.address", "rocketDepositPool"));
    }

    modifier onlyDiamond() {
        if (msg.sender != diamond) {
            revert NotDiamond();
        }
        _;
    }

    receive() external payable {}

    function _getRethContract() private view returns (IRocketTokenRETH) {
        return IRocketTokenRETH(rocketStorage.getAddress(RETH_TYPEHASH));
    }

    //@dev does not need read only re-entrancy
    function getBaseCollateral() external view returns (address) {
        return rocketStorage.getAddress(RETH_TYPEHASH);
    }

    //@dev does not need read only re-entrancy
    function getZethValue() external view returns (uint256) {
        IRocketTokenRETH rocketETHToken = _getRethContract();
        return rocketETHToken.getEthValue(rocketETHToken.balanceOf(address(this)));
    }

    // @dev ERC20 success https://ethereum.stackexchange.com/questions/148216/when-would-an-erc20-return-false
    // Bring rETH to system and credit zETH to user
    function deposit(address from, uint256 amount)
        external
        onlyDiamond
        returns (uint256)
    {
        IRocketTokenRETH rocketETHToken = _getRethContract();
        // Transfer rETH to this bridge contract
        // @dev RETH uses OZ ERC-20, don't need to check success bool
        rocketETHToken.transferFrom(from, address(this), amount);
        // Calculate rETH equivalent value in ETH
        return rocketETHToken.getEthValue(amount);
    }

    // Deposit ETH and mint rETH (to system) and credit zETH to user
    function depositEth() external payable onlyDiamond returns (uint256) {
        IRocketDepositPool rocketDepositPool =
            IRocketDepositPool(rocketStorage.getAddress(ROCKET_DEPOSIT_POOL_TYPEHASH));
        IRocketTokenRETH rocketETHToken = _getRethContract();

        uint256 originalBalance = rocketETHToken.balanceOf(address(this));
        rocketDepositPool.deposit{value: msg.value}();
        uint256 netBalance = rocketETHToken.balanceOf(address(this)) - originalBalance;
        if (netBalance == 0) revert NetBalanceZero();

        return rocketETHToken.getEthValue(netBalance);
    }

    // Exchange system rETH to fulfill zETH obligation to user
    function withdraw(address to, uint256 amount)
        external
        onlyDiamond
        returns (uint256)
    {
        IRocketTokenRETH rocketETHToken = _getRethContract();
        // Calculate zETH equivalent value in rETH
        uint256 rethValue = rocketETHToken.getRethValue(amount);
        // Transfer rETH from this bridge contract
        // @dev RETH uses OZ ERC-20, don't need to check success bool
        rocketETHToken.transfer(to, rethValue);
        return rethValue;
    }

    function unstake(address to, uint256 amount) external onlyDiamond {
        IRocketTokenRETH rocketETHToken = _getRethContract();
        uint256 rethValue = rocketETHToken.getRethValue(amount);
        uint256 originalBalance = address(this).balance;
        rocketETHToken.burn(rethValue);
        uint256 netBalance = address(this).balance - originalBalance;
        if (netBalance == 0) revert NetBalanceZero();
        (bool sent,) = to.call{value: netBalance}("");
        assert(sent);
    }
}
