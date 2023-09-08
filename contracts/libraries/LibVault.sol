// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {IBridge} from "contracts/interfaces/IBridge.sol";

import {STypes} from "contracts/libraries/DataTypes.sol";
import {AppStorage, appStorage} from "contracts/libraries/AppStorage.sol";
import {Constants} from "contracts/libraries/Constants.sol";

import {U256, U88} from "contracts/libraries/PRBMathHelper.sol";

// import {console} from "contracts/libraries/console.sol";

library LibVault {
    using U256 for uint256;
    using U88 for uint88;
    using {zethTithePercent} for uint256;

    // BridgeRouterFacet
    function addZeth(uint256 vault, uint88 amount) internal {
        AppStorage storage s = appStorage();
        s.vaultUser[vault][msg.sender].ethEscrowed += amount;
        s.vault[vault].zethTotal += amount;
    }

    function removeZeth(uint256 vault, uint88 amount, uint88 fee) internal {
        AppStorage storage s = appStorage();
        s.vaultUser[vault][msg.sender].ethEscrowed -= (amount + fee);
        s.vault[vault].zethTotal -= amount;
    }

    // default of .1 ether, stored in uint16 as 10_00
    // range of [0-33],
    // i.e. 12.34% as 12_34 / 10_000 -> 0.1234 ether
    // @dev percentage of yield given to TAPP
    function zethTithePercent(uint256 vault) internal view returns (uint256) {
        AppStorage storage s = appStorage();
        return (uint256(s.vault[vault].zethTithePercent) * 1 ether)
            / Constants.FOUR_DECIMAL_PLACES;
    }

    function getZethTotal(uint256 vault) internal view returns (uint256 zethTotal) {
        AppStorage storage s = appStorage();
        address[] storage bridges = s.vaultBridges[vault];
        uint256 bridgeCount = bridges.length;

        for (uint256 i; i < bridgeCount;) {
            zethTotal += IBridge(bridges[i]).getZethValue();
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Updates the vault yield rate from staking rewards earned by bridge contracts holding LSD
     * @dev Does not distribute yield to any individual owner of shortRecords
     *
     * @param vault The vault that will be impacted
     */

    function updateYield(uint256 vault) internal {
        AppStorage storage s = appStorage();

        STypes.Vault storage Vault = s.vault[vault];
        STypes.VaultUser storage TAPP = s.vaultUser[vault][address(this)];
        // Retrieve vault variables
        uint88 zethTotalNew = uint88(getZethTotal(vault)); // @dev(safe-cast)
        uint88 zethTotal = Vault.zethTotal;
        uint88 zethCollateral = Vault.zethCollateral;
        uint88 zethTreasury = TAPP.ethEscrowed;

        // Calculate vault yield and overwrite previous total
        if (zethTotalNew <= zethTotal) return;
        uint88 yield = zethTotalNew - zethTotal;
        Vault.zethTotal = zethTotalNew;

        // If no short records, yield goes to treasury
        if (zethCollateral == 0) {
            TAPP.ethEscrowed += yield;
            return;
        }

        // Assign yield to zethTreasury
        uint88 zethTreasuryReward = yield.mul(zethTreasury).divU88(zethTotal);
        yield -= zethTreasuryReward;
        // Assign tithe of the remaining yield to treasuryF
        uint88 tithe = yield.mulU88(vault.zethTithePercent());
        yield -= tithe;
        // Realize assigned yields
        TAPP.ethEscrowed += zethTreasuryReward + tithe;
        Vault.zethYieldRate += yield.divU80(zethCollateral);
        Vault.zethCollateralReward += yield;
    }
}
