#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release --product calctl
BIN=".build/release/calctl"
codesign --force --sign - --entitlements calctl.entitlements "$BIN"
echo "Built and ad-hoc signed: $BIN"
