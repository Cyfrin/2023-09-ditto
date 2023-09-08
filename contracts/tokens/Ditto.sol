// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {
    ERC20,
    ERC20Permit
} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract Ditto is ERC20, ERC20Permit, ERC20Votes {
    address private immutable diamond;

    error NotDiamond();

    constructor(address diamondAddr) ERC20("Ditto", "DITTO") ERC20Permit("Ditto") {
        diamond = diamondAddr;
    }

    modifier onlyDiamond() {
        if (msg.sender != diamond) {
            revert NotDiamond();
        }
        _;
    }

    function mint(address to, uint256 amount) external onlyDiamond {
        _mint(to, amount);
    }

    function burnFrom(address account, uint256 amount) external onlyDiamond {
        _burn(account, amount);
    }

    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }
}
