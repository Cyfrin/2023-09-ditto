# OrderBook

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

# OrderBook

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
forge install foundry-rs/forge-std
git submodule update --init --recursive
# setup .env file
echo 'ANVIL_9_PRIVATE_KEY=0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6' > .env && echo 'MAINNET_RPC_URL=http://192.168.11.134:8545' >> .env
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

## Get Started

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
