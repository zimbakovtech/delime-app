#!/usr/bin/env bash
# Quality gate: no empty directories under lib/ or test/. Git doesn't track
# empty dirs, so they signal dead scaffolding or a half-finished move.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "Checking for empty directories under lib/ and test/…"
empty=$(find lib test -type d -empty 2>/dev/null || true)
if [ -n "$empty" ]; then
  echo "✗ Empty directories found (remove them):"
  echo "$empty"
  exit 1
fi
echo "No empty directories."
