# Delime

> *Macedonian: "We split."*

**Delime** is an offline Android & iOS app for tracking shared expenses across
**multiple trips**. Friends log purchases, record who paid and who owes what, and
Delime works out **exactly who should pay whom — with the fewest possible
transactions** to settle every debt.

No accounts, no internet, no cloud. All data lives in a local SQLite database on
the device — it runs from a clean install in airplane mode.

---

## Features

### 🧳 Trips
- The home screen is a list of **trips** — a holiday, a household, a night out.
  Each trip is its own isolated ledger of people, purchases and settlements.
- Create, edit, **archive** and delete trips. Each gets a type (vacation,
  household, couple, event, other), an optional date range, and a cover colour.
- A quick **net-balance pill** and member count show each trip's status at a
  glance. Tapping a trip opens the Purchases / Settle / People shell scoped to it.
- People are **trip-scoped** — identities are not shared across trips (yet).

### 👥 People
- Add, edit, and delete trip members.
- Each person gets a colour-coded avatar with their initials, auto-assigned so a
  group gets distinct colours.
- Deleting someone who appears in a purchase is **blocked** with a clear
  explanation of which purchases reference them.

### 🧾 Purchases — the heart of the app
A guided, single-screen flow:
1. **Name** the purchase (Dinner, Taxi, Groceries…).
2. **Category** — pick a built-in (Food, Drinks, Transport, Accommodation,
   Groceries, Activities, Shopping, Other) or type a **custom** one. The category
   shows as a chip in the purchase list.
3. **Amount + currency** — enter in **EUR (€)** or **MKD (ден)**. When MKD is
   selected the EUR equivalent is shown live (and vice-versa). Fixed rate:
   **1 EUR = 61.5 MKD**.
4. **Paid by** — one payer by default (pays the full amount). Add more payers as
   chips; each gets their own amount. A live badge shows how much is left to
   assign or whether payers are over the total.
