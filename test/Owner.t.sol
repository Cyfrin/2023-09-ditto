// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {Asset} from "contracts/tokens/Asset.sol";

import {Errors} from "contracts/libraries/Errors.sol";
import {OBFixture} from "test/utils/OBFixture.sol";
import {MTypes, STypes, F} from "contracts/libraries/DataTypes.sol";
import {Vault} from "contracts/libraries/Constants.sol";
// import {console} from "contracts/libraries/console.sol";

contract OwnerTest is OBFixture {
    function setUp() public override {
        super.setUp();
    }

    function testOwnerRevert() public {
        vm.prank(sender);
        vm.expectRevert("LibDiamond: Must be contract owner");
        diamond.transferOwnership(extra);
    }

    function testOwnerCandidateRevert() public {
        vm.prank(owner);
        diamond.transferOwnership(extra);
        vm.prank(sender);
        vm.expectRevert(Errors.NotOwnerCandidate.selector);
        diamond.claimOwnership();
    }

    function testOwnerCandidate() public {
        assertEq(diamond.owner(), owner);
        assertEq(diamond.ownerCandidate(), address(0));

        vm.prank(owner);
        diamond.transferOwnership(extra);

        assertEq(diamond.owner(), owner);
        assertEq(diamond.ownerCandidate(), extra);

        vm.prank(extra);
        diamond.claimOwnership();

        assertEq(diamond.owner(), extra);
        assertEq(diamond.ownerCandidate(), address(0));
    }

    function test_TransferAdminship() public {
        vm.prank(owner);
        diamond.transferAdminship(extra);
        assertEq(diamond.owner(), owner);
        assertEq(diamond.admin(), extra);
        vm.prank(extra);
        diamond.transferAdminship(sender);
        assertEq(diamond.admin(), sender);
    }

    function test_OnlyAdminOrOwner() public {
        test_TransferAdminship();
        vm.prank(owner);
        diamond.transferAdminship(extra);
        assertEq(diamond.admin(), extra);
    }

    function testRevert_OnlyAdmin() public {
        vm.prank(owner);
        diamond.transferAdminship(extra);
        assertEq(diamond.owner(), owner);
        assertEq(diamond.admin(), extra);
        vm.prank(sender);
        vm.expectRevert(Errors.NotOwnerOrAdmin.selector);
        diamond.transferAdminship(sender);
    }

    //Unit tests for setters
    //REVERT//
    function test_setTithe() public {
        vm.expectRevert(Errors.NotOwnerOrAdmin.selector);
        diamond.setTithe(Vault.CARBON, 2);
    }

    function testRevert_setDittoMatchedRate() public {
        vm.startPrank(owner);
        vm.expectRevert("above 100");
        diamond.setDittoMatchedRate(Vault.CARBON, 101);
    }

    function testRevert_setDittoShorterRate() public {
        vm.startPrank(owner);
        vm.expectRevert("above 100");
        diamond.setDittoShorterRate(Vault.CARBON, 101);
    }

    function testRevert_SetResetLiquidationTime() public {
        vm.expectRevert(Errors.NotOwnerOrAdmin.selector);
        diamond.setResetLiquidationTime(asset, 100);

        vm.startPrank(owner);
        vm.expectRevert("below 1.00");
        diamond.setResetLiquidationTime(asset, 100 - 1);
        vm.expectRevert("above 48.00");
        diamond.setResetLiquidationTime(asset, 4800 + 1);
    }

    function testRevert_SetSecondLiquidationTime() public {
        vm.expectRevert(Errors.NotOwnerOrAdmin.selector);
        diamond.setSecondLiquidationTime(asset, 100);

        vm.startPrank(owner);
        vm.expectRevert("below 1.00");
        diamond.setSecondLiquidationTime(asset, 100 - 1);
        vm.expectRevert("above resetLiquidationTime");
        diamond.setSecondLiquidationTime(asset, 1800);
    }

    function testRevert_SetFirstLiquidationTime() public {
        vm.expectRevert(Errors.NotOwnerOrAdmin.selector);
        diamond.setFirstLiquidationTime(asset, 100);

        vm.startPrank(owner);
        vm.expectRevert("below 1.00");
        diamond.setFirstLiquidationTime(asset, 100 - 1);
        vm.expectRevert("above secondLiquidationTime");
        diamond.setFirstLiquidationTime(asset, 1300);
    }

    function testRevert_SetInitialMargin() public {
        vm.expectRevert(Errors.NotOwnerOrAdmin.selector);
        diamond.setFirstLiquidationTime(asset, 10);

        vm.startPrank(owner);
        vm.expectRevert("below primary liquidation");
        diamond.setInitialMargin(asset, 100 - 1);
        vm.expectRevert("above max CR");
        diamond.setInitialMargin(asset, 1500);
    }

    function testRevert_SetprimaryLiquidationCR() public {
        vm.expectRevert(Errors.NotOwnerOrAdmin.selector);
        diamond.setFirstLiquidationTime(asset, 10);

        vm.startPrank(owner);
        vm.expectRevert("below secondary liquidation");
        diamond.setPrimaryLiquidationCR(asset, 100 - 1);
        vm.expectRevert("above 5.0");
        diamond.setPrimaryLiquidationCR(asset, 500 + 1);
    }

    function testRevert_SetsecondaryLiquidationCR() public {
        vm.expectRevert(Errors.NotOwnerOrAdmin.selector);
        diamond.setSecondaryLiquidationCR(asset, 100);

        vm.startPrank(owner);
        vm.expectRevert("below 1.0");
        diamond.setSecondaryLiquidationCR(asset, 100 - 1);
        vm.expectRevert("above 5.0");
        diamond.setSecondaryLiquidationCR(asset, 500 + 1);
        diamond.setInitialMargin(asset, 800);
        vm.expectRevert("above 5.0");
        diamond.setSecondaryLiquidationCR(asset, 500 + 1);
    }

    function testRevert_SetforcedBidPriceBuffer() public {
        vm.expectRevert(Errors.NotOwnerOrAdmin.selector);
        diamond.setForcedBidPriceBuffer(asset, 100);

        vm.startPrank(owner);
        vm.expectRevert("below 1.0");
        diamond.setForcedBidPriceBuffer(asset, 100 - 1);
        vm.expectRevert("above 2.0");
        diamond.setForcedBidPriceBuffer(asset, 200 + 1);
    }

    function testRevert_SetminimumCR() public {
        vm.expectRevert(Errors.NotOwnerOrAdmin.selector);
        diamond.setMinimumCR(asset, 100);

        vm.startPrank(owner);
        vm.expectRevert("below 1.0");
        diamond.setMinimumCR(asset, 100 - 1);
        vm.expectRevert("above 2.0");
        diamond.setMinimumCR(asset, 200 + 1);
    }

    function testRevert_SetTappFeePct() public {
        vm.expectRevert(Errors.NotOwnerOrAdmin.selector);
        diamond.setTappFeePct(asset, 10);

        vm.startPrank(owner);
        vm.expectRevert("Can't be zero");
        diamond.setTappFeePct(asset, 0);
        vm.expectRevert("above 25.0");
        diamond.setTappFeePct(asset, 250 + 1);
    }

    function testRevert_SetCallerFeePct() public {
        vm.expectRevert(Errors.NotOwnerOrAdmin.selector);
        diamond.setCallerFeePct(asset, 10);

        vm.startPrank(owner);
        vm.expectRevert("Can't be zero");
        diamond.setCallerFeePct(asset, 0);
        vm.expectRevert("above 25.0");
        diamond.setCallerFeePct(asset, 250 + 1);
    }

    function testRevert_SetMinBidEth() public {
        vm.expectRevert(Errors.NotOwnerOrAdmin.selector);
        diamond.setMinBidEth(asset, 10);

        vm.startPrank(owner);
        vm.expectRevert("Can't be zero");
        diamond.setMinBidEth(asset, 0);
    }

    function testRevert_SetMinAskEth() public {
        vm.expectRevert(Errors.NotOwnerOrAdmin.selector);
        diamond.setMinAskEth(asset, 10);

        vm.startPrank(owner);
        vm.expectRevert("Can't be zero");
        diamond.setMinAskEth(asset, 0);
    }

    function testRevert_SetMinShortErc() public {
        vm.expectRevert(Errors.NotOwnerOrAdmin.selector);
        diamond.setMinShortErc(asset, 10);

        vm.startPrank(owner);
        vm.expectRevert("Can't be zero");
        diamond.setMinShortErc(asset, 0);
    }

    function testRevert_createBridge() public {
        vm.expectRevert("LibDiamond: Must be contract owner");
        diamond.createBridge(address(1), Vault.CARBON, 1501, 0);

        vm.startPrank(owner);
        vm.expectRevert("above 15.00%");
        diamond.createBridge(address(1), Vault.CARBON, 1501, 0);
    }

    function testRevert_WithdrawalFee() public {
        vm.expectRevert(Errors.NotOwnerOrAdmin.selector);
        diamond.setWithdrawalFee(asset, 10);

        vm.startPrank(owner);
        vm.expectRevert("above 15.00%");
        diamond.setWithdrawalFee(_bridgeSteth, 1501);
    }

    //NON-REVERT//
    function test_setDittoMatchedRate() public {
        vm.prank(owner);
        diamond.setDittoMatchedRate(Vault.CARBON, 2);

        assertEq(diamond.getVaultStruct(vault).dittoMatchedRate, 2);
    }

    function test_setDittoShorterRate() public {
        vm.prank(owner);
        diamond.setDittoShorterRate(Vault.CARBON, 2);

        assertEq(diamond.getVaultStruct(vault).dittoShorterRate, 2);
    }

    function testSetInitialMargin() public {
        assertEq(diamond.getAssetStruct(asset).initialMargin, 500);
        vm.prank(owner);
        diamond.setInitialMargin(asset, 450);
        assertEq(diamond.getAssetStruct(asset).initialMargin, 450);
    }

    function testSetprimaryLiquidationCR() public {
        assertEq(diamond.getAssetStruct(asset).primaryLiquidationCR, 400);
        vm.prank(owner);
        diamond.setPrimaryLiquidationCR(asset, 200);
        assertEq(diamond.getAssetStruct(asset).primaryLiquidationCR, 200);
    }

    function testSetsecondaryLiquidationCR() public {
        assertEq(diamond.getAssetStruct(asset).secondaryLiquidationCR, 150);
        vm.prank(owner);
        diamond.setSecondaryLiquidationCR(asset, 200);
        assertEq(diamond.getAssetStruct(asset).secondaryLiquidationCR, 200);
    }

    function testSetforcedBidPriceBuffer() public {
        assertEq(diamond.getAssetStruct(asset).forcedBidPriceBuffer, 110);
        vm.prank(owner);
        diamond.setForcedBidPriceBuffer(asset, 200);
        assertEq(diamond.getAssetStruct(asset).forcedBidPriceBuffer, 200);
    }

    function testSetminimumCR() public {
        assertEq(diamond.getAssetStruct(asset).minimumCR, 110);
        vm.prank(owner);
        diamond.setMinimumCR(asset, 115);
        assertEq(diamond.getAssetStruct(asset).minimumCR, 115);
    }

    function testSetResetLiquidationTime() public {
        assertEq(diamond.getAssetStruct(asset).resetLiquidationTime, 1600);
        vm.prank(owner);
        diamond.setResetLiquidationTime(asset, 1300);
        assertEq(diamond.getAssetStruct(asset).resetLiquidationTime, 1300);
    }

    function testSetSecondLiquidationTime() public {
        assertEq(diamond.getAssetStruct(asset).secondLiquidationTime, 1200);
        vm.prank(owner);
        diamond.setSecondLiquidationTime(asset, 1100);
        assertEq(diamond.getAssetStruct(asset).secondLiquidationTime, 1100);
    }

    function testSetFirstLiquidationTime() public {
        assertEq(diamond.getAssetStruct(asset).firstLiquidationTime, 1000);
        vm.prank(owner);
        diamond.setFirstLiquidationTime(asset, 200);
        assertEq(diamond.getAssetStruct(asset).firstLiquidationTime, 200);
    }

    function testSetTappFeePct() public {
        assertEq(diamond.getAssetStruct(asset).tappFeePct, 25);
        vm.prank(owner);
        diamond.setTappFeePct(asset, 200);
        assertEq(diamond.getAssetStruct(asset).tappFeePct, 200);
    }

    function testSetCallerFeePct() public {
        assertEq(diamond.getAssetStruct(asset).callerFeePct, 5);
        vm.prank(owner);
        diamond.setCallerFeePct(asset, 200);
        assertEq(diamond.getAssetStruct(asset).callerFeePct, 200);
    }

    function testSetMinBidEth() public {
        assertEq(diamond.getAssetStruct(asset).minBidEth, 1);
        vm.prank(owner);
        diamond.setMinBidEth(asset, 2);
        assertEq(diamond.getAssetStruct(asset).minBidEth, 2);
    }

    function testSetMinAskEth() public {
        assertEq(diamond.getAssetStruct(asset).minAskEth, 1);
        vm.prank(owner);
        diamond.setMinAskEth(asset, 2);
        assertEq(diamond.getAssetStruct(asset).minAskEth, 2);
    }

    function testSetMinShortErc() public {
        assertEq(diamond.getAssetStruct(asset).minShortErc, 2000);
        vm.prank(owner);
        diamond.setMinShortErc(asset, 3000);
        assertEq(diamond.getAssetStruct(asset).minShortErc, 3000);
    }

    function test_CreateBridge() public {
        uint256 length = diamond.getBridges(Vault.CARBON).length;
        address newBridge = address(1);
        vm.prank(owner);
        diamond.createBridge(newBridge, Vault.CARBON, 0, 0);
        assertEq(diamond.getBridges(Vault.CARBON).length, length + 1);
        assertEq(diamond.getBridges(Vault.CARBON)[length], newBridge);
        assertEq(diamond.getBridgeVault(newBridge), Vault.CARBON);
        assertEq(diamond.getBridgeNormalizedStruct(newBridge).withdrawalFee, 0);
        assertEq(diamond.getBridgeNormalizedStruct(newBridge).unstakeFee, 0);
    }

    function test_WithdrawalFee() public {
        vm.startPrank(owner);
        diamond.setWithdrawalFee(_bridgeSteth, 1500);
        assertEq(
            diamond.getBridgeNormalizedStruct(_bridgeSteth).withdrawalFee, 0.15 ether
        );
    }

    address[] private bridges;

    function test_DeleteBridge() public {
        uint256 VAULT = 2;
        assertEq(diamond.getBridges(VAULT).length, 0);

        address newBridge1 = address(1);
        address newBridge2 = address(2);
        address newBridge3 = address(3);

        vm.prank(owner);
        diamond.createBridge(newBridge1, VAULT, 0, 0);
        bridges = [newBridge1];
        assertEq(diamond.getBridges(VAULT), bridges);
        assertEq(diamond.getBridges(VAULT).length, 1);
        assertEq(diamond.getBridgeVault(newBridge1), VAULT);
        assertEq(diamond.getBridgeVault(newBridge2), 0);
        assertEq(diamond.getBridgeVault(newBridge3), 0);

        vm.prank(owner);
        diamond.createBridge(newBridge2, VAULT, 0, 0);
        bridges = [newBridge1, newBridge2];
        assertEq(diamond.getBridges(VAULT), bridges);
        assertEq(diamond.getBridges(VAULT).length, 2);
        assertEq(diamond.getBridgeVault(newBridge1), VAULT);
        assertEq(diamond.getBridgeVault(newBridge2), VAULT);
        assertEq(diamond.getBridgeVault(newBridge3), 0);

        vm.prank(owner);
        diamond.createBridge(newBridge3, VAULT, 0, 0);
        bridges = [newBridge1, newBridge2, newBridge3];
        assertEq(diamond.getBridges(VAULT), bridges);
        assertEq(diamond.getBridges(VAULT).length, 3);
        assertEq(diamond.getBridgeVault(newBridge1), VAULT);
        assertEq(diamond.getBridgeVault(newBridge2), VAULT);
        assertEq(diamond.getBridgeVault(newBridge3), VAULT);

        vm.prank(owner);
        diamond.deleteBridge(newBridge1);
        bridges = [newBridge3, newBridge2];
        assertEq(diamond.getBridges(VAULT), bridges);
        assertEq(diamond.getBridges(VAULT).length, 2);
        assertEq(diamond.getBridgeVault(newBridge1), 0);
        assertEq(diamond.getBridgeVault(newBridge2), VAULT);
        assertEq(diamond.getBridgeVault(newBridge2), VAULT);

        vm.prank(owner);
        diamond.deleteBridge(newBridge2);
        bridges = [newBridge3];
        assertEq(diamond.getBridges(VAULT), bridges);
        assertEq(diamond.getBridges(VAULT).length, 1);
        assertEq(diamond.getBridgeVault(newBridge1), 0);
        assertEq(diamond.getBridgeVault(newBridge2), 0);
        assertEq(diamond.getBridgeVault(newBridge3), VAULT);

        vm.prank(owner);
        diamond.deleteBridge(newBridge3);
        assertEq(diamond.getBridges(VAULT).length, 0);
        assertEq(diamond.getBridgeVault(newBridge1), 0);
        assertEq(diamond.getBridgeVault(newBridge2), 0);
        assertEq(diamond.getBridgeVault(newBridge3), 0);
    }

    function testRevert_NotOwnerCreateMarket() public {
        STypes.Asset memory a;

        vm.expectRevert("LibDiamond: Must be contract owner");
        diamond.createMarket(asset, a);
    }

    function test_CreateMarket() public {
        STypes.Asset memory a;
        a.vault = uint8(Vault.CARBON);
        a.oracle = _ethAggregator;
        a.initialMargin = 400;
        a.primaryLiquidationCR = 300;
        a.secondaryLiquidationCR = 200;
        a.forcedBidPriceBuffer = 120;
        a.resetLiquidationTime = 1400;
        a.secondLiquidationTime = 1000;
        a.firstLiquidationTime = 800;
        a.minimumCR = 110;
        a.tappFeePct = 25;
        a.callerFeePct = 5;
        a.minBidEth = 1;
        a.minAskEth = 1;
        a.minShortErc = 2000;
        Asset temp = new Asset(_diamond, "Temp", "TEMP");

        assertEq(diamond.getAssets().length, 1);
        assertEq(diamond.getAssetNormalizedStruct(asset).assetId, 0);
        assertEq(diamond.getAssetsMapping(0), _cusd);
        vm.prank(owner);
        diamond.createMarket({asset: address(temp), a: a});
        assertEq(diamond.getAssets().length, 2);
        assertEq(diamond.getAssetNormalizedStruct(address(temp)).assetId, 1);
        assertEq(diamond.getAssetsMapping(1), address(temp));
    }

    function testRevert_CreateDuplicateMarket() public {
        STypes.Asset memory a;

        vm.prank(owner);
        vm.expectRevert(Errors.MarketAlreadyCreated.selector);

        diamond.createMarket(asset, a);
    }

    function testRevert_CreateVaultAlreadyExists() public {
        MTypes.CreateVaultParams memory vaultParams;

        vm.prank(owner);
        vm.expectRevert(Errors.VaultAlreadyCreated.selector);
        diamond.createVault(_zeth, Vault.CARBON, vaultParams);
    }

    function testRevert_NotContractOwner() public {
        MTypes.CreateVaultParams memory vaultParams;
        vm.expectRevert("LibDiamond: Must be contract owner");
        diamond.createVault(_zeth, Vault.CARBON, vaultParams);
    }
}
