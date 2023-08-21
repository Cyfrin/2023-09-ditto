// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// import {console} from "contracts/libraries/console.sol";

//https://github.com/rocket-pool/rocketpool/blob/master/contracts/contract/token/RocketTokenRETH.sol
contract RocketTokenRETH is ERC20 {
    //mock values to represent the reth to eth supply
    uint256 private ethSupply = 1 ether;
    uint256 private rethSupply = 1 ether;

    constructor() ERC20("Rocket Pool ETH", "rETH") {}

    //Normally this function lives on RocketDepositPool
    function deposit() external payable {
        uint256 rethAmount = getRethValue(msg.value);
        // Check rETH amount
        require(rethAmount > 0, "Invalid token mint amount");
        _mint(msg.sender, rethAmount);
    }

    //This admin function normally lives on RocketNetworkBalances
    function submitBalances(uint256 _ethSupply, uint256 _rethSupply) external {
        ethSupply = _ethSupply;
        rethSupply = _rethSupply;
    }

    //used in tests
    function getExchangeRate() external view returns (uint256) {
        return getEthValue(1 ether);
    }

    function burn(uint256 _rethAmount) external {
        require(_rethAmount > 0, "Invalid token burn amount");
        require(balanceOf(msg.sender) >= _rethAmount, "Insufficient rETH balance");
        uint256 ethAmount = getEthValue(_rethAmount);
        uint256 ethBalance = address(this).balance;
        require(ethBalance >= ethAmount, "Insufficient ETH for swap");
        _burn(msg.sender, _rethAmount);
        payable(msg.sender).transfer(ethAmount);
    }

    //bottom two functions are used as external calls in bridgeReth
    function getEthValue(uint256 _rethAmount) public view returns (uint256) {
        return (_rethAmount * ethSupply) / rethSupply;
    }

    function getRethValue(uint256 _ethAmount) public view returns (uint256) {
        return (_ethAmount * rethSupply) / ethSupply;
    }
}
