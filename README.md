# Ditto 

[//]: # (contest-details-open)

## Contest Details 

- Total Prize Pool: $55,000
  - HM Awards: $50,000
  - Low Awards: $5,000
  - No GAS, Informational, or QAs

- Starts September 8, 2023
- Ends Oct 8th, 2023

## Stats
- nSLOC: ~3365
- Complexity Score: ~1682
- Dollars per Complexity: ~$33
- Dollars per nSLOC: ~$16

## About the Project

- [Docs](https://dittoeth.com/)
- [Twitter](https://twitter.com/dittoproj)

[//]: # (contest-details-close)

[//]: # (scope-open)

## Scope (contracts)

Let's prioritize the core parts: orderbook functions (making orders: `createX`), yield (`updateYield`, `distributeYield`), shortRecord functions (`increaseCollateral`)

- [ ] libraries/AppStorage.sol
- [ ] libraries/DataTypes.sol (struct packing for storage types)
- [ ] facets/AskOrdersFacet.sol
- [ ] facets/BidOrdersFacet.sol (particularly the `bidMatchAlgo`. bids are different because they match against both types of sell: ask/short)
- [ ] facets/ShortOrdersFacet.sol
- [ ] facets/OrdersFacet.sol
- [ ] libraries/LibOrders.sol
- [ ] facets/YieldFacet.sol
- [ ] libraries/LibBridge.sol
- [ ] facets/ShortRecordFacet.sol
- [ ] libraries/LibShortRecord.sol
- [ ] facets/MarginCallPrimaryFacet.sol
- [ ] facets/MarginCallSecondaryFacet.sol
- [ ] facets/ExitShortFacet.sol
- [ ] facets/ERC721Facet.sol (only care about `transferFrom`, `mintNFT` since the rest is standard OZ)
- [ ] libraries/LibAsset.sol
- [ ] libraries/LibVault.sol
- [ ] libraries/LibOracle.sol
- [ ] facets/VaultFacet.sol
- [ ] facets/BridgeRouterFacet.sol
- [ ] bridges/BridgeReth.sol (links to rETH)
- [ ] bridges/BridgeSteth.sol (links to stETH)
- [ ] facets/OwnerFacet.sol (dao only)
- [ ] tokens/Asset.sol (ERC20)
- [ ] tokens/Ditto.sol (ERC20)
- [ ] facets/MarketShutdownFacet.sol

## Out of Scope

> don't care about these or any view functions, can skip these.

- Diamond.sol
- libraries/LibDiamond.sol
- libraries/PRBMathHelper.sol
- libraries/UniswapOracleLibrary.sol
- libraries/UniswapTickMath.sol (copied bc of sol 0.8 + contract size too big)
- libraries/console.sol
- libraries/Constants.sol
- libraries/Errors.sol
- libraries/Events.sol
- interfaces/*.sol
- mocks/*.sol
- governance/*.sol
- facets/TWAPFacet.sol
- facets/TestFacet.sol
- facets/ViewFacet.sol
- facets/DiamondCutFacet.sol
- facets/DiamondLoupeFacet.sol

[//]: # (scope-close)

[//]: # (known-issues-open)

# Known Issues

- Oracle is very dependent on Chainlink: similar to Liquity. stale/invalid prices fallback to uniswap TWAP. 2 hours staleness means it can be somewhat out of date
- Oracle: non ETH/USD oracle assets currently have no Uniswap TWAP fallback, it reverts.
- Need boostrap phase: when there are few shorts/TAPP is low, easy to fall into black swan scenario
- Bootstrap for ditto rewards: first claimer gets 100% of ditto reward
- Events: still adding core events, mostly admin events for now.
- Not done with governance setup
- Not finished with mainnet deployment setup

## Known Considerations from previous stablecoin Codehawk report
[https://www.codehawks.com/report/cljx3b9390009liqwuedkn0m0]

- H-01: Collateral tokens < 18 decimals: Project assumes collateral tokens are 18 decimals because they will all specifically be ETH LSTs like rETH. stETH and rETH are both 18. diamondCut upgrade can be used otherwise. (see old reports)
- H-02: Liquidation reverts: Liquidation shouldn't revert the due to lack of collateral or the extra liquidation fee/bonus because the TAPP can be used. Primary liquidation can revert if there are no orders, secondary liquidation doesn't have an associated fee
- H-03: Liquidation of small shorts: Protocol attempts to cover liquidating small positions in a few ways: there is a minimum short amount upon creation, gas fee is paid by shorter not liquidator. Shorts with too small fee to get liquidated are also too small to effect the market with bad debt. If needed, the shutdownMarket can be called when market CR is < minimumCR to freeze that market and allow people to redeemErc. Worst case, TAPP/DAO can also secondary liquidate small positions
- M-01: protocol is only planned to be on L1
- M-02 stale price: stale period is intentionally set at 2 hours for Ethereum/mainnet for base oracle (ETH/USD), which fallsback to TWAP. For multi-asset oracle, considering adding a mapping to track different stale heartbeats (Gold is 24 hours)
- M-03 revert if outside of min/max answer: Shouldn't happen for a feed like ETH/USD, but will add checks for minAnswer and maxAnswer according to chainlink docs
- M-04 decimals: protocol assumes same decimals, not calling decimals() to save a SLOAD of gas. Can use diamond upgrade if needed for multi-asset if necessary.
- M-05 burnFrom: protocol doesn't inherit OZ ERC20Burnable, just calls _burn directly with owner modifier.
- M-06 duplicate inputs: protocol uses arrays for inputs for orderhints which isn't an issue, batches for secondary margin call (checks for deleted shorts), and combineShorts ids which checks deleted shorts
- M-07 oracle fallback: protocol uses Uniswap TWAP
- M-08 fee-on-transfer: protocol's bridges for reth/steth account checks for fees on deposit of eth into steth or reth by checking balanceOf. It doesn't do it for depositing the token itself, protocol assumes steth/reth won't add a fee on transfer.
- M-09 liquidate revert: protocol can use TAPP
- M-10 upgradable collateral: diamond upgradable, bridges are whitelisted already, will think about detecting upgrades
- M-11 liquidate front run: No particular protections against frontrunning an order/liquidation, and oracle manipulation (unlikely for ETH/USD pair for both chainlink/uniswap)
- M-12 dos liquidation: secondary liquidation doesn't need to be precise, can't be blocked

[//]: # (known-issues-close)

[//]: # (getting-started-open)

## Getting Started

Add a mainnet rpc url so you can run fork tests. 

```
bun install
bun run interfaces
forge build
echo 'ANVIL_9_PRIVATE_KEY=0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6' > .env && echo 'MAINNET_RPC_URL=XXXXX' >> .env
forge test
```

## Setup

```sh
# Install Bun to run TS/JS
curl -fsSL https://bun.sh/install | bash
# if already installed
bun upgrade
# download files from package.json into node_modules
bun install
# Install foundry for solidity
curl -L https://foundry.paradigm.xyz | bash
foundryup
# init/update submodules for forge-std
git submodule update --init --recursive
# setup .env file
echo 'ANVIL_9_PRIVATE_KEY=0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6' > .env && echo 'MAINNET_RPC_URL=XXXXX' >> .env
# disable next telemetry
npx next telemetry disable
```

```sh
# If needed, use volta to get node/npm, uses field in package.json
curl https://get.volta.sh | bash
volta install node
```

## Develop

> `bun run` to check commands
> there's a `pre-push` git hook (bypass with `--no-verify`)
> If you want to reset everything not tracked in git: `git clean -xfd`

- To run local node: `bun run anvil`, then deploy with `bun run deploy-local`
- To run UI: `bun run dev` (`http://localhost:3000`)
- Check `scripts` in `package.json`
  - `bun run build` to compile contracts
  - `bun run interfaces` to re-compile solidity interfaces
  - `bun run test`, `bun run test-gas` (`forge test`)
    - `-- --vv` for verbosity
    - `-- --watch` to watch files
    - `-- -m testX` to match tests
  - `bun run coverage` (first `brew install lcov`)

> https://book.getfoundry.sh/forge/writing-tests.html#writing-tests
> For info on `v`, https://book.getfoundry.sh/forge/tests.html?highlight=vvvv#logs-and-traces

## Running

````sh
bun run build
bun run test
bun run test-gas
bun run coverage

## Aliases

```sh
alias i='bun run interfaces-force'
alias t="forge test "
alias tm="forge test --match-test "
alias ts="forge test --match-test statefulFuzz"
alias g="bun run test-gas"
alias gm="FOUNDRY_PROFILE=gas forge build && FOUNDRY_PROFILE=testgas forge test --match-test "
alias w='forge test -vv --watch '

t -m testA
gm testA
w -m testA
```
````

[//]: # (getting-started-close)
