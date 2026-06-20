# Delime

> *Macedonian: "We split."*

**Delime** is an offline Android app for tracking shared trip expenses. Friends
log purchases, record who paid and who owes what, and at the end Delime works out
**exactly who should pay whom — with the fewest possible transactions** to settle
every debt.

No accounts, no internet, no cloud. All data lives in a local SQLite database on
the device.

---

## Features

### 👥 People
- Add, edit, and delete trip members.
- Each person gets a colour-coded avatar with their initials, auto-assigned so a
  group gets distinct colours.
- Deleting someone who appears in a purchase is **blocked** with a clear
  explanation of which purchases reference them.

### 🧾 Purchases — the heart of the app
A guided, single-screen flow:
1. **Name** the purchase (Dinner, Taxi, Groceries…).
2. **Amount + currency** — enter in **EUR (€)** or **MKD (ден)**. When MKD is
   selected the EUR equivalent is shown live (and vice-versa). Fixed rate:
   **1 EUR = 61.5 MKD**.
3. **Paid by** — one payer by default (pays the full amount). Add more payers as
   chips; each gets their own amount. A live badge shows how much is left to
   assign or whether payers are over the total.
4. **Split between** — everyone equally by default. Switch to **Custom** to enter
   per-person shares, or exclude people entirely. A payer doesn't have to be in
   the split (e.g. someone buying a group gift).

The save button stays disabled until **both** the payer total and the split total
match the purchase total, with a friendly explanation of any mismatch.

### 🤝 Settle up
- Per-person **balance summary**: how much they paid, their share, and their net
  (colour-coded — green if they're owed money, red if they owe).
- The **minimum set of payments** to settle everyone, each showing the amount in
  both EUR and MKD.
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

**Equal-split rounding:** when a total doesn't divide evenly, the leftover
cent(s) are handed out one per person from the top, so the shares always sum
exactly to the total. e.g. €10.00 ÷ 3 → €3.34, €3.33, €3.33.

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
    person.dart                 Person (name, colour, initials)
    purchase.dart               Purchase + Contribution (payer/split share)
    balance.dart                Balance + Settlement value types
  services/
    settlement_service.dart     Pure balance + greedy settlement logic
  data/
    database.dart               SQLite schema / connection
    app_repository.dart         All SQL CRUD lives here
  state/
    app_state.dart              ChangeNotifier: in-memory state + derived data
  screens/
    home_screen.dart            Bottom-nav shell (Purchases / Settle / People)
    purchases_screen.dart       Purchase list + totals
    add_purchase_screen.dart    The core add/edit flow
    settlement_screen.dart      Balances + payment plan
    people_screen.dart          Manage trip members
  theme/
    app_theme.dart              Dark Material 3 theme + colour tokens
    avatar_palette.dart         Avatar colour set + auto-assignment
  utils/
    money.dart                  Cents, EUR/MKD formatting & conversion, splitEqually
  widgets/                      Reusable UI (avatars, empty states, sheets)
```

- **State management:** `provider` (`ChangeNotifier`). The repository is the only
  thing that touches SQL; `AppState` keeps in-memory lists in sync and exposes
  derived balances/settlements computed by the pure `SettlementService`.
- **Database:** `sqflite` with four tables — `people`, `purchases`, `payers`,
  `splits` (child rows cascade-delete with their purchase).

### Dependencies
`sqflite`, `path`, `provider`, `intl`, `uuid` — no network/cloud packages.

---

## Building

Requires the Flutter SDK (developed against Flutter 3.41 / Dart 3.11).

```bash
flutter pub get

# Run on a connected device / emulator
flutter run

# Run the tests (settlement correctness, rounding, conversion)
flutter test

# Build a release APK
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
```

### Build configuration
- `applicationId`: `com.delime.app`
- `minSdkVersion`: 21
- `targetSdkVersion`: 34
