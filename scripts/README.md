# Quality gate scripts

Local, CI-agnostic checks. Each script `cd`s to the repo root, exits non-zero on
failure, and can be run on its own. The CI workflow (`.github/workflows/ci.yml`)
runs the orchestrator on every pull request to `main` / `develop`.

| Script | Gate |
|--------|------|
| `quality_gates.sh` | Runs every gate below, prints a summary, fails if any failed |
| `check_format.sh` | `dart format` leaves no changes |
| `check_analyze.sh` | `flutter analyze --fatal-infos --fatal-warnings` is clean |
| `check_print.sh` | No stray `print()` / `debugPrint()` in `lib/` |
| `check_empty_dirs.sh` | No empty directories under `lib/` or `test/` |
| `check_tests.sh` | `flutter test` passes |

## Usage

```bash
# All gates
bash scripts/quality_gates.sh

# A single gate
bash scripts/check_analyze.sh
```

Run `flutter pub get` first if dependencies aren't fetched yet.
