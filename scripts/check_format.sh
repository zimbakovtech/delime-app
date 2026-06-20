#!/usr/bin/env bash
# Quality gate: code is formatted with `dart format`.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "Checking formatting (dart format)…"
dart format --output=none --set-exit-if-changed .
echo "Formatting OK."
