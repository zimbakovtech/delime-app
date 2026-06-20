#!/usr/bin/env bash
# Quality gate: no stray print()/debugPrint() left in production code (lib/).
# These are almost always forgotten debug output. Use proper logging if needed.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "Checking for stray print()/debugPrint() in lib/…"
# Match `print(` / `debugPrint(` as a call; ignore identifiers like `sprint(`.
if matches=$(grep -rnE '(^|[^A-Za-z0-9_.])(print|debugPrint)[[:space:]]*\(' \
  lib --include='*.dart'); then
  echo "✗ Found print/debugPrint calls in lib/:"
  echo "$matches"
  exit 1
fi
echo "No stray print() found."
