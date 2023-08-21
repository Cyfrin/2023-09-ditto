// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U88} from "contracts/libraries/PRBMathHelper.sol";

import {IBridge} from "contracts/interfaces/IBridge.sol";

import {Modifiers} from "contracts/libraries/AppStorage.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {Events} from "contracts/libraries/Events.sol";
import {LibBridge} from "contracts/libraries/LibBridge.sol";
import {LibVault} from "contracts/libraries/LibVault.sol";
import {Constants, Vault} from "contracts/libraries/Constants.sol";

// import {console} from "contracts/libraries/console.sol";

contract BridgeRouterFacet is Modifiers {
    using U256 for uint256;
    using U88 for uint88;
    using LibBridge for uint256;
    using LibBridge for address;
    using LibVault for uint256;

    address private immutable rethBridge;
    address private immutable stethBridge;

    constructor(address _rethBridge, address _stethBridge) {
        rethBridge = _rethBridge;
        stethBridge = _stethBridge;
    }

    function getZethTotal(uint256 vault)
        external
        view
        nonReentrantView
        returns (uint256)
    {
        return vault.getZethTotal();
    }

    //@dev does not need read only re-entrancy
    function getBridges(uint256 vault) external view returns (address[] memory) {
        return s.vaultBridges[vault];
    }

    function deposit(address bridge, uint88 amount)
        external
        nonReentrant
        onlyValidBridge(bridge)
    {
        if (amount < Constants.MIN_DEPOSIT) revert Errors.UnderMinimumDeposit();
        // @dev amount after deposit might be less, if bridge takes a fee
        uint88 zethAmount = uint88(IBridge(bridge).deposit(msg.sender, amount)); // @dev(safe-cast)

        uint256 vault;
        if (bridge == rethBridge || bridge == stethBridge) {
            vault = Vault.CARBON;
        } else {
            vault = s.bridge[bridge].vault;
        }

        vault.addZeth(zethAmount);
        maybeUpdateYield(vault, zethAmount);
        emit Events.Deposit(bridge, msg.sender, zethAmount);
    }

    //review triple check for reentrancy
    function depositEth(address bridge)
        external
        payable
        nonReentrant
        onlyValidBridge(bridge)
    {
        if (msg.value < Constants.MIN_DEPOSIT) revert Errors.UnderMinimumDeposit();

        uint256 vault;
        if (bridge == rethBridge || bridge == stethBridge) {
            vault = Vault.CARBON;
        } else {
            vault = s.bridge[bridge].vault;
        }

        uint88 zethAmount = uint88(IBridge(bridge).depositEth{value: msg.value}()); // Assumes 1 ETH = 1 ZETH
        vault.addZeth(zethAmount);
        maybeUpdateYield(vault, zethAmount);
        emit Events.DepositEth(bridge, msg.sender, zethAmount);
    }

    function withdraw(address bridge, uint88 zethAmount)
        external
        nonReentrant
        onlyValidBridge(bridge)
    {
        if (zethAmount == 0) revert Errors.ParameterIsZero();

        uint88 fee;
        uint256 withdrawalFee = bridge.withdrawalFee();
        uint256 vault;
        if (bridge == rethBridge || bridge == stethBridge) {
            vault = Vault.CARBON;
        } else {
            vault = s.bridge[bridge].vault;
        }

        if (withdrawalFee > 0) {
            fee = zethAmount.mulU88(withdrawalFee);
            zethAmount -= fee;
            s.vaultUser[vault][address(this)].ethEscrowed += fee;
        }

        uint88 ethAmount = _ethConversion(vault, zethAmount);
        vault.removeZeth(zethAmount, fee);
        IBridge(bridge).withdraw(msg.sender, ethAmount);
        emit Events.Withdraw(bridge, msg.sender, zethAmount, fee);
    }

    function unstakeEth(address bridge, uint88 zethAmount)
        external
        nonReentrant
        onlyValidBridge(bridge)
    {
        if (zethAmount == 0) revert Errors.ParameterIsZero();

        uint88 fee = zethAmount.mulU88(bridge.unstakeFee());

        uint256 vault;
        if (bridge == rethBridge || bridge == stethBridge) {
            vault = Vault.CARBON;
        } else {
            vault = s.bridge[bridge].vault;
        }

        if (fee > 0) {
            zethAmount -= fee;
            s.vaultUser[vault][address(this)].ethEscrowed += fee;
        }
        uint88 ethAmount = _ethConversion(vault, zethAmount);
        vault.removeZeth(zethAmount, fee);
        IBridge(bridge).unstake(msg.sender, ethAmount);
        emit Events.UnstakeEth(bridge, msg.sender, zethAmount, fee);
    }

    function withdrawTapp(address bridge, uint88 zethAmount)
        external
        onlyOwner
        onlyValidBridge(bridge)
    {
        if (zethAmount == 0) revert Errors.ParameterIsZero();

        uint256 vault;
        if (bridge == rethBridge || bridge == stethBridge) {
            vault = Vault.CARBON;
        } else {
            vault = s.bridge[bridge].vault;
        }
        uint88 ethAmount = _ethConversion(vault, zethAmount);

        s.vaultUser[vault][address(this)].ethEscrowed -= zethAmount;
        s.vault[vault].zethTotal -= zethAmount;

        IBridge(bridge).withdraw(msg.sender, ethAmount);
        emit Events.WithdrawTapp(bridge, msg.sender, zethAmount);
    }

    function maybeUpdateYield(uint256 vault, uint88 amount) private {
        uint88 zethTotal = s.vault[vault].zethTotal;
        if (
            zethTotal > Constants.BRIDGE_YIELD_UPDATE_THRESHOLD
                && amount.div(zethTotal) > Constants.BRIDGE_YIELD_PERCENT_THRESHOLD
        ) {
            // Update yield for "large" bridge deposits
            vault.updateYield();
        }
    }

    function _ethConversion(uint256 vault, uint88 amount) private view returns (uint88) {
        uint256 zethTotalNew = vault.getZethTotal();
        uint88 zethTotal = s.vault[vault].zethTotal;

        if (zethTotalNew >= zethTotal) {
            // when yield is positive 1 zeth = 1 eth
            return amount;
        } else {
            // negative yield means 1 zeth < 1 eth
            return amount.mulU88(zethTotalNew).divU88(zethTotal);
        }
    }
}
