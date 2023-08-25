// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U80, U88} from "contracts/libraries/PRBMathHelper.sol";
import {Constants} from "contracts/libraries/Constants.sol";
import {STypes, O, SR} from "contracts/libraries/DataTypes.sol";

import {Test} from "forge-std/Test.sol";

import {IOBFixture} from "interfaces/IOBFixture.sol";
import {IDiamond} from "interfaces/IDiamond.sol";

import {Vault} from "contracts/libraries/Constants.sol";
import {Handler} from "./Handler.sol";

// import {console} from "contracts/libraries/console.sol";

/// @dev This contract deploys the target contract, the Handler, adds the Handler's actions to the invariant fuzzing
/// @dev targets, then defines invariants that should always hold throughout any invariant run.
contract InvariantsNFT is Test {
    using U256 for uint256;
    using U80 for uint80;
    using U88 for uint88;

    Handler internal s_handler;
    IDiamond public diamond;
    uint256 public vault;
    address public asset;
    IOBFixture public s_ob;

    bytes4[] public selectors;

    //@dev Used for one test: statefulFuzz_allOrderIdsUnique
    mapping(uint16 id => uint256 cnt) orderIdMapping;

    function setUp() public {
        IOBFixture ob = IOBFixture(deployCode("OBFixture.sol"));
        ob.setUp();
        address _diamond = ob.contracts("diamond");
        asset = ob.contracts("cusd");
        diamond = IDiamond(payable(_diamond));
        vault = Vault.CARBON;

        s_handler = new Handler(ob);
        selectors = [Handler.mintNFT.selector, Handler.transferNFT.selector];

        targetSelector(FuzzSelector({addr: address(s_handler), selectors: selectors}));
        targetContract(address(s_handler));

        s_ob = ob;
    }

    function statefulFuzz_NFT_NFTsHaveOnlyOneShortRecord() public {
        address[] memory users = s_handler.getUsers();
        for (uint256 i = 0; i < users.length; i++) {
            STypes.ShortRecord[] memory shortRecords =
                diamond.getShortRecords(asset, users[i]);
            for (uint256 j = 0; j < shortRecords.length; j++) {
                STypes.ShortRecord memory shortRecord = shortRecords[j];
                uint40 tokenId = shortRecord.tokenId;
                if (tokenId == 0) {
                    continue;
                } else {
                    STypes.NFT memory nft = diamond.getNFT(tokenId);
                    assertEq(nft.shortRecordId, shortRecord.id);
                    assertEq(nft.owner, users[i]);
                }
            }
        }
    }

    function statefulFuzz_NFT_TokenIdOnlyIncreases() public {
        assertGe(diamond.getTokenId(), s_handler.getGhostTokenIdCounter());
    }
}
