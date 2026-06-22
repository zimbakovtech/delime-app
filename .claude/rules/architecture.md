# Rule: Architecture & layering

Respect the layer boundaries. Each layer talks only to the one below it.

```
screens/  →  state/AppState  →  data/AppRepository  →  data/AppDatabase (SQLite)
                  │
                  └─→ services/SettlementService (pure, derived data)
```

- **Raw SQL lives only in `lib/data/app_repository.dart`.** Never write SQL in
  screens, state, or services. Add a repository method instead.
- **`AppState` (`lib/state/app_state.dart`) is the only mutable state holder.**
  It's a `ChangeNotifier`. Every mutation: call repo → reload affected list →
  `notifyListeners()`. Follow the existing pattern in `addPerson` / `savePurchase`.
- **Screens never touch the repository or DB directly.** Read via
  `context.watch<AppState>()`, mutate via `AppState` methods.
- **`SettlementService` is pure** — static methods, no DB, no state, no side
  effects. Balances and settlements are *derived* (`AppState.balances` /
  `.settlements` recompute on demand). Keep it that way; it's the easiest layer
  to unit-test.
- **Models (`lib/models/`) are immutable** (`@immutable`, `copyWith`,
  `toMap`/`fromMap`). No business logic beyond simple derived getters
  (`payersTotal`, `splitsTotal`).
- User-facing errors → throw `AppStateException(message)` from `AppState`;
  screens catch and show the message.

DB: SQLite, version 1, 4 tables (`people`, `purchases`, `payers`, `splits`),
`PRAGMA foreign_keys = ON`, `ON DELETE CASCADE` from purchases to payers/splits.
Schema change ⇒ bump `_dbVersion` and add migration in `AppDatabase`.
