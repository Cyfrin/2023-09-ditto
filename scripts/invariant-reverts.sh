#!/bin/sh

mkdir -p .forge-snapshots/reverts

{
    FOUNDRY_PROFILE=default forge test --match-test statefulFuzz
} > .forge-snapshots/reverts/invariant_revert.snap