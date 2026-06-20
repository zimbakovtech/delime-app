#!/usr/bin/env bash
# Quality gate: static analysis is clean. Treats infos and warnings as failures
# so nothing slips past the curated lint set in analysis_options.yaml.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "Running flutter analyze (fatal infos + warnings)…"
flutter analyze --fatal-infos --fatal-warnings
echo "Analyze OK."
