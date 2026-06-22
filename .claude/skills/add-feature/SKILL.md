---
name: add-feature
description: Playbook for adding a feature or data field to Delime through every layer (model → DB → repository → state → UI → tests). Use when a change spans more than one layer or touches persisted data.
---

# Adding a feature (vertical slice)

Delime is strictly layered (`.claude/rules/architecture.md`). A feature that
touches data goes top-to-bottom. Work in this order, verifying at each step.

## 1. Model (`lib/models/`)
- Add the field to the immutable model. Update the constructor, `copyWith`,
  `toMap`, `fromMap`. Keep `@immutable`.
- Money fields are `int` cents.
- **verify:** `flutter analyze`.

## 2. Database (`lib/data/database.dart`)
- Add the column in `_onCreate`.
- **Bump `_dbVersion`** and add an `onUpgrade` migration — there's existing
  on-device data. Don't silently break it.
- **verify:** schema matches model `toMap`/`fromMap` keys.

## 3. Repository (`lib/data/app_repository.dart`)
- All SQL changes happen here only. Update inserts/queries/mappers.
- **verify:** add/extend a repository test using in-memory SQLite + `FakeRepository`
  helpers; `flutter test test/data/`.

## 4. State (`lib/state/app_state.dart`)
- Expose the new data / mutation. Pattern: call repo → reload list →
  `notifyListeners()`. Throw `AppStateException` for user-facing failures.
- Keep derived data (balances/settlements) in `SettlementService`, not here.
- **verify:** `flutter test test/state/`.

## 5. UI (`lib/screens/`, `lib/widgets/`)
- Read via `context.watch<AppState>()`, mutate via `AppState` methods. No repo/DB
  in the UI. Format money with `Money.formatEur` / `formatBoth`.
- Reuse `lib/widgets/` + `lib/theme/` tokens; don't hardcode colours/geometry.

## 6. Gates
- `dart format lib/ test/`
- `bash scripts/quality_gates.sh` (or `/qa`) — must be fully green before done.

## Invariants to keep
- Purchase: `totalCents == payersTotal == splitsTotal`.
- Money stays integer EUR cents end to end (`.claude/rules/money.md`).
- Settlement service stays pure.
