// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {ISTETH} from "interfaces/ISTETH.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

//this is a mock of lido's unsteth: code can be reviewed here - https://vscode.blockscan.com/ethereum/0xe42c659dc09109566720ea8b2de186c2be7d94d9
contract UNSTETH is ERC721 {
    ISTETH private immutable steth;

    uint256 private requestIndex = 1;
    mapping(uint256 => Request) private requests;
    uint256[] private incomingRequests;

    constructor(ISTETH _steth) ERC721("stETH Withdrawal NFT", "unstETH") {
        steth = ISTETH(_steth);
    }

    enum R {
        Unprocessed,
        Processed,
        Withdrawn
    }

    struct Request {
        R status;
        uint256 amount;
    }

    receive() external payable {}

    function claimWithdrawals(
        uint256[] calldata _requestIds,
        uint256[] calldata /*_hints*/
    ) external {
        for (uint256 i = 0; i < _requestIds.length; ++i) {
            address owner;
            if (
                _isApprovedOrOwner(msg.sender, _requestIds[i])
                    && requests[_requestIds[i]].status == R.Processed
            ) {
                owner = _ownerOf(_requestIds[i]);
                _burn(_requestIds[i]);
                requests[_requestIds[i]].status = R.Withdrawn;
                (bool sent,) = owner.call{value: requests[_requestIds[i]].amount}("");
                assert(sent);
            }
        }
    }

    //add back _permit when we implement permit via erc-2612
    function requestWithdrawals(uint256[] calldata _amounts, address _owner)
        external
        returns (uint256[] memory requestIds)
    {
        if (_owner == address(0)) _owner = msg.sender;
        requestIds = new uint256[](_amounts.length);
        for (uint256 i = 0; i < _amounts.length; ++i) {
            steth.transferFrom(_owner, address(this), _amounts[i]);
            requests[requestIndex] = Request({status: R.Unprocessed, amount: _amounts[i]});
            incomingRequests.push(requestIndex);
            requestIds[i] = requestIndex;
            _safeMint(_owner, requestIndex);
            requestIndex++;
        }
    }

    //test only - normally this is done by validators via a different call - function isn't same
    function processWithdrawals() external {
        uint256 i = incomingRequests.length;
        uint256 amount;
        while (i > 0) {
            i--;
            amount += requests[incomingRequests[i]].amount;
            requests[incomingRequests[i]].status = R.Processed;
        }
        delete incomingRequests;
        steth.burn(amount);
        steth.transferWithdrawalEth(amount);
    }
}
