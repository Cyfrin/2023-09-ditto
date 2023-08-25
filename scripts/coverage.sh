set -e # exit on error

# generates lcov.info
forge coverage --no-match-path "test/invariants/**/*.sol" --report lcov

# Filter out node_modules, test, and mock files
lcov \
    --branch-coverage \
    --remove lcov.info \
    --output-file filtered-lcov.info \
    --ignore-errors unused \
    "test*" "deploy*" "governance*" "mocks*" \
    "facets/DiamondLoupeFacet.sol" "facets/DiamondCutFacet.sol" "facets/TestFacet.sol" "libraries/console.sol" "libraries/UniswapTickMath.sol" "libraries/LibDiamond.sol" "libraries/PRBMathHelper.sol" "libraries/UniswapOracleLibrary.sol"

# Generate summary
lcov --list filtered-lcov.info

# Open more granular breakdown in browser
# --ignore-errors source,branch,callback,corrupt,count,deprecated,empty,format,mismatch,negative,package,parallel,source,unsupported,unused,version \
if [ "$CI" != "true" ]
then
    genhtml \
        --output-directory coverage \
        filtered-lcov.info
    open coverage/index.html
fi