5. **Split between** — four strategies, all of which reconcile to the cent:
   - **Equal** — shared evenly (exclude anyone who shouldn't pay).
   - **Exact** — type each person's exact € amount.
   - **Percent** — type each person's % (must total 100%).
   - **Shares** — type integer weights (a bigger weight pays more).

   A payer doesn't have to be in the split (e.g. someone buying a group gift).
6. **Receipts** *(when editing a purchase)* — attach photos from the camera or
   gallery. They're stored **on-device only**; nothing is uploaded.

The save button stays disabled until **both** the payer total and the split total
match the purchase total, with a friendly explanation of any mismatch.

### 🤝 Settle up
- Per-person **balance summary**: how much they paid, their share, and their net
  (colour-coded — green if they're owed money, red if they owe).
- The payment plan, with a **"Simplify debts" toggle**: on = the **minimum set of
  payments** to settle everyone (greedy minimiser); off = **direct
  debtor → creditor** payments without rerouting through other people.
- **Mark a payment as settled** (with an optional note) — it's recorded, removed
  from the outstanding balances, and listed in the **settlement history** (undoable).
- When everyone is balanced, a clear "All square!" celebration instead of an
  empty list.

### ✨ Details
- Dark, modern Material 3 theme.
- Thoughtful empty states, loading states, and error messages throughout.
- Handles edge cases: single-person trips, no purchases yet, payers excluded from
  the split, and cent-perfect equal splits (leftover cents are distributed so
  totals are never off by €0.01).

---

## How money is handled

All amounts are stored and calculated internally as **integer EUR cents** to
avoid floating-point rounding errors. EUR is the canonical currency; MKD is only
an input/display convenience converted at the fixed rate of **1 EUR = 61.5 MKD**.

**Split rounding:** when a total doesn't divide evenly, the leftover cent(s) are
handed out so the shares always sum exactly to the total. Equal splits hand them
out one per person from the top (€10.00 ÷ 3 → €3.34, €3.33, €3.33); **percentage**
and **shares** splits use the **largest-remainder** rule (`utils/split.dart`).
Percentages are entered as basis points internally (10000 = 100%) to keep the
maths integer-only.

**Settlement algorithm:** a greedy minimum-transaction matcher. It repeatedly
pairs the **biggest debtor** with the **biggest creditor**, transfers the smaller
of the two amounts, and removes whoever hits zero — until everyone is settled.

### Worked example (from the spec)

Four friends — John, Eve, Marc, Amy — have a €10.00 dinner. Marc and John each
paid €5.00; the cost is split equally (€2.50 each).

| Person | Paid  | Owes  | Net    |
|--------|-------|-------|--------|
| John   | €5.00 | €2.50 | +€2.50 |
| Eve    | €0.00 | €2.50 | −€2.50 |
| Marc   | €5.00 | €2.50 | +€2.50 |
| Amy    | €0.00 | €2.50 | −€2.50 |

Settlement (2 transactions):
- **Eve pays John €2.50**
- **Amy pays Marc €2.50**

This exact scenario is covered by the automated tests in
`test/settlement_test.dart`.

---

## Architecture

```
lib/
  main.dart                     App entry, theme + Provider wiring
  models/
    trip.dart                   Trip (name, type, dates, cover, status)
    person.dart                 Person (name, colour, initials)
    purchase.dart               Purchase + Contribution (payer/split share)
    balance.dart                Balance + Settlement value types
    settlement_record.dart      A recorded (confirmed) payment
    attachment.dart             A local receipt-photo reference
  services/
    settlement_service.dart     Pure balances + greedy/direct settlement logic
  data/
    database.dart               SQLite schema / connection / migrations
    app_repository.dart         All SQL CRUD lives here (scoped by trip)
    receipt_store.dart          Receipt-file interface (keeps AppState pure)
    file_receipt_store.dart     On-device file impl (path_provider + dart:io)
  state/
    app_state.dart              ChangeNotifier: trips + trip-scoped state
  screens/
    trips_screen.dart           Home: the trips list (entry point)
    add_edit_trip_screen.dart   Create / edit a trip
    home_screen.dart            Per-trip bottom-nav shell (Purchases / Settle / People)
    purchases_screen.dart       Purchase list + totals
    add_purchase_screen.dart    The core add/edit flow (category, splits, receipts)
    settlement_screen.dart      Balances, plan, simplify toggle, history
    people_screen.dart          Manage trip members
  theme/
    app_theme.dart              Dark Material 3 theme + colour tokens
    avatar_palette.dart         Avatar/cover colour set + auto-assignment
  utils/
    money.dart                  Cents, EUR/MKD formatting & conversion, splitEqually
    split.dart                  Split-strategy math (largest-remainder)
    categories.dart             Built-in expense categories + icons
    trip_display.dart           Trip type labels/icons + date formatting
  widgets/                      Reusable UI (avatars, cards, chips, thumbnails…)
```

- **State management:** `provider` (`ChangeNotifier`). The repository is the only
  thing that touches SQL; `AppState` keeps in-memory lists in sync and exposes
  derived balances/settlements computed by the pure `SettlementService`.
- **Database:** `sqflite`, **schema v2**, seven tables — `trips`, `people`,
  `purchases`, `payers`, `splits`, `settlements`, `attachments`. `people` and
  `purchases` carry a `trip_id`; children cascade-delete with their trip/purchase.
  A forward-only migration moves a v1 (single-ledger) database into one
  auto-created default trip with zero data loss.

### Dependencies
`sqflite`, `path`, `provider`, `intl`, `uuid`, `image_picker`, `path_provider` —
no network/cloud packages.

---

## Building

Requires the Flutter SDK (developed against Flutter 3.41 / Dart 3.11).

```bash
flutter pub get

# Run on a connected device / emulator
flutter run

# Run the tests
flutter test

# Build a release APK (Android)
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk

# Build for iOS (no signing — e.g. on CI)
flutter build ios --release --no-codesign
```

Delime targets both **Android** and **iOS** (bundle id `com.delime.app` on both).

## Tests

Tests mirror `lib/` under `test/` and cover the logic end to end:

| Area | File |
|------|------|
| Money: conversion, formatting, `splitEqually` rounding | `test/utils/money_test.dart` |
| Split strategies (equal/exact/percent/shares reconcile exactly) | `test/utils/split_test.dart` |
| Expense categories | `test/utils/categories_test.dart` |
| Balances + greedy min-transaction settlement | `test/services/settlement_service_test.dart` |
| `Person` / `Purchase` value types | `test/models/` |
| Repository CRUD (trips/people/purchases/settlements/attachments) over in-memory SQLite | `test/data/app_repository_test.dart` |
| **v1 → v2 migration** upgrades a populated DB with zero loss | `test/data/migration_test.dart` |
| `AppState`: trip scoping, settle/undo, simplify toggle, receipts | `test/state/app_state_test.dart` |
| Widgets/screens: trips list, split editor, settle screen, avatars, empty states | `test/screens/`, `test/widgets/` |

## Quality gates & CI

Local quality gates live in [`scripts/`](scripts/README.md) and run on every PR
to `main` / `develop` via [`.github/workflows/ci.yml`](.github/workflows/ci.yml):

```bash
bash scripts/quality_gates.sh
```

Gates: `dart format` · `flutter analyze` (fatal infos/warnings) · stray
`print()` regression · empty-dir regression · `flutter test`. CI also builds the
Android APK and the iOS app (no codesign) on each PR.

### Build configuration
- `applicationId`: `com.delime.app`
- `targetSdkVersion`: 34
- `minSdkVersion`: **24** — the spec asks for 21, but Flutter 3.41 (the SDK this
  was built with) enforces a hard minimum and rejects anything below its floor:
  `flutter build apk --release` fails the `ReleaseMinSdkCheck` with *"minimum
  Android SDK version (21) is lower than Flutter's minimum supported version"*.
  Since a working release APK from the plain build command is a non-negotiable
  requirement, `minSdk` is left at Flutter's floor (`flutter.minSdkVersion` = 24).
  This only affects the *install* floor (API 24 / Android 7.0+); the app runs
  unchanged on every newer device. To force 21 you'd need an older Flutter or
  the `--android-skip-build-dependency-validation` flag.

---

## License

[MIT](LICENSE) © Damjan Zimbakov
