# Prompt — Implement Phase 1 of the Delime Roadmap

> Copy everything below the line into your AI coding agent (Claude Code, Cursor, etc.),
> with the repository open and `DELIME_ROADMAP.md` present at the repo root.

---

You are an expert Flutter/Dart engineer working on **Delime** (a.k.a. *WeSplit*), an
offline-first shared-expense splitter. Your job is to implement **Phase 1** of the
project roadmap, and only Phase 1.

## Step 0 — Read the plan first

1. Open and read `DELIME_ROADMAP.md` in full before writing any code. It is the source
   of truth for this work.
2. Re-read these sections carefully and treat them as binding:
   - **§1 Guiding principles** (non-negotiable),
   - **§2 Architectural decisions** (committed long-term choices),
   - **Phase 1 — Multi-trip foundation**, including its *Scope/deliverables*,
     *Data-model summary*, *Code/module changes*, *Out of scope*, *Acceptance criteria*,
     and *Testing*,
   - **§6 Definition of done**.
3. Then read the existing codebase to ground yourself: `lib/main.dart`, the `models/`,
   `data/database.dart`, `data/app_repository.dart`, `state/app_state.dart`,
   `services/settlement_service.dart`, `utils/money.dart`, the `screens/`, and the
   existing `test/` tree. Mirror the patterns already in use.

## Your task

Implement **Phase 1 — Multi-trip foundation (local-first, no backend)** exactly as
specified in the roadmap. In short, deliver:

1. A first-class **`Trip`** entity + `trips` table (id/uuid, name, type, base_currency
   defaulting to EUR, optional dates, cover colour + optional cover photo path, status,
   timestamps).
2. A **schema migration** that adds `trip_id` to `people` and `purchases`, and migrates
   all existing rows into one auto-created default trip — **zero data loss**, with a test
   that upgrades a populated old-version DB.
3. A **trips list home screen**: create / edit / archive / delete trips; tapping a trip
   opens the existing Purchases/Settle/People shell **scoped to that trip**.
4. **Trip scoping** in `AppState` (`currentTrip`) so all people, purchases, balances, and
   settlements are filtered to the current trip. (People remain trip-scoped — do NOT
   share identities across trips; that's a later phase.)
5. **Expense categories** on purchases (built-in set + custom), with picker and chip in UI.
6. **Advanced split strategies** via a `SplitStrategy` abstraction: `equal`,
   `exactAmounts`, `percentages`, `shares`. Each must reconcile to the exact total using
   the existing leftover-minor-unit distribution rule. Keep `SettlementService` pure.
7. **Settle-up upgrades**: a `settlements` table; "mark as settled" recording a payment
   and updating outstanding balances; a settlement history; and a **simplify-debts
   on/off toggle** (on = greedy minimizer, off = direct debtor→creditor pairs).
8. **Local receipt photos**: attach photo(s) to a purchase, stored on-device with paths
   in an `attachments` table. **No OCR, no upload** — capture/display only.

## Hard constraints (do not violate)

- **Stay offline & accountless.** Add no networking, no auth, no cloud, no sync in this
  phase. The app must run from a clean install in airplane mode with no account.
- **Money stays integer minor units.** No floating point in stored amounts or split/
  settlement math. Every split strategy must sum exactly to the total.
- **Keep `SettlementService` pure** and side-effect free.
- **All SQL goes through the repository.** No SQL in widgets/screens/services.
- **Migrations are forward-only and lossless**, with a version bump and an upgrade test.
- **Do NOT pull in any later-phase work** (multi-currency/live FX, personal finance,
  accounts, sync, OCR, itemized splitting, payments, sharing). EUR-only + the existing
  fixed-rate behavior stays for now.
- Keep `scripts/quality_gates.sh` passing at every commit: `dart format`,
  `flutter analyze` (fatal infos/warnings), no stray `print()`, no empty dirs,
  `flutter test`.

## How to work

1. **Plan briefly first.** Produce a short ordered implementation plan and the list of
   files you'll add/change (map it to the roadmap's *Code/module changes*). Wait for the
   nothing-blocking-you check, then proceed.
2. **Land work in small, reviewable, releasable increments**, ideally in this order:
   (a) `Trip` model + `trips` table + migration + migration test;
   (b) repository CRUD scoped by `trip_id` + `AppState.currentTrip`;
   (c) trips list/home + create/edit/archive UI;
   (d) categories;
   (e) `SplitStrategy` + split math + exhaustive tests;
   (f) `settlements` table + mark-settled + history + simplify toggle;
   (g) local receipt attachments.
   After each increment, run the quality gates and keep the app launchable.
3. **Tests ship with logic.** Add: the migration upgrade test; split-strategy
   reconciliation tests (including non-divisible totals and leftover-unit edge cases);
   settlement-with-recorded-payments tests; repository CRUD tests for trips/settlements/
   attachments over `sqflite_common_ffi`; `AppState` trip-scoping + toggle tests; and
   widget tests for the trips list and the split-strategy editor. Keep `test/` mirroring
   `lib/`.
4. **Follow existing conventions** for state (`provider`/`ChangeNotifier`), theming
   (Material 3 dark), naming, and folder layout. Reuse the avatar palette for trip cover
   colours.
5. Add any new dependency (e.g. `image_picker`) minimally and justify it; keep the app
   free of network/cloud packages.

## Definition of done (verify before declaring complete)

- Every Phase 1 *Acceptance criterion* in `DELIME_ROADMAP.md` is met.
- `scripts/quality_gates.sh` passes locally; the app builds a release APK and a
  no-codesign iOS build.
- Existing single-ledger data migrates into a default trip with zero loss (proven by test).
- All four split strategies reconcile exactly (proven by tests).
- The app runs fully offline, signed-out, from a clean install.
- `README.md` is updated to describe multi-trip, categories, split strategies, settle-up
  history + simplify toggle, and local receipt photos.

When Phase 1 is complete against the above, **stop** and give me: a summary of what
changed (by area), the list of new/changed files, any deviations from the roadmap and
why, the test results, and anything you recommend reconsidering before Phase 2. Do not
begin Phase 2.
