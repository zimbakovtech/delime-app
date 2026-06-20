#!/usr/bin/env bash
# Runs every quality gate. Continues through all checks (does not stop at the
# first failure) and reports a summary, exiting non-zero if any gate failed.
#
# Usage: bash scripts/quality_gates.sh
set -uo pipefail
cd "$(dirname "$0")/.."

CHECKS=(
  check_format
  check_analyze
  check_print
  check_empty_dirs
  check_tests
)

declare -a FAILED=()
START_DESC="Delime quality gates"
echo "================================================================"
echo " $START_DESC"
echo "================================================================"

for check in "${CHECKS[@]}"; do
  echo ""
  echo "──▶ $check"
  if bash "scripts/$check.sh"; then
    echo "   ✓ $check"
  else
    echo "   ✗ $check FAILED"
    FAILED+=("$check")
  fi
done

echo ""
echo "================================================================"
if [ "${#FAILED[@]}" -ne 0 ]; then
  echo " RESULT: FAILED (${#FAILED[@]}/${#CHECKS[@]}) → ${FAILED[*]}"
  echo "================================================================"
  exit 1
fi
echo " RESULT: all ${#CHECKS[@]} quality gates passed ✓"
echo "================================================================"
