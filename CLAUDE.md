# CLAUDE.md

Guidance for AI agents working in this repo. Combines universal behavioral
principles with Delime-specific facts. Read the principles first, then the
project section.

---

## Behavioral Principles

Guidelines to reduce common LLM coding mistakes.

**Tradeoff:** These bias toward caution over speed. For trivial tasks, use judgment.

### 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

### 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it
work") require constant clarification.

**These principles are working if:** fewer unnecessary changes in diffs, fewer
rewrites due to overcomplication, and clarifying questions come before
implementation rather than after mistakes.

---

## Project: Delime

Offline mobile app (Android + iOS) for splitting shared trip expenses. Friends
log purchases with payers and splits; the app computes who owes whom in the
fewest transactions. No accounts, no internet, no cloud — all data is local
SQLite. ("Делиме" = "We split.")

### Stack

- **Flutter 3.41+ / Dart `^3.11.5`**
- `provider` — state management (`ChangeNotifier`)
- `sqflite` — local SQLite; `sqflite_common_ffi` for in-memory test DB
- `intl` — number formatting · `uuid` — ID generation
- No Firebase, no network packages. Keep it that way unless explicitly asked.

### Commands

```bash
flutter pub get                                      # install deps
flutter run                                          # run on device/emulator
flutter test                                         # run all tests
dart format lib/ test/                               # format
flutter analyze --fatal-infos --fatal-warnings       # static analysis (must be clean)
bash scripts/quality_gates.sh                        # full gate suite (run before commit/PR)
flutter build apk --release                          # Android release
flutter build ios --release --no-codesign            # iOS build (CI style)
```

`scripts/quality_gates.sh` runs, in order: format check, analyze, no stray
`print`/`debugPrint` in lib/, no empty dirs, tests. CI (`.github/workflows/ci.yml`)
runs these plus Android + iOS builds on PRs to `main`/`develop`.

### Architecture

Strict layering — respect it:

- `lib/models/` — immutable value types (`@immutable`, `copyWith()`,
  `toMap()`/`fromMap()`). `Person`, `Purchase` + `Contribution`, `Balance` + `Settlement`.
- `lib/data/database.dart` — SQLite schema (4 tables: people, purchases, payers, splits).
- `lib/data/app_repository.dart` — **only** place raw SQL lives. All CRUD here.
- `lib/state/app_state.dart` — `ChangeNotifier`. Central in-memory state + derived
  data. Loads from repository on startup. Throws `AppStateException` for
  user-facing errors (e.g. deleting a person still referenced).
- `lib/services/settlement_service.dart` — **pure** static logic (greedy
  min-transaction algorithm). No side effects, no state.
- `lib/screens/` — UI screens. Consume state via `context.watch<AppState>()` /
  `Provider.of<AppState>()`. `home_screen.dart` is the bottom-nav shell.
- `lib/widgets/` — reusable components. `lib/theme/` — dark Material 3 theme +
  avatar palette. `lib/utils/money.dart` — currency logic.
- `lib/main.dart` — entry point; wires repository → Provider → `DelimeApp`.

### Critical conventions

- **Money: amounts stored as integer EUR cents.** EUR is canonical; MKD is
  input/display only at fixed rate 1 EUR = 61.5 MKD. All conversion/formatting
  goes through `Money` (`lib/utils/money.dart`). Never store floats or MKD.
- Files snake_case, classes PascalCase, private members `_prefixed`.
- No relative imports (lint-enforced). Prefer `const` constructors, `final` locals.
- Keep settlement logic pure — no DB or state access in `settlement_service.dart`.
- Tests mirror `lib/` under `test/`. Use `test/helpers/` (`FakeRepository`,
  `sample_data`) for fixtures. Add/update tests when changing behavior.

### Reference docs (`.claude/`)

Always-on rules — read before touching the relevant area:
- [.claude/rules/money.md](.claude/rules/money.md) — integer-cents money handling.
- [.claude/rules/architecture.md](.claude/rules/architecture.md) — layer boundaries.
- [.claude/rules/style.md](.claude/rules/style.md) — lint/format conventions.
- [.claude/rules/testing.md](.claude/rules/testing.md) — test layout + invariants.

Task playbooks (skills):
- `domain-model` — entities, invariants, settlement algorithm.
- `add-feature` — vertical-slice change across all layers.

Command: `/qa` runs the full quality-gate suite.

### Before finishing any change

Run `bash scripts/quality_gates.sh` — analyze is `--fatal-infos --fatal-warnings`,
so any info/warning fails. No `print`/`debugPrint` in `lib/`.
