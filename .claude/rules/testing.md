# Rule: Testing

Behavior change ⇒ test change. Tests are a quality gate (`scripts/check_tests.sh`).

- **`test/` mirrors `lib/`** — `lib/services/x.dart` ↔ `test/services/x_test.dart`.
- Framework: `flutter_test`. Run with `flutter test`.
- **Shared fixtures in `test/helpers/`** — `FakeRepository` (in-memory repo stand-in)
  and `sample_data` (canonical people/purchases). Reuse them; don't re-invent fixtures.
- **DB tests use in-memory SQLite** via `sqflite_common_ffi` and
  `AppDatabase(path: ...)` / inMemory path — never the real device DB.
- **Pure logic (`SettlementService`, `Money`) is the priority to test** — cheap,
  deterministic, high value. The settlement test encodes the spec's 4-friend example.
- Bug fix workflow: write a failing test that reproduces it first, then fix
  until green. Never delete or weaken a test to pass a gate.

Cent invariants worth asserting: `splitEqually` parts sum to total; settlement
plan zeroes out every balance; `payersTotal == splitsTotal == totalCents`.
