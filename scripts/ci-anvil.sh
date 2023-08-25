#!/bin/bash

(
  ./scripts/anvil.sh
) & sleep 2

bun run deploy-local

exit_code=$?

if [ $exit_code -eq 0 ]; then
  exit 0
fi

exit 1