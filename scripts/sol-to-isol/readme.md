# sol-to-isol

> Generates a solidity interface from a given solidity contract

- [x] rename contracts from Contract to IContract
- [x] tested on v0.8.21
- [x] handle inlining any structs
- [x] handle public getters
- [ ] copy over errors
- [ ] copy over events

## Example

> `contracts/A.sol`

```sol
pragma solidity 0.8.21;

struct Custom {
  address a;
}

contract A {
  // functions from contracts/A.sol

  string public i;
  address public a;
  Custom public b;
  address[] public c;
  Custom[] public d;
  mapping(string => address) public e;
  mapping(string => address[]) public f;
  mapping(string => Custom) public g;
  mapping(string => Custom[]) public h;

  function setUp() external {}

  receive() external payable {}

  fallback() external payable {}
}

```

> `interfaces/A.sol`

```sol
pragma solidity 0.8.21;

interface IA {
  // public getters from contracts/misc/A.sol
  function i() external view returns (string memory);

  function a() external view returns (address);

  function b() external view returns (address);

  function c(uint256) external view returns (address);

  function d(uint256) external view returns (address);

  function e(string memory) external view returns (address);

  function f(string memory, uint256) external view returns (address);

  function g(string memory) external view returns (address);

  function h(string memory, uint256) external view returns (address);

  // functions from contracts/A.sol
  function setUp() external;

  receive() external payable;

  fallback() external payable;
}

```
