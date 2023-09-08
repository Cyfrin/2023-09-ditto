// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

//https://github.com/rocket-pool/rocketpool/blob/master/contracts/contract/RocketStorage.sol
contract RocketStorage {
    mapping(bytes32 => address) private addressStorage;

    function getAddress(bytes32 _key) external view returns (address r) {
        return addressStorage[_key];
    }

    //function belows are fake and used to mock getAddress of reth and depositpool
    function setReth(address addr) external {
        addressStorage[keccak256(abi.encodePacked("contract.address", "rocketTokenRETH"))]
        = addr;
    }

    function setDeposit(address addr) external {
        addressStorage[keccak256(
            abi.encodePacked("contract.address", "rocketDepositPool")
        )] = addr;
    }
}
