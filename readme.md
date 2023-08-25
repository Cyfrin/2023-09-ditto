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
