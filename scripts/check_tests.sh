#!/usr/bin/env bash
# Quality gate: the test suite passes.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "Running flutter test…"
flutter test
echo "Tests OK."
