// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U80, U88} from "contracts/libraries/PRBMathHelper.sol";
import {AddressSet, LibAddressSet} from "test/utils/AddressSet.sol";
import {Constants} from "contracts/libraries/Constants.sol";
import {STypes, SR, MTypes, O} from "contracts/libraries/DataTypes.sol";

import {IAsset} from "interfaces/IAsset.sol";
import {IOBFixture} from "interfaces/IOBFixture.sol";
import {IDiamond} from "interfaces/IDiamond.sol";
import {IMockAggregatorV3} from "interfaces/IMockAggregatorV3.sol";

import {Vault} from "contracts/libraries/Constants.sol";
import {console} from "contracts/libraries/console.sol";
import {ConstantsTest} from "test/utils/ConstantsTest.sol";

/// @dev The handler is the set of valid actions that can be performed during an invariant test run.
/* solhint-disable no-console */
contract Handler is ConstantsTest {
    using U256 for uint256;
    using U80 for uint80;
    using U88 for uint88;
    using LibAddressSet for AddressSet;

    IOBFixture public s_ob;
    IMockAggregatorV3 public ethAggregator;
    address public _ethAggregator;
    address public asset;
    address public zeth;
    uint256 public vault;
    address public _diamond;
    IDiamond public diamond;
    address public _reth;
    IAsset public reth;
    address public _bridgeReth;
    address public _steth;
    IAsset public steth;
    address public _bridgeSteth;

    // GHOST VARIABLES
    address internal currentUser;
    address internal currentShorter;
    address internal currentNFTOwner;
    AddressSet internal s_Users;
    AddressSet internal s_Shorters;
    AddressSet internal s_NFTOwners;
    uint16 public ghost_orderId;
    uint88 public ghost_ethEscrowed;
    uint104 public ghost_ercEscrowed;
    uint256 public ghost_oracleTime;
    uint256 public ghost_oraclePrice;
    uint80 public ghost_zethYieldRate;
    uint88 public ghost_zethCollateralReward;
    uint40 public ghost_tokenIdCounter;
    // GHOST VARIABLES - Counters
    uint256 public ghost_exitShort;
    uint256 public ghost_primaryMC;
    uint256 public ghost_secondaryMC;

    uint256 public ghost_exitShortSRGtZeroCounter;
    uint256 public ghost_exitShortComplete;
    uint256 public ghost_secondaryMCSRGtZeroCounter;
    uint256 public ghost_secondaryMCComplete;
    uint256 public ghost_primaryMCSRGtZeroCounter;
    uint256 public ghost_primaryMCComplete;

    uint256 public ghost_exitShortCancelledShortCounter;
    uint256 public ghost_secondaryMCSameUserCounter;
    uint256 public ghost_secondaryMCCancelledShortCounter;
    uint256 public ghost_primaryMCSameUserCounter;
    uint256 public ghost_primaryMCCancelledShortCounter;

    uint256 public ghost_denominator;
    uint256 public ghost_numerator;

    // OUTPUT VARS - used to print a summary of calls and reverts during certain actions
    // uint256 internal s_swapToCalls;
    // uint256 internal s_swapToFails;

    constructor(IOBFixture ob) {
        s_ob = ob;
        _diamond = ob.contracts("diamond");
        diamond = IDiamond(payable(_diamond));
        asset = ob.contracts("cusd");
        zeth = ob.contracts("zeth");
        _ethAggregator = ob.contracts("ethAggregator");
        ethAggregator = IMockAggregatorV3(_ethAggregator);
        _steth = ob.contracts("steth");
        steth = IAsset(_steth);
        _reth = ob.contracts("reth");
        reth = IAsset(_reth);
        _bridgeReth = ob.contracts("bridgeReth");
        _bridgeSteth = ob.contracts("bridgeSteth");
        vault = Vault.CARBON;

        // skip(Constants.STARTING_TIME - 1);
    }

    //MODIFIERS
    modifier advanceTime() {
        ghost_oracleTime = block.timestamp;
        //@dev 12 seconds to replicate how often a block gets added on average
        vm.warp(block.timestamp + 12 seconds);
        vm.roll(block.number + 1);
        _;
    }

    //@dev change price by +/- .5% randomly
    modifier advancePrice(uint8 addressSeed) {
        uint256 currentOraclePrice = diamond.getOraclePriceT(asset);
        uint256 newOraclePrice;
        if (addressSeed % 3 == 0) {
            newOraclePrice = currentOraclePrice;
        } else if (addressSeed % 2 == 0) {
            newOraclePrice = currentOraclePrice.mul(1.005 ether);
        } else {
            newOraclePrice = currentOraclePrice.mul(0.995 ether);
        }
        int256 newOraclePriceInv = int256(newOraclePrice.inv());
        //@dev Don't change saved oracle data, just chainlink!
        ethAggregator.setRoundData(
            92233720368547778907 wei,
            newOraclePriceInv / Constants.BASE_ORACLE_DECIMALS,
            block.timestamp,
            block.timestamp,
            92233720368547778907 wei
        );
        _;
    }

    modifier useExistingUser(uint8 userSeed) {
        currentUser = s_Users.rand(userSeed);
        _;
    }

    modifier useExistingShorter(uint8 userSeed) {
        currentUser = s_Shorters.rand(userSeed);
        _;
    }

    modifier useExistingNFTOwner(uint8 userSeed) {
        currentNFTOwner = s_NFTOwners.rand(userSeed);
        _;
    }

    //HELPERS

    function _seedToAddress(uint8 addressSeed) internal pure returns (address) {
        return address(uint160(_bound(addressSeed, 2, type(uint8).max)));
    }

    function boundU16(uint16 x, uint256 min, uint256 max)
        internal
        pure
        returns (uint16)
    {
        return uint16(_bound(uint256(x), uint256(min), uint256(max)));
    }

    function boundU80(uint80 x, uint256 min, uint256 max)
        internal
        pure
        returns (uint80)
    {
        return uint80(_bound(uint256(x), uint256(min), uint256(max)));
    }

    function boundU88(uint88 x, uint256 min, uint256 max)
        internal
        pure
        returns (uint88)
    {
        return uint88(_bound(uint256(x), uint256(min), uint256(max)));
    }

    function boundU104(uint104 x, uint256 min, uint256 max)
        internal
        pure
        returns (uint104)
    {
        return uint104(_bound(uint256(x), uint256(min), uint256(max)));
    }

    function getUsers() public view returns (address[] memory) {
        return s_Users.addrs;
    }

    function getShorters() public view returns (address[] memory) {
        return s_Shorters.addrs;
    }

    function getGhostOrderId() public view returns (uint16) {
        return ghost_orderId;
    }

    function getGhostEthEscrowed() public view returns (uint88) {
        return ghost_ethEscrowed;
    }

    function getGhostErcEscrowed() public view returns (uint104) {
        return ghost_ercEscrowed;
    }

    function getGhostOracleTime() public view returns (uint256) {
        return ghost_oracleTime;
    }

    function getGhostOraclePrice() public view returns (uint256) {
        return ghost_oraclePrice;
    }

    function getGhostZethYieldRate() public view returns (uint256) {
        return ghost_zethYieldRate;
    }

    function getGhostZethCollateralReward() public view returns (uint256) {
        return ghost_zethCollateralReward;
    }

    function getGhostTokenIdCounter() public view returns (uint40) {
        return ghost_tokenIdCounter;
    }

    function initialGhostVarSetUp(address _msgSender) public {
        ghost_orderId = diamond.getAssetNormalizedStruct(asset).orderId;
        ghost_ethEscrowed = diamond.getVaultUserStruct(vault, _msgSender).ethEscrowed;
        ghost_ercEscrowed = diamond.getAssetUserStruct(asset, _msgSender).ercEscrowed;
        ghost_oracleTime = diamond.getOracleTimeT(asset);
        ghost_zethYieldRate = diamond.getVaultStruct(vault).zethYieldRate;
        ghost_zethCollateralReward = diamond.getVaultStruct(vault).zethCollateralReward;
        ghost_tokenIdCounter = diamond.getTokenId();
    }

    function reduceUsers(
        uint256 acc,
        function(uint256,address) external returns (uint256) func
    ) public returns (uint256) {
        return s_Users.reduce(acc, func);
    }

    function reduceShorters(
        uint256 acc,
        function(uint256,address) external returns (uint256) func
    ) public returns (uint256) {
        return s_Shorters.reduce(acc, func);
    }

    function updateShorters() public {
        uint256 length = s_Users.length();
        for (uint256 i; i < length; ++i) {
            address addr = s_Users.addrs[i];
            STypes.ShortRecord[] memory shortRecords =
                diamond.getShortRecords(asset, addr);
            bool isShorter = shortRecords.length > 0 && shortRecords[0].collateral > 0;

            if (isShorter && !s_Shorters.saved[addr]) {
                // Shorter should be in the shorters set
                s_Shorters.add(addr);
            } else if (
                // Shorter should not be in the shorters set
                !isShorter && s_Shorters.saved[addr]
            ) {
                s_Shorters.remove(addr);
            }
        }
    }

    //MAIN INVARIANT FUNCTIONS
    function cancelOrder(uint16 index, uint8 addressSeed)
        public
        advanceTime
        advancePrice(addressSeed)
        useExistingUser(addressSeed)
    {
        initialGhostVarSetUp(currentUser);
        STypes.Order[] memory bids = diamond.getUserOrders(asset, currentUser, O.LimitBid);
        STypes.Order[] memory asks = diamond.getUserOrders(asset, currentUser, O.LimitAsk);
        STypes.Order[] memory shorts =
            diamond.getUserOrders(asset, currentUser, O.LimitShort);

        if (index % 3 == 0 && bids.length > 0) {
            index = boundU16(index, 0, uint16(bids.length - 1));
            console.log(string.concat("vm.prank(", vm.toString(currentUser), ");"));
            console.log(
                string.concat(
                    "diamond.cancelBid(",
                    vm.toString(asset),
                    ",",
                    vm.toString(bids[index].id),
                    ");"
                )
            );
            vm.prank(currentUser);
            diamond.cancelBid(asset, bids[index].id);
            ghost_oraclePrice = diamond.getOraclePriceT(asset);
        } else if (index % 3 == 1 && asks.length > 0) {
            index = boundU16(index, 0, uint16(asks.length - 1));
            console.log(string.concat("vm.prank(", vm.toString(currentUser), ");"));
            console.log(
                string.concat(
                    "diamond.cancelAsk(",
                    vm.toString(asset),
                    ",",
                    vm.toString(asks[index].id),
                    ");"
                )
            );
            vm.prank(currentUser);
            diamond.cancelAsk(asset, asks[index].id);
            ghost_oraclePrice = diamond.getOraclePriceT(asset);
        } else if (index % 3 == 2 && shorts.length > 0) {
            index = boundU16(index, 0, uint16(shorts.length - 1));
            console.log(string.concat("vm.prank(", vm.toString(currentUser), ");"));
            console.log(
                string.concat(
                    "diamond.cancelShort(",
                    vm.toString(asset),
                    ",",
                    vm.toString(shorts[index].id),
                    ");"
                )
            );
            vm.prank(currentUser);
            diamond.cancelShort(asset, shorts[index].id);
            ghost_oraclePrice = diamond.getOraclePriceT(asset);
        } else {
            console.log("cancelorder [skip]");
        }
    }

    function createLimitBid(uint80 price, uint88 amount, uint8 addressSeed)
        public
        advanceTime
        advancePrice(addressSeed)
        useExistingUser(addressSeed)
    {
        // bound inputs
        price = boundU80(price, DEFAULT_PRICE / 2, DEFAULT_PRICE * 2);
        amount = boundU88(amount, DEFAULT_AMOUNT, DEFAULT_AMOUNT * 10);

        uint256 oracleTime = diamond.getOracleTimeT(asset);
        if (block.timestamp > oracleTime + 2 hours) {
            //@dev If the block timestamp is > 2 hours from latest "mock-chainlink", update the chainlink
            s_ob.setETH(4000 ether);
        }

        initialGhostVarSetUp(currentUser);
        console.log(
            string.concat(
                "fundLimitBidOpt(",
                vm.toString(price),
                ",",
                vm.toString(amount),
                ",",
                vm.toString(currentUser),
                ");"
            )
        );

        uint88 ethEscrowed = diamond.getVaultUserStruct(vault, currentUser).ethEscrowed;
        if (ethEscrowed < price.mulU88(amount)) {
            return;
        }

        MTypes.OrderHint[] memory orderHintArray =
            diamond.getHintArray(asset, price, O.LimitBid);
        uint16[] memory shortHintArray = new uint16[](1);
        shortHintArray[0] = diamond.getShortIdAtOracle(asset);

        vm.prank(currentUser);
        diamond.createBid(
            asset, price, amount, Constants.LIMIT_ORDER, orderHintArray, shortHintArray
        );

        ghost_oraclePrice = diamond.getOraclePriceT(asset);
        updateShorters();
    }

    function createLimitAsk(uint80 price, uint88 amount, uint8 addressSeed)
        public
        advanceTime
        advancePrice(addressSeed)
        useExistingUser(addressSeed)
    {
        // bound inputs
        price = boundU80(price, DEFAULT_PRICE / 2, DEFAULT_PRICE * 2);
        amount = boundU88(amount, DEFAULT_AMOUNT, DEFAULT_AMOUNT * 10);

        initialGhostVarSetUp(currentUser);
        console.log(
            string.concat(
                "fundLimitAskOpt(",
                vm.toString(price),
                ",",
                vm.toString(amount),
                ",",
                vm.toString(currentUser),
                ");"
            )
        );

        uint104 ercEscrowed = diamond.getAssetUserStruct(asset, currentUser).ercEscrowed;
        if (ercEscrowed < amount) {
            return;
        }

        MTypes.OrderHint[] memory orderHintArray =
            diamond.getHintArray(asset, price, O.LimitAsk);

        vm.prank(currentUser);
        diamond.createAsk(asset, price, amount, Constants.LIMIT_ORDER, orderHintArray);

        ghost_oraclePrice = diamond.getOraclePriceT(asset);
    }

    function createLimitShort(uint80 price, uint88 amount, uint8 addressSeed)
        public
        advanceTime
        advancePrice(addressSeed)
        useExistingUser(addressSeed)
    {
        // bound inputs
        price = boundU80(price, DEFAULT_PRICE / 2, DEFAULT_PRICE * 2);
        amount = boundU88(amount, DEFAULT_AMOUNT, DEFAULT_AMOUNT * 10);

        uint256 oracleTime = diamond.getOracleTimeT(asset);
        if (block.timestamp > oracleTime + 2 hours) {
            //@dev If the block timestamp is > 2 hours from latest "mock-chainlink", update the chainlink
            s_ob.setETH(4000 ether);
        }

        initialGhostVarSetUp(currentUser);

        uint88 ethEscrowed = diamond.getVaultUserStruct(vault, currentUser).ethEscrowed;

        if (
            ethEscrowed
                <= price.mulU88(amount).mulU88(
                    diamond.getAssetNormalizedStruct(asset).initialMargin
                )
        ) {
            return;
        }

        MTypes.OrderHint[] memory orderHintArray =
            diamond.getHintArray(asset, price, O.LimitShort);
        uint16[] memory shortHintArray = new uint16[](1);
        shortHintArray[0] = diamond.getShortIdAtOracle(asset);

        console.log(string.concat("vm.prank(", vm.toString(currentUser), ");"));
        console.log(
            string.concat(
                "createLimitShort(",
                vm.toString(asset),
                ",",
                vm.toString(price),
                ",",
                vm.toString(amount),
                ",",
                "orderHintArray",
                ",",
                "shortHintArray",
                ",",
                vm.toString(diamond.getAssetStruct(asset).initialMargin),
                ");"
            )
        );

        vm.startPrank(currentUser);
        diamond.createLimitShort(
            asset,
            price,
            amount,
            orderHintArray,
            shortHintArray,
            diamond.getAssetStruct(asset).initialMargin
        );
        vm.stopPrank();

        ghost_oraclePrice = diamond.getOraclePriceT(asset);

        updateShorters();
    }

    function exitShort(uint80 price, uint8 addressSeed)
        public
        advanceTime
        advancePrice(addressSeed)
        useExistingShorter(addressSeed)
    {
        ghost_exitShort++;
        initialGhostVarSetUp(currentUser);
        STypes.ShortRecord[] memory shortRecords =
            diamond.getShortRecords(asset, currentUser);

        if (shortRecords.length > 0) {
            ghost_exitShortSRGtZeroCounter++;
            // TODO: exit more than the starting SR
            if (
                diamond.getShortRecord(asset, currentUser, Constants.SHORT_STARTING_ID)
                    .status == SR.Cancelled
            ) {
                ghost_exitShortCancelledShortCounter++;
                return;
            }

            // bound inputs
            uint88 shortErcDebt = diamond.getShortRecord(
                asset, currentUser, Constants.SHORT_STARTING_ID
            ).ercDebt;

            //@dev sometimes the short collateral will not be enough to exit short bc price will be too high
            price = boundU80(
                price,
                diamond.getOraclePriceT(asset).div(1.1 ether),
                diamond.getOraclePriceT(asset).mul(1.1 ether)
            );

            console.log(
                string.concat(
                    "fundLimitAskOpt(",
                    vm.toString(price),
                    ",",
                    vm.toString(shortErcDebt),
                    ",",
                    vm.toString(currentUser),
                    ");"
                )
            );
            //@dev create ask for exit short
            s_ob.fundLimitAskOpt(price, shortErcDebt, currentUser);

            console.log(
                string.concat(
                    "exitShort(Constants.SHORT_STARTING_ID, ",
                    vm.toString(shortErcDebt),
                    ",",
                    vm.toString(price),
                    ",",
                    vm.toString(currentUser),
                    ");"
                )
            );
            s_ob.exitShort(
                Constants.SHORT_STARTING_ID, shortErcDebt, uint80(price), currentUser
            );

            ghost_oraclePrice = diamond.getOraclePriceT(asset);

            updateShorters();
            ghost_exitShortComplete++;
        }
    }

    function mintNFT(uint80 price, uint88 amount, uint256 index, uint8 addressSeed)
        public
        advanceTime
    {
        address msgSender = _seedToAddress(addressSeed);
        initialGhostVarSetUp(msgSender);

        //bound values - Make minimum the ETH price to ensure it is above oracle
        price = boundU80(price, DEFAULT_PRICE, DEFAULT_PRICE * 2);
        amount = boundU88(amount, DEFAULT_AMOUNT, DEFAULT_AMOUNT * 10);

        // keep oracle price fixed
        s_ob.setETH(4000 ether);

        //match short with bid
        s_ob.fundLimitBidOpt(price, amount, msgSender);
        s_ob.fundLimitShortOpt(price, amount, msgSender);

        STypes.ShortRecord[] memory shortRecords =
            diamond.getShortRecords(asset, msgSender);

        // bound inputs
        index = bound(index, 1, shortRecords.length);
        STypes.ShortRecord memory shortRecord = shortRecords[index - 1];
        if (shortRecord.tokenId != 0) return;
        vm.prank(msgSender);
        diamond.mintNFT(asset, shortRecord.id);

        ghost_oraclePrice = diamond.getOraclePriceT(asset);
        s_Users.add(msgSender);
        s_Shorters.add(msgSender);
        s_NFTOwners.add(msgSender);
    }

    function transferNFT(uint256 index, uint8 addressSeed)
        public
        advanceTime
        useExistingNFTOwner(addressSeed)
    {
        // if (currentNFTOwner == address(0)) return;
        initialGhostVarSetUp(currentNFTOwner);
        address nftReceiver = _seedToAddress(addressSeed);

        STypes.ShortRecord[] memory shortRecords =
            diamond.getShortRecords(asset, currentNFTOwner);

        if (shortRecords.length == 0) return;

        // bound inputs
        index = bound(index, 1, shortRecords.length);
        STypes.ShortRecord memory shortRecord = shortRecords[index - 1];

        STypes.NFT memory nft = diamond.getNFT(shortRecord.tokenId);
        if (nft.owner != currentNFTOwner) return;

        vm.prank(currentNFTOwner);
        diamond.transferFrom(currentNFTOwner, nftReceiver, shortRecord.tokenId);
        s_Users.add(nftReceiver);
        s_NFTOwners.add(nftReceiver);
        updateShorters();
    }

    function secondaryMarginCall(uint88 amount, uint8 addressSeed)
        public
        advanceTime
        advancePrice(addressSeed)
        useExistingShorter(addressSeed)
    {
        ghost_secondaryMC++;
        initialGhostVarSetUp(currentUser);
        STypes.ShortRecord[] memory shortRecords =
            diamond.getShortRecords(asset, currentUser);

        if (shortRecords.length > 0) {
            ghost_secondaryMCSRGtZeroCounter++;
            // bound inputs
            amount = boundU88(amount, DEFAULT_AMOUNT, DEFAULT_AMOUNT * 10);

            address marginCaller = _seedToAddress(addressSeed);
            if (marginCaller == currentUser) {
                ghost_secondaryMCSameUserCounter++;
                return;
            }

            STypes.ShortRecord memory short =
                diamond.getShortRecord(asset, currentUser, Constants.SHORT_STARTING_ID);
            if (short.status == SR.Cancelled) {
                ghost_secondaryMCCancelledShortCounter++;
                return;
            }
            uint88 shortErcDebt = short.ercDebt;

            //@dev reduce price to margin call levels
            int256 preMCPrice = int256(diamond.getOraclePriceT(asset).inv());
            s_ob.setETH(500 ether);
            console.log("setETH(500 ether);");

            //@dev randomly choose between erc vs wallet approach
            if (addressSeed % 2 == 0) {
                if (
                    diamond.getAssetUserStruct(asset, marginCaller).ercEscrowed
                        < shortErcDebt
                ) {
                    return;
                }

                console.log(
                    string.concat(
                        "liquidateErcEscrowed(",
                        vm.toString(currentUser),
                        ",",
                        vm.toString(Constants.SHORT_STARTING_ID),
                        ",",
                        vm.toString(shortErcDebt),
                        ",",
                        vm.toString(marginCaller),
                        ");"
                    )
                );

                s_ob.liquidateErcEscrowed(
                    currentUser, Constants.SHORT_STARTING_ID, shortErcDebt, marginCaller
                );
            } else {
                if (IAsset(asset).balanceOf(marginCaller) >= shortErcDebt) {
                    s_ob.liquidateWallet(
                        currentUser,
                        Constants.SHORT_STARTING_ID,
                        shortErcDebt,
                        marginCaller
                    );

                    console.log(
                        string.concat(
                            "liquidateWallet(",
                            vm.toString(currentUser),
                            ",",
                            vm.toString(Constants.SHORT_STARTING_ID),
                            ",",
                            vm.toString(shortErcDebt),
                            ",",
                            vm.toString(marginCaller),
                            ");"
                        )
                    );
                } else if (
                    diamond.getAssetUserStruct(asset, marginCaller).ercEscrowed
                        >= shortErcDebt
                ) {
                    //withdraw
                    console.log(
                        string.concat(
                            "diamond.withdrawAsset(asset,",
                            vm.toString(shortErcDebt),
                            ");"
                        )
                    );
                    vm.prank(marginCaller);
                    diamond.withdrawAsset(asset, shortErcDebt);

                    console.log(
                        string.concat(
                            "liquidateWallet(",
                            vm.toString(currentUser),
                            ",",
                            vm.toString(Constants.SHORT_STARTING_ID),
                            ",",
                            vm.toString(shortErcDebt),
                            ",",
                            vm.toString(marginCaller),
                            ");"
                        )
                    );
                    s_ob.liquidateWallet(
                        currentUser,
                        Constants.SHORT_STARTING_ID,
                        shortErcDebt,
                        marginCaller
                    );
                } else {
                    return;
                }
            }

            //@dev reset price back to original levels
            s_ob.setETH(preMCPrice);

            s_Users.add(marginCaller);
            updateShorters();
            ghost_secondaryMCComplete++;
        }
    }

    function primaryMarginCall(uint8 addressSeed)
        public
        advanceTime
        advancePrice(addressSeed)
        useExistingShorter(addressSeed)
    {
        ghost_primaryMC++;
        initialGhostVarSetUp(currentUser);
        STypes.ShortRecord[] memory shortRecords =
            diamond.getShortRecords(asset, currentUser);

        if (shortRecords.length > 0) {
            ghost_primaryMCSRGtZeroCounter++;
            address marginCaller = _seedToAddress(addressSeed);
            if (marginCaller == currentUser) {
                ghost_primaryMCSameUserCounter++;
                return;
            }

            STypes.ShortRecord memory short =
                diamond.getShortRecord(asset, currentUser, Constants.SHORT_STARTING_ID);
            if (short.status == SR.Cancelled) {
                // TODO: can also check short.flaggerId != 0 if time hasn't passed
                ghost_primaryMCCancelledShortCounter++;
                return;
            }

            uint88 shortErcDebt = short.ercDebt;

            int256 preMCPrice = int256(diamond.getOraclePriceT(asset).inv());

            //@dev create ask for margin call
            console.log(
                string.concat(
                    "fundLimitAskOpt(",
                    vm.toString(uint80(diamond.getOraclePriceT(asset))),
                    ",",
                    vm.toString(shortErcDebt),
                    ",",
                    vm.toString(marginCaller),
                    ");"
                )
            );
            s_ob.fundLimitAskOpt(
                uint80(diamond.getOraclePriceT(asset)), shortErcDebt, marginCaller
            );

            //@dev reduce price to margin call levels
            console.log("setETH(1500 ether);");
            s_ob.setETH(1500 ether);

            console.log(string.concat("vm.prank(", vm.toString(marginCaller), ");"));
            console.log(
                string.concat(
                    "diamond.flagShort",
                    vm.toString(asset),
                    ",",
                    vm.toString(currentUser),
                    ",",
                    vm.toString(Constants.SHORT_STARTING_ID),
                    ",",
                    vm.toString(Constants.HEAD),
                    ");"
                )
            );
            vm.prank(marginCaller);
            diamond.flagShort(
                asset, currentUser, Constants.SHORT_STARTING_ID, Constants.HEAD
            );

            //for some reason, the skip and liquidate are not working together
            skip(10 hours + 1 hours);
            //@dev reset time to prevent stale oracle data
            s_ob.setETH(1500 ether);

            console.log(
                string.concat(
                    "liquidate(",
                    vm.toString(currentUser),
                    ",",
                    vm.toString(Constants.SHORT_STARTING_ID),
                    ",",
                    vm.toString(marginCaller),
                    ");"
                )
            );
            s_ob.liquidate(currentUser, Constants.SHORT_STARTING_ID, marginCaller);

            //@dev reset price back to original levels
            s_ob.setETH(preMCPrice);

            s_Users.add(marginCaller);
            updateShorters();
            ghost_primaryMCComplete++;
        }
    }

    function depositEth(uint8 addressSeed, uint88 amountIn) public {
        // bound address seed
        address msgSender = _seedToAddress(addressSeed);
        address bridge;

        // bound inputs
        amountIn = boundU88(amountIn, Constants.MIN_DEPOSIT, 10000 ether);
        console.log(
            string.concat(
                "give(", vm.toString(msgSender), ",", vm.toString(amountIn), ");"
            )
        );
        give(msgSender, amountIn);

        if (amountIn % 2 == 0) {
            bridge = _bridgeSteth;
        } else {
            bridge = _bridgeReth;
        }

        console.log(string.concat("vm.prank(", vm.toString(msgSender), ");"));
        console.log(
            string.concat(
                "diamond.depositEth{value:",
                vm.toString(amountIn),
                "}(",
                amountIn % 2 == 0 ? "_bridgeSteth" : "_bridgeReth",
                ");"
            )
        );

        vm.prank(msgSender);
        diamond.depositEth{value: amountIn}(bridge);
        s_Users.add(msgSender);

        console.log(
            string.concat(
                "// bridge=",
                vm.toString(diamond.getZethTotal(vault)),
                " zethTotal=",
                vm.toString(diamond.getVaultStruct(vault).zethTotal)
            )
        );
    }

    function deposit(uint8 addressSeed, uint88 amountIn) public {
        address msgSender = _seedToAddress(addressSeed);
        address bridge;

        amountIn = boundU88(amountIn, Constants.MIN_DEPOSIT, 10000 ether);

        vm.startPrank(msgSender);
        if (amountIn % 2 == 0) {
            bridge = _bridgeSteth;
            give(_steth, msgSender, amountIn);
            give(_steth, amountIn);
            steth.approve(_bridgeSteth, type(uint88).max);

            console.log(
                string.concat(
                    "give(_steth,",
                    vm.toString(msgSender),
                    ",",
                    vm.toString(amountIn),
                    ");"
                )
            );
            console.log(string.concat("give(_steth,", vm.toString(amountIn), ");"));
            console.log(string.concat("vm.prank(", vm.toString(msgSender), ");"));
            console.log(string.concat("steth.approve(_bridgeSteth, type(uint88).max);"));
        } else {
            bridge = _bridgeReth;
            give(_reth, msgSender, amountIn);
            give(_reth, amountIn);
            reth.approve(_bridgeReth, type(uint88).max);

            console.log(
                string.concat(
                    "give(_reth,",
                    vm.toString(msgSender),
                    ",",
                    vm.toString(amountIn),
                    ");"
                )
            );
            console.log(string.concat("give(_reth,", vm.toString(amountIn), ");"));
            console.log(string.concat("vm.prank(", vm.toString(msgSender), ");"));
            console.log(string.concat("reth.approve(_bridgeReth, type(uint88).max);"));
        }

        console.log(string.concat("vm.prank(", vm.toString(msgSender), ");"));
        console.log(
            string.concat(
                "diamond.deposit(",
                amountIn % 2 == 0 ? "_bridgeSteth" : "_bridgeReth",
                ",",
                vm.toString(amountIn),
                ");"
            )
        );

        diamond.deposit(bridge, amountIn);
        vm.stopPrank();
        s_Users.add(msgSender);

        console.log(
            string.concat(
                "// bridge=",
                vm.toString(diamond.getZethTotal(vault)),
                " zethTotal=",
                vm.toString(diamond.getVaultStruct(vault).zethTotal)
            )
        );
    }

    function withdraw(uint8 addressSeed, uint88 amountOut)
        public
        useExistingUser(addressSeed)
    {
        address bridge;

        uint88 escrowed = diamond.getVaultUserStruct(vault, currentUser).ethEscrowed;
        if (escrowed <= 1) {
            return;
        } else {
            amountOut = boundU88(amountOut, 1, escrowed);
        }

        if (steth.balanceOf(_bridgeSteth) >= amountOut) {
            bridge = _bridgeSteth;
        } else if (reth.balanceOf(_bridgeReth) >= amountOut) {
            bridge = _bridgeReth;
        } else {
            return;
        }

        console.log(string.concat("vm.prank(", vm.toString(currentUser), ");"));
        console.log(
            string.concat(
                "diamond.withdraw(",
                amountOut % 2 == 0 ? "_bridgeSteth" : "_bridgeReth",
                ",",
                vm.toString(amountOut),
                ");"
            )
        );

        vm.prank(currentUser);
        diamond.withdraw(bridge, amountOut);

        console.log(
            string.concat(
                "// bridge=",
                vm.toString(diamond.getZethTotal(vault)),
                " zethTotal=",
                vm.toString(diamond.getVaultStruct(vault).zethTotal),
                " ethEscrowed=",
                vm.toString(escrowed)
            )
        );
    }

    function unstakeEth(uint8 addressSeed, uint88 amountOut)
        public
        useExistingUser(addressSeed)
    {
        address bridge;

        uint88 escrowed = diamond.getVaultUserStruct(vault, currentUser).ethEscrowed;
        if (escrowed <= 1) {
            return;
        } else {
            amountOut = boundU88(amountOut, 1, escrowed);
        }

        if (steth.balanceOf(_bridgeSteth) >= amountOut) {
            bridge = _bridgeSteth;
        } else if (reth.balanceOf(_bridgeReth) >= amountOut) {
            bridge = _bridgeReth;
        } else {
            return;
        }

        console.log(string.concat("vm.prank(", vm.toString(currentUser), ");"));
        console.log(
            string.concat(
                "diamond.unstakeEth(",
                amountOut % 2 == 0 ? "_bridgeSteth" : "_bridgeReth",
                ",",
                vm.toString(amountOut),
                ");"
            )
        );

        vm.prank(currentUser);
        diamond.unstakeEth(bridge, amountOut);

        console.log(
            string.concat(
                "// bridge=",
                vm.toString(diamond.getZethTotal(vault)),
                " zethTotal=",
                vm.toString(diamond.getVaultStruct(vault).zethTotal),
                " ethEscrowed=",
                vm.toString(escrowed)
            )
        );
    }

    function fakeYield(uint64 amountIn) public {
        amountIn = uint64(_bound(amountIn, 1, 1 ether));
        address bridge;
        if (amountIn % 2 == 0) {
            bridge = _bridgeSteth;
            give(_steth, _bridgeSteth, amountIn);
        } else {
            bridge = _bridgeReth;
            give(_reth, _bridgeReth, amountIn);
        }
        vm.prank(address(1));
        diamond.updateYield(vault);

        console.log(
            string.concat(
                "// bridge=",
                vm.toString(diamond.getZethTotal(vault)),
                " zethTotal=",
                vm.toString(diamond.getVaultStruct(vault).zethTotal)
            )
        );
    }

    function distributeYield(uint8 addressSeed) public useExistingShorter(addressSeed) {
        if (diamond.getYield(asset, currentUser) == 0) return;

        skip(Constants.YIELD_DELAY_HOURS * 2 hours); //@round up by hours instead of seconds or minutes;

        address[] memory assets = new address[](1);
        assets[0] = asset;

        vm.prank(currentUser);
        diamond.distributeYield(assets);
    }

    //VAULT Functions

    function depositAsset(uint8 addressSeed, uint104 amount)
        public
        advanceTime
        advancePrice(addressSeed)
        useExistingUser(addressSeed)
    {
        initialGhostVarSetUp(currentUser);
        uint256 balance = IAsset(asset).balanceOf(currentUser);

        if (balance == 0) return;
        // bound inputs
        amount = boundU104(amount, balance, balance);
        vm.prank(currentUser);
        diamond.depositAsset(asset, amount);
    }

    function depositZeth(uint8 addressSeed, uint88 amount)
        public
        advanceTime
        advancePrice(addressSeed)
        useExistingUser(addressSeed)
    {
        initialGhostVarSetUp(currentUser);
        uint256 balance = IAsset(zeth).balanceOf(currentUser);
        if (balance == 0) return;
        // bound inputs
        amount = boundU88(amount, balance, balance);
        vm.prank(currentUser);
        diamond.depositZETH(zeth, amount);
    }

    function withdrawAsset(uint8 addressSeed, uint104 amount)
        public
        advanceTime
        advancePrice(addressSeed)
        useExistingUser(addressSeed)
    {
        initialGhostVarSetUp(currentUser);
        uint104 ercEscrowed = diamond.getAssetUserStruct(asset, currentUser).ercEscrowed;
        if (ercEscrowed == 0) return;
        // bound inputs
        amount = boundU104(amount, ercEscrowed, ercEscrowed);
        vm.prank(currentUser);
        diamond.withdrawAsset(asset, amount);
    }

    function withdrawZeth(uint8 addressSeed, uint88 amount)
        public
        advanceTime
        advancePrice(addressSeed)
        useExistingUser(addressSeed)
    {
        initialGhostVarSetUp(currentUser);
        uint88 ethEscrowed = diamond.getVaultUserStruct(vault, currentUser).ethEscrowed;
        if (ethEscrowed == 0) return;
        // bound inputs
        amount = boundU88(amount, ethEscrowed, ethEscrowed);
        vm.prank(currentUser);
        diamond.withdrawZETH(zeth, amount);
    }
    //Shorts Stuff - re-organize page later

    function increaseCollateral(uint88 amount, uint256 index, uint8 addressSeed)
        public
        advanceTime
        advancePrice(addressSeed)
        useExistingShorter(addressSeed)
    {
        initialGhostVarSetUp(currentUser);

        STypes.ShortRecord[] memory shortRecords =
            diamond.getShortRecords(asset, currentUser);

        console.log("shortRecords.length == 0");
        if (shortRecords.length == 0) return;
        // bound inputs
        amount = boundU88(amount, DEFAULT_PRICE / 10, DEFAULT_PRICE);
        index = bound(index, 1, shortRecords.length);
        STypes.ShortRecord memory shortRecord = shortRecords[index - 1];

        console.log(
            string.concat(
                "diamond.increaseCollateral(asset,",
                vm.toString(shortRecord.id),
                ",",
                vm.toString(amount),
                ");"
            )
        );
        vm.prank(currentUser);
        diamond.increaseCollateral(asset, shortRecord.id, amount);
        ghost_oraclePrice = diamond.getOraclePriceT(asset);
    }

    function decreaseCollateral(uint88 amount, uint256 index, uint8 addressSeed)
        public
        advanceTime
        advancePrice(addressSeed)
        useExistingShorter(addressSeed)
    {
        initialGhostVarSetUp(currentUser);

        STypes.ShortRecord[] memory shortRecords =
            diamond.getShortRecords(asset, currentUser);

        console.log("shortRecords.length == 0");
        if (shortRecords.length == 0) return;
        // bound inputs
        index = bound(index, 1, shortRecords.length);
        STypes.ShortRecord memory shortRecord = shortRecords[index - 1];
        //@dev bounding this to prevent reducing CR too low
        amount = boundU88(amount, shortRecord.collateral / 10, shortRecord.collateral / 6);

        console.log(
            string.concat(
                "diamond.decreaseCollateral(asset,",
                vm.toString(shortRecord.id),
                ",",
                vm.toString(amount),
                ");"
            )
        );
        vm.prank(currentUser);
        diamond.decreaseCollateral(asset, shortRecord.id, amount);
        ghost_oraclePrice = diamond.getOraclePriceT(asset);
    }

    function combineShorts(uint8 addressSeed)
        public
        advanceTime
        advancePrice(addressSeed)
        useExistingShorter(addressSeed)
    {
        initialGhostVarSetUp(currentUser);

        STypes.ShortRecord[] memory shortRecords =
            diamond.getShortRecords(asset, currentUser);

        console.log("shortRecords.length < 2");
        if (shortRecords.length < 2) return;

        uint8[] memory ids = new uint8[](shortRecords.length);

        for (uint256 i = 0; i < shortRecords.length; i++) {
            ids[i] = shortRecords[i].id;
        }

        vm.prank(currentUser);
        diamond.combineShorts(asset, ids);
        ghost_oraclePrice = diamond.getOraclePriceT(asset);
    }
}
