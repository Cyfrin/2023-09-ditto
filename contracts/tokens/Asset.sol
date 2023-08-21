// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Asset is ERC20 {
    address private immutable diamond;

    error NotDiamond();

    constructor(address diamondAddr, string memory name, string memory symbol)
        ERC20(name, symbol)
    {
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
}
