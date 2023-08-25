// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256} from "contracts/libraries/PRBMathHelper.sol";
import {Test} from "forge-std/Test.sol";

import {MTypes, STypes} from "contracts/libraries/DataTypes.sol";
import {Constants, Vault} from "contracts/libraries/Constants.sol";
import {Diamond} from "contracts/Diamond.sol";
import {IDiamondCut} from "contracts/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "contracts/interfaces/IDiamondLoupe.sol";

import {IDiamond} from "interfaces/IDiamond.sol";
import {ITestFacet} from "interfaces/ITestFacet.sol";

import {IBridge} from "contracts/interfaces/IBridge.sol";
import {IAsset} from "interfaces/IAsset.sol";

import {IMockAggregatorV3} from "interfaces/IMockAggregatorV3.sol";
import {ISTETH} from "interfaces/ISTETH.sol";
import {IRocketStorage} from "interfaces/IRocketStorage.sol";
import {IRocketTokenRETH} from "interfaces/IRocketTokenRETH.sol";
import {IUNSTETH} from "interfaces/IUNSTETH.sol";
import {Multicall3} from "deploy/MultiCall3.sol";

// import {console} from "contracts/libraries/console.sol";

interface IImmutableCreate2Factory {
    function safeCreate2(bytes32 salt, bytes memory contractCreationCode)
        external
        returns (address);
}

interface IDittoTimelockController {
    function schedule(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) external;

    function execute(
        address target,
        uint256 value,
        bytes calldata payload,
        bytes32 predecessor,
        bytes32 salt
    ) external;

    function grantRole(bytes32 role, address account) external;

    function renounceRole(bytes32 role, address account) external;

    function hasRole(bytes32 role, address account) external view returns (bool);

    function getMinDelay() external view returns (uint256);
}

