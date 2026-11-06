#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p test-build
clang -DHABITS=1 -fno-objc-arc -Wall -Wno-incomplete-implementation -Wno-deprecated-declarations -Isrc tests/core.m src/CLAIRequest.m src/CLIntegration.m src/ORJSON.m src/HBAI.m -framework Foundation -o test-build/core
test-build/core
