# Rule: Code style & conventions

Analysis is strict (`flutter analyze --fatal-infos --fatal-warnings`). Lint
config: `analysis_options.yaml`. Common ones that bite:

- **Package imports only** — `import 'package:delime/...'`. Relative `lib/`
  imports are an analyzer error. (`always_use_package_imports`)
- **Single quotes** for strings. (`prefer_single_quotes`)
- **`const` everywhere it's valid** — constructors, declarations, literals.
- **`final` locals** and `final` in for-each loops.
- **Trailing commas required** on multi-line arg/param lists. (`require_trailing_commas`)
- `sort_child_properties_last` — Flutter `child:`/`children:` go last.
- No `avoid_dynamic_calls`, no `unused_*`, no `dead_code` (all errors).
- `unawaited_futures` — `await` futures or mark `unawaited(...)`.

Other:
- Files `snake_case`, classes `PascalCase`, private members `_prefixed`.
- **No `print` / `debugPrint` in `lib/`** — `scripts/check_print.sh` fails the build.
- No empty directories under `lib/` or `test/` — `scripts/check_empty_dirs.sh` fails.
- Run `dart format lib/ test/` before finishing; format is gate-checked.

Let `dart format` decide whitespace — don't hand-format.