/* solhint-disable max-states-count */
contract DeployHelper is Test {
    using U256 for uint256;

    IImmutableCreate2Factory public factory;
    address public _immutableCreate2Factory;

    bytes32 public constant TIMELOCK_ADMIN_ROLE = keccak256("TIMELOCK_ADMIN_ROLE");
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");

    IDiamond public diamond;
    address public _diamond;
    address public _diamondLoupe;
    address public _diamondCut;

    address public _askOrders;
    address public _bidOrders;
    address public _bridgeRouter;
    address public _exitShort;
    address public _marginCallPrimary;
    address public _marginCallSecondary;
    address public _marketShutdown;
    address public _orders;
    address public _ownerFacet;
    address public _shortOrders;
    address public _shortRecord;
    address public _testFacet;
    address public _twapFacet;
    address public _vaultFacet;
    address public _viewFacet;
    address public _yield;
    address public _erc721;

    ITestFacet public testFacet;

    bytes4[] internal loupeSelectors;
    bytes4[] internal askOrdersSelectors;
    bytes4[] internal bidOrdersSelectors;
    bytes4[] internal bridgeRouterSelectors;
    bytes4[] internal exitShortSelectors;
    bytes4[] internal marginCallPrimarySelectors;
    bytes4[] internal marginCallSecondarySelectors;
    bytes4[] internal marketShutdownSelectors;
    bytes4[] internal ordersSelectors;
    bytes4[] internal ownerSelectors;
    bytes4[] internal shortOrdersSelectors;
    bytes4[] internal shortRecordSelectors;
    bytes4[] internal testSelectors;
    bytes4[] internal twapSelectors;
    bytes4[] internal vaultFacetSelectors;
    bytes4[] internal viewSelectors;
    bytes4[] internal yieldSelectors;
    bytes4[] internal erc721Selectors;

    IBridge public bridgeSteth;
    address public _bridgeSteth;
    IBridge public bridgeReth;
    address public _bridgeReth;

    IAsset public zeth;
    address public _zeth;
    IAsset public cusd;
    address public _cusd;
    IAsset public ditto;
    address public _ditto;
    IDittoTimelockController public dittoTimelockController;
    address public _dittoTimelockController;
    address public _dittoGovernor;

    //mocks
    address public _multicall3;
    ISTETH public steth;
    address public _steth;
    IUNSTETH public unsteth;
    address public _unsteth;
    IMockAggregatorV3 public ethAggregator;
    address public _ethAggregator;
    IRocketStorage public rocketStorage;
    address public _rocketStorage;
    IRocketTokenRETH public reth;
    address public _reth;

    function getSelector(string memory _func) internal pure returns (bytes4) {
        return bytes4(keccak256(bytes(_func)));
    }

    function deployContracts(address _owner, uint256 chainId) internal {
        if (chainId == 31337) {
            //mocks
            _immutableCreate2Factory = deployCode("ImmutableCreate2Factory.sol");

            _steth = deployCode("STETH.sol");
            steth = ISTETH(_steth);
            _unsteth = deployCode("UNSTETH.sol", abi.encode(_steth));
            unsteth = IUNSTETH(payable(_unsteth));
            _rocketStorage = deployCode("RocketStorage.sol");
            rocketStorage = IRocketStorage(_rocketStorage);
            _reth = deployCode("RocketTokenRETH.sol");
            reth = IRocketTokenRETH(_reth);
            rocketStorage.setDeposit(_reth);
            rocketStorage.setReth(_reth);

            _ethAggregator = deployCode("MockAggregatorV3.sol");
            ethAggregator = IMockAggregatorV3(_ethAggregator);
        } else if (chainId == 1) {
            // create2factory on mainnet = 0x0000000000FFe8B47B3e2130213B802212439497
            // hardcode rocket storage address & oracles
        }
        loupeSelectors = [
            IDiamond.facets.selector,
            IDiamond.facetFunctionSelectors.selector,
            IDiamond.facetAddresses.selector,
            IDiamond.facetAddress.selector
        ];
        askOrdersSelectors = [IDiamond.createAsk.selector];
        bidOrdersSelectors = [
            IDiamond.createBid.selector,
            IDiamond.createForcedBid.selector // remove
        ];
        bridgeRouterSelectors = [
            IDiamond.getZethTotal.selector,
            IDiamond.getBridges.selector,
            IDiamond.deposit.selector,
            IDiamond.depositEth.selector,
            IDiamond.withdraw.selector,
            IDiamond.withdrawTapp.selector,
            IDiamond.unstakeEth.selector
        ];
        exitShortSelectors = [
            IDiamond.exitShortWallet.selector,
            IDiamond.exitShortErcEscrowed.selector,
            IDiamond.exitShort.selector
        ];
        marginCallPrimarySelectors =
            [IDiamond.flagShort.selector, IDiamond.liquidate.selector];
        marginCallSecondarySelectors = [IDiamond.liquidateSecondary.selector];
        marketShutdownSelectors =
            [IDiamond.shutdownMarket.selector, IDiamond.redeemErc.selector];
        ordersSelectors = [
            IDiamond.cancelAsk.selector,
            IDiamond.cancelBid.selector,
            IDiamond.cancelShort.selector,
            IDiamond.cancelOrderFarFromOracle.selector
        ];
        ownerSelectors = [
            IDiamond.transferOwnership.selector,
            IDiamond.claimOwnership.selector,
            IDiamond.owner.selector,
            IDiamond.ownerCandidate.selector,
            IDiamond.setOracle.selector,
            IDiamond.setTithe.selector,
            IDiamond.setDittoMatchedRate.selector,
            IDiamond.setDittoShorterRate.selector,
            IDiamond.setInitialMargin.selector,
            IDiamond.setPrimaryLiquidationCR.selector,
            IDiamond.setSecondaryLiquidationCR.selector,
            IDiamond.setForcedBidPriceBuffer.selector,
            IDiamond.setResetLiquidationTime.selector,
            IDiamond.setSecondLiquidationTime.selector,
            IDiamond.setFirstLiquidationTime.selector,
            IDiamond.setMinimumCR.selector,
            IDiamond.setTappFeePct.selector,
            IDiamond.setCallerFeePct.selector,
            IDiamond.setMinBidEth.selector,
            IDiamond.setMinAskEth.selector,
            IDiamond.setMinShortErc.selector,
            IDiamond.createBridge.selector,
            IDiamond.deleteBridge.selector,
            IDiamond.setAssetOracle.selector,
            IDiamond.createVault.selector,
            IDiamond.createMarket.selector,
            IDiamond.setWithdrawalFee.selector,
            IDiamond.setUnstakeFee.selector
        ];
        shortOrdersSelectors = [IDiamond.createLimitShort.selector];
        shortRecordSelectors = [
            IDiamond.increaseCollateral.selector,
            IDiamond.decreaseCollateral.selector,
            IDiamond.combineShorts.selector
        ];
        testSelectors = [
            ITestFacet.setprimaryLiquidationCRT.selector,
            ITestFacet.getAskKey.selector,
            ITestFacet.getBidKey.selector,
            ITestFacet.getBidOrder.selector,
            ITestFacet.getAskOrder.selector,
            ITestFacet.getShortOrder.selector,
            ITestFacet.currentInactiveBids.selector,
            ITestFacet.currentInactiveAsks.selector,
            ITestFacet.currentInactiveShorts.selector,
            ITestFacet.setReentrantStatus.selector,
            ITestFacet.getReentrantStatus.selector,
            ITestFacet.setOracleTimeAndPrice.selector,
            ITestFacet.getOracleTimeT.selector,
            ITestFacet.getOraclePriceT.selector,
            ITestFacet.setStartingShortId.selector,
            ITestFacet.nonZeroVaultSlot0.selector,
            ITestFacet.setforcedBidPriceBufferT.selector,
            ITestFacet.setErcDebtRate.selector,
            ITestFacet.setOrderIdT.selector,
            ITestFacet.getAssetNormalizedStruct.selector,
            ITestFacet.getBridgeNormalizedStruct.selector,
            ITestFacet.setEthEscrowed.selector,
            ITestFacet.setErcEscrowed.selector,
            ITestFacet.getUserOrders.selector,
            ITestFacet.setFrozen.selector,
            ITestFacet.getAssets.selector,
            ITestFacet.getAssetsMapping.selector,
            ITestFacet.setTokenId.selector,
            ITestFacet.getTokenId.selector,
            ITestFacet.getNFT.selector,
            ITestFacet.getNFTName.selector,
            ITestFacet.getNFTSymbol.selector,
            ITestFacet.setFlaggerIdCounter.selector,
            ITestFacet.getFlaggerIdCounter.selector,
            ITestFacet.getFlagger.selector,
            ITestFacet.getZethYieldRate.selector
        ];
        twapSelectors = [IDiamond.estimateWETHInUSDC.selector];
        vaultFacetSelectors = [
            IDiamond.depositAsset.selector,
            IDiamond.depositZETH.selector,
            IDiamond.withdrawAsset.selector,
            IDiamond.withdrawZETH.selector
        ];
        viewSelectors = [
            IDiamond.getZethBalance.selector,
            IDiamond.getAssetBalance.selector,
            IDiamond.getVault.selector,
            IDiamond.getBridgeVault.selector,
            IDiamond.getBids.selector,
            IDiamond.getBidHintId.selector,
            IDiamond.getAsks.selector,
            IDiamond.getAskHintId.selector,
            IDiamond.getShorts.selector,
            IDiamond.getShortHintId.selector,
            IDiamond.getShortIdAtOracle.selector,
            IDiamond.getHintArray.selector,
            IDiamond.getCollateralRatio.selector,
            IDiamond.getAssetPrice.selector,
            IDiamond.getProtocolAssetPrice.selector,
            IDiamond.getTithe.selector,
            IDiamond.getUndistributedYield.selector,
            IDiamond.getYield.selector,
            IDiamond.getDittoMatchedReward.selector,
            IDiamond.getDittoReward.selector,
            IDiamond.getAssetCollateralRatio.selector,
            IDiamond.getShortRecord.selector,
            IDiamond.getShortRecords.selector,
            IDiamond.getShortRecordCount.selector,
            IDiamond.getAssetUserStruct.selector,
            IDiamond.getVaultUserStruct.selector,
            IDiamond.getVaultStruct.selector,
            IDiamond.getAssetStruct.selector,
            IDiamond.getBridgeStruct.selector,
            IDiamond.getBaseOracle.selector,
            IDiamond.getOffsetTime.selector,
            IDiamond.getOffsetTimeHours.selector,
            IDiamond.getFlaggerId.selector
        ];
        yieldSelectors = [
            IDiamond.updateYield.selector,
            IDiamond.distributeYield.selector,
            IDiamond.claimDittoMatchedReward.selector,
            IDiamond.withdrawDittoReward.selector
        ];
        erc721Selectors = [
            IDiamond.balanceOf.selector,
            IDiamond.ownerOf.selector,
            getSelector("safeTransferFrom(address,address,uint256)"), // 0x42842e0e
            getSelector("safeTransferFrom(address,address,uint256,bytes)"), // 0xb88d4fde
            IDiamond.transferFrom.selector,
            IDiamond.isApprovedForAll.selector,
            IDiamond.approve.selector,
            IDiamond.setApprovalForAll.selector,
            IDiamond.getApproved.selector,
            IDiamond.mintNFT.selector,
            IDiamond.supportsInterface.selector
        ];

        factory = IImmutableCreate2Factory(_immutableCreate2Factory);
        //should this be a ENV var?
        bytes32 salt = bytes32(0);

        _diamondCut = factory.safeCreate2(
            salt, abi.encodePacked(vm.getCode("DiamondCutFacet.sol:DiamondCutFacet"))
        );
        _diamond = factory.safeCreate2(
            salt,
            abi.encodePacked(type(Diamond).creationCode, abi.encode(_owner, _diamondCut))
        );

        //Tokens
        _zeth = factory.safeCreate2(
            salt,
            abi.encodePacked(
                vm.getCode("Asset.sol:Asset"), abi.encode(_diamond, "Zebra ETH", "ZETH")
            )
        );
        _ditto = factory.safeCreate2(
            salt, abi.encodePacked(vm.getCode("Ditto.sol:Ditto"), abi.encode(_diamond))
        );
        address[] memory proposers = new address[](1);
        proposers[0] = _owner;
        address[] memory executors = new address[](1);
        executors[0] = _owner;

        _dittoTimelockController = factory.safeCreate2(
            salt,
            abi.encodePacked(
                vm.getCode("DittoTimelockController.sol:DittoTimelockController"),
                abi.encode(proposers, executors, _owner)
            )
        );
        _dittoGovernor = factory.safeCreate2(
            salt,
            abi.encodePacked(
                vm.getCode("DittoGovernor.sol:DittoGovernor"),
                abi.encode(_ditto, _dittoTimelockController)
            )
        );
        _cusd = factory.safeCreate2(
            salt,
            abi.encodePacked(
                vm.getCode("Asset.sol:Asset"), abi.encode(_diamond, "Carbon USD", "CUSD")
            )
        );

        //Bridges
        _bridgeReth = factory.safeCreate2(
            salt,
            abi.encodePacked(
                vm.getCode("BridgeReth.sol:BridgeReth"),
                abi.encode(_rocketStorage, _diamond)
            )
        );
        _bridgeSteth = factory.safeCreate2(
            salt,
            abi.encodePacked(
                vm.getCode("BridgeSteth.sol:BridgeSteth"),
                abi.encode(_steth, _unsteth, _diamond)
            )
        );

        //Facets
        _diamondLoupe = factory.safeCreate2(
            salt, abi.encodePacked(vm.getCode("DiamondLoupeFacet.sol:DiamondLoupeFacet"))
        );
        _ownerFacet = factory.safeCreate2(
            salt, abi.encodePacked(vm.getCode("OwnerFacet.sol:OwnerFacet"))
        );
        _viewFacet = factory.safeCreate2(
            salt, abi.encodePacked(vm.getCode("ViewFacet.sol:ViewFacet"))
        );
        _yield = factory.safeCreate2(
            salt,
            abi.encodePacked(
                vm.getCode("YieldFacet.sol:YieldFacet"), abi.encode(_ditto, _zeth)
            )
        );
        _vaultFacet = factory.safeCreate2(
            salt,
            abi.encodePacked(vm.getCode("VaultFacet.sol:VaultFacet"), abi.encode(_zeth))
        );
        _bridgeRouter = factory.safeCreate2(
            salt,
            abi.encodePacked(
                vm.getCode("BridgeRouterFacet.sol:BridgeRouterFacet"),
                abi.encode(_bridgeReth, _bridgeSteth)
            )
        );
        _shortRecord = factory.safeCreate2(
            salt,
            abi.encodePacked(
                vm.getCode("ShortRecordFacet.sol:ShortRecordFacet"), abi.encode(_cusd)
            )
        );
        _askOrders = factory.safeCreate2(
            salt, abi.encodePacked(vm.getCode("AskOrdersFacet.sol:AskOrdersFacet"))
        );
        _shortOrders = factory.safeCreate2(
            salt, abi.encodePacked(vm.getCode("ShortOrdersFacet.sol:ShortOrdersFacet"))
        );
        _bidOrders = factory.safeCreate2(
            salt, abi.encodePacked(vm.getCode("BidOrdersFacet.sol:BidOrdersFacet"))
        );
        _orders = factory.safeCreate2(
            salt, abi.encodePacked(vm.getCode("OrdersFacet.sol:OrdersFacet"))
        );
        _exitShort = factory.safeCreate2(
            salt,
            abi.encodePacked(
                vm.getCode("ExitShortFacet.sol:ExitShortFacet"), abi.encode(_cusd)
            )
        );
        _marginCallPrimary = factory.safeCreate2(
            salt,
            abi.encodePacked(
                vm.getCode("MarginCallPrimaryFacet.sol:MarginCallPrimaryFacet"),
                abi.encode(_cusd)
            )
        );
        _marginCallSecondary = factory.safeCreate2(
            salt,
            abi.encodePacked(
                vm.getCode("MarginCallSecondaryFacet.sol:MarginCallSecondaryFacet")
            )
        );
        _marketShutdown = factory.safeCreate2(
            salt,
            abi.encodePacked(vm.getCode("MarketShutdownFacet.sol:MarketShutdownFacet"))
        );

        _twapFacet = factory.safeCreate2(
            salt, abi.encodePacked(vm.getCode("TWAPFacet.sol:TWAPFacet"))
        );

        _erc721 = factory.safeCreate2(
            salt, abi.encodePacked(vm.getCode("ERC721Facet.sol:ERC721Facet"))
        );

        IDiamondCut.FacetCut[] memory cut;
        if (chainId == 31337) {
            _testFacet = factory.safeCreate2(
                salt,
                abi.encodePacked(vm.getCode("TestFacet.sol:TestFacet"), abi.encode(_cusd))
            );

            cut = new IDiamondCut.FacetCut[](18);
            cut[17] = (
                IDiamondCut.FacetCut({
                    facetAddress: _testFacet,
                    action: IDiamondCut.FacetCutAction.Add,
                    functionSelectors: testSelectors
                })
            );
        } else if (chainId == 1) {
            cut = new IDiamondCut.FacetCut[](16);
        }
        cut[0] = (
            IDiamondCut.FacetCut({
                facetAddress: _diamondLoupe,
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: loupeSelectors
            })
        );

        cut[1] = (
            IDiamondCut.FacetCut({
                facetAddress: _shortRecord,
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: shortRecordSelectors
            })
        );

        cut[2] = (
            IDiamondCut.FacetCut({
                facetAddress: _vaultFacet,
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: vaultFacetSelectors
            })
        );

        cut[3] = (
            IDiamondCut.FacetCut({
                facetAddress: _bridgeRouter,
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: bridgeRouterSelectors
            })
        );

        cut[4] = (
            IDiamondCut.FacetCut({
                facetAddress: _bidOrders,
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: bidOrdersSelectors
            })
        );

        cut[5] = (
            IDiamondCut.FacetCut({
                facetAddress: _askOrders,
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: askOrdersSelectors
            })
        );

        cut[6] = (
            IDiamondCut.FacetCut({
                facetAddress: _shortOrders,
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: shortOrdersSelectors
            })
        );

        cut[7] = (
            IDiamondCut.FacetCut({
                facetAddress: _exitShort,
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: exitShortSelectors
            })
        );

        cut[8] = (
            IDiamondCut.FacetCut({
                facetAddress: _marginCallPrimary,
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: marginCallPrimarySelectors
            })
        );

        cut[9] = (
            IDiamondCut.FacetCut({
                facetAddress: _marginCallSecondary,
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: marginCallSecondarySelectors
            })
        );

        cut[10] = (
            IDiamondCut.FacetCut({
                facetAddress: _ownerFacet,
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: ownerSelectors
            })
        );

        cut[11] = (
            IDiamondCut.FacetCut({
                facetAddress: _yield,
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: yieldSelectors
            })
        );

        cut[12] = (
            IDiamondCut.FacetCut({
                facetAddress: _viewFacet,
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: viewSelectors
            })
        );

        cut[13] = (
            IDiamondCut.FacetCut({
                facetAddress: _orders,
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: ordersSelectors
            })
        );

        cut[14] = (
            IDiamondCut.FacetCut({
                facetAddress: _marketShutdown,
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: marketShutdownSelectors
            })
        );

        cut[15] = (
            IDiamondCut.FacetCut({
                facetAddress: _twapFacet,
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: twapSelectors
            })
        );

        cut[16] = (
            IDiamondCut.FacetCut({
                facetAddress: _erc721,
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: erc721Selectors
            })
        );

        assertNotEq(_zeth, address(0));
        assertNotEq(_cusd, address(0));
        assertNotEq(_ditto, address(0));
        assertNotEq(_dittoTimelockController, address(0));
        assertNotEq(_dittoGovernor, address(0));
        assertNotEq(_bridgeReth, address(0));
        assertNotEq(_bridgeSteth, address(0));
        assertNotEq(_diamond, address(0));
        diamond = IDiamond(payable(_diamond));
        diamond.diamondCut(cut, address(0x0), "");

        IDiamondLoupe.Facet[] memory facets = diamond.facets();
        // @dev first facet is DiamondCutFacet
        assertEq(facets.length, cut.length + 1);
        for (uint256 i = 0; i < facets.length - 1; i++) {
            assertNotEq(facets[i].facetAddress, address(0));
            assertEq(
                facets[i + 1].functionSelectors.length, cut[i].functionSelectors.length
            );
            for (uint256 y = 0; y < facets[i + 1].functionSelectors.length; y++) {
                assertEq(facets[i + 1].functionSelectors[y], cut[i].functionSelectors[y]);
            }
        }

        if (chainId == 31337) {
            _multicall3 =
                factory.safeCreate2(salt, abi.encodePacked(type(Multicall3).creationCode));

            testFacet = ITestFacet(_diamond);

            zeth = IAsset(_zeth);
            cusd = IAsset(_cusd);
            ditto = IAsset(_ditto);
            dittoTimelockController =
                IDittoTimelockController(payable(_dittoTimelockController));

            bridgeReth = IBridge(_bridgeReth);
            bridgeSteth = IBridge(_bridgeSteth);

            MTypes.CreateVaultParams memory vaultParams;
            vaultParams.zethTithePercent = 10_00;
            vaultParams.dittoMatchedRate = 1;
            vaultParams.dittoShorterRate = 1;
            diamond.createVault({zeth: _zeth, vault: Vault.CARBON, params: vaultParams});

            STypes.Vault memory carbonVaultConfig = diamond.getVaultStruct(Vault.CARBON);
            assertEq(carbonVaultConfig.zethTithePercent, 10_00);
            assertEq(carbonVaultConfig.dittoMatchedRate, 1);
            assertEq(carbonVaultConfig.dittoShorterRate, 1);

            diamond.createBridge({
                bridge: _bridgeReth,
                vault: Vault.CARBON,
                withdrawalFee: 50,
                unstakeFee: 0
            }); // 0.5%
            diamond.createBridge({
                bridge: _bridgeSteth,
                vault: Vault.CARBON,
                withdrawalFee: 0,
                unstakeFee: 0
            });

            STypes.Bridge memory bridgeRethConfig = diamond.getBridgeStruct(_bridgeReth);
            STypes.Bridge memory bridgeStethConfig = diamond.getBridgeStruct(_bridgeSteth);
            assertEq(bridgeRethConfig.withdrawalFee, 50);
            assertEq(bridgeRethConfig.unstakeFee, 0);

            assertEq(bridgeStethConfig.withdrawalFee, 0);
            assertEq(bridgeStethConfig.unstakeFee, 0);

            diamond.setOracle(_ethAggregator);
            assertEq(diamond.getBaseOracle(), _ethAggregator);
            _setETH(4000 ether);

            STypes.Asset memory a;
            a.vault = uint8(Vault.CARBON);
            a.oracle = _ethAggregator;
            a.initialMargin = 500; // 500 -> 5 ether
            a.primaryLiquidationCR = 400; // 400 -> 4 ether
            a.secondaryLiquidationCR = 150; // 150 -> 1.5 ether
            a.forcedBidPriceBuffer = 110; // 110 -> 1.1 ether
            a.resetLiquidationTime = 1600; // 1600 -> 16 hours
            a.secondLiquidationTime = 1200; // 1200 -> 12 hours
            a.firstLiquidationTime = 1000; // 1000 -> 10 hours
            a.minimumCR = 110; // 110 -> 1.1 ether
            a.tappFeePct = 25; //25 -> .025 ether
            a.callerFeePct = 5; //5 -> .005 ether
            a.minBidEth = 1; //1 -> 0.001 ether
            a.minAskEth = 1; //1 -> 0.001 ether
            a.minShortErc = 2000; //1 -> 0.001 ether
            diamond.createMarket({asset: _cusd, a: a});

            STypes.Asset memory cusdConfig = diamond.getAssetStruct(_cusd);
            assertEq(a.initialMargin, cusdConfig.initialMargin);
            assertEq(a.minBidEth, cusdConfig.minBidEth);
            assertEq(a.minAskEth, cusdConfig.minAskEth);
            assertEq(a.minShortErc, cusdConfig.minShortErc);
            assertEq(a.oracle, cusdConfig.oracle);
            assertEq(Vault.CARBON, cusdConfig.vault);
            assertEq(a.resetLiquidationTime, cusdConfig.resetLiquidationTime);
            assertEq(a.secondLiquidationTime, cusdConfig.secondLiquidationTime);
            assertEq(a.firstLiquidationTime, cusdConfig.firstLiquidationTime);
            assertEq(a.primaryLiquidationCR, cusdConfig.primaryLiquidationCR);
            assertEq(a.secondaryLiquidationCR, cusdConfig.secondaryLiquidationCR);
            assertEq(a.minimumCR, cusdConfig.minimumCR);
            assertEq(a.forcedBidPriceBuffer, cusdConfig.forcedBidPriceBuffer);
            assertEq(a.tappFeePct, cusdConfig.tappFeePct);
            assertEq(a.callerFeePct, cusdConfig.callerFeePct);

            dittoTimelockController.grantRole(PROPOSER_ROLE, _dittoGovernor);
            dittoTimelockController.grantRole(CANCELLER_ROLE, _dittoGovernor);
            dittoTimelockController.grantRole(EXECUTOR_ROLE, _dittoGovernor);

            // dittoTimelockController.renounceRole(TIMELOCK_ADMIN_ROLE, _owner);

            // bytes memory payload = abi.encodeWithSignature("updateDelay(uint256)", 172800);

            // dittoTimelockController.schedule(
            //     _dittoTimelockController, 0, payload, bytes32(0), bytes32(0), 0
            // );

            // dittoTimelockController.execute(
            //     _dittoTimelockController, 0, payload, bytes32(0), bytes32(0)
            // );
        }
    }

    function _setETH(int256 amount) public {
        ethAggregator = IMockAggregatorV3(_ethAggregator);

        ethAggregator.setRoundData(
            92233720368547778907 wei,
            amount / Constants.BASE_ORACLE_DECIMALS,
            block.timestamp,
            block.timestamp,
            92233720368547778907 wei
        );

        if (amount != 0) {
            uint256 assetPrice = (uint256(amount)).inv();
            // also set asset price
            testFacet.setOracleTimeAndPrice(_cusd, assetPrice);
        }
    }
}
