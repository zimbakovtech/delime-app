# Delime — Long-Term Product & Engineering Roadmap

> **Purpose of this document.** This is the canonical, long-lived plan for evolving
> Delime from a single-ledger offline expense splitter into a production-grade,
> collaborative, multi-trip money app — *without throwing away what makes it good*.
> It is written to be executed by an AI coding agent (and reviewed by a human) one
> phase at a time. Each phase is self-contained, ships something usable, and leaves
> the app in a releasable state.
>
> When implementing, **always read this file first**, locate the phase you are
> working on, and treat its *Acceptance criteria* as the definition of done.

---

## 0. Where we are today (baseline)

Delime is an offline Android/iOS Flutter app (`com.delime.app`) that tracks shared
trip expenses and computes the **minimum set of payments** to settle all debts.

- **State:** `provider` / `ChangeNotifier` (`AppState`). The repository is the only
  layer that touches SQL; `AppState` holds in-memory lists and exposes derived
  balances/settlements from the **pure** `SettlementService`.
- **Storage:** local `sqflite` SQLite, four tables — `people`, `purchases`,
  `payers`, `splits` (children cascade-delete with their purchase). No network, no
  accounts, no cloud.
- **Money:** stored/calculated as **integer EUR cents**. EUR is canonical; MKD is an
  input/display convenience at a **fixed** rate (1 EUR = 61.5 MKD). Equal-split
  leftover cents are distributed one-per-person from the top so shares sum exactly.
- **Settlement:** greedy biggest-debtor ↔ biggest-creditor matcher.
- **Structure:** `lib/{models,services,data,state,screens,theme,utils,widgets}`,
  Material 3 dark theme, with tests mirroring `lib/` under `test/`.

There is currently **one implicit ledger** — no concept of separate trips.

---

## 1. Guiding principles (non-negotiable across all phases)

These constraints hold for every phase unless a phase explicitly supersedes one.

1. **Local-first, always.** The on-device SQLite database is the source of truth.
   The app must remain fully usable with no network and no account. The backend
   (introduced in Phase 3) is a *sync + collaboration layer on top*, never a
   prerequisite for core use. This is Delime's primary differentiator — protect it.
2. **Money is exact.** All monetary values stay integer **minor units** (cents).
   Never use floating point for stored amounts or settlement math. Every split
   strategy must reconcile to the exact total (leftover-unit distribution). The
   `SettlementService` stays **pure** and side-effect free so it can run identically
   on device and (later) on the server.
3. **The repository owns SQL.** No widget, screen, or service issues SQL directly.
   New persistence goes through `AppRepository` (or a clearly-scoped sibling
   repository). `AppState` stays the single source of in-memory truth for the UI.
4. **Migrations are forward-only and lossless.** Every schema change ships a
   `sqflite` migration with a version bump and a test that upgrades a populated
   old-version DB without data loss. Never require users to reinstall.
5. **Tests gate everything.** Logic changes ship with tests. `scripts/quality_gates.sh`
   (format, analyze with fatal infos/warnings, no stray `print()`, no empty dirs,
   `flutter test`) must pass. CI must stay green, including the release APK and the
   no-codesign iOS build.
6. **Each phase is releasable.** No phase may leave `main` in a broken or
   half-migrated state. Feature-flag incomplete work rather than merging it half-done.
7. **Privacy is a feature.** No telemetry that identifies users without explicit
   opt-in. No selling data — ever. State this in-product where relevant.

---

## 2. Architectural decisions made for the long term

These are committed choices so later phases don't re-litigate them.

- **Backend (Phase 3+): Supabase.** Postgres + Auth + Storage + Realtime, EU-region
  hostable (matters for an MK/EU user base and GDPR). Row-Level Security (RLS) is the
  authorization model: a row is visible to a user iff they are a member of its trip.
- **Sync model (Phase 3+): local-first sync, not thin-client.** Preferred approach is
  a purpose-built engine (PowerSync or ElectricSQL) that syncs local SQLite ⇄ Postgres.
  If that proves unworkable, fall back to a **custom change-log sync**: every mutable
  row carries `updated_at` + `deleted_at` (soft delete) + an `op_log` of local changes
  replayed on reconnect. Conflict policy: **last-write-wins per field** for scalar
  edits; expenses are append-mostly so true conflicts are rare. Document the chosen
  engine in `/docs/SYNC.md` when Phase 3 starts.
- **IDs are UUIDs everywhere** (already using `uuid`). This makes offline-created rows
  safe to sync without server round-trips for key allocation. Apply this to the new
  `trips` table and all future tables from the moment they're created.
- **Trip is the unit of sharing and sync.** Every shareable/syncable row belongs to a
  trip. Personal-finance data (Phase 2) belongs to a user and is never shared.
- **Multi-currency from Phase 2 onward.** Each stored amount carries a currency code
  and the minor-unit scale for that currency. EUR stays the default display base but
  is no longer hard-coded as the only currency. The fixed 61.5 rate is removed.
- **Money capture stays a guided single-screen flow.** New input methods (OCR, voice,
  bank import) feed *into* the existing add/edit flow rather than replacing it, so
  there is one validated path to a saved expense.

---

## 3. Phase overview & dependency order

| Phase | Theme | Network? | Account? | Ships |
|-------|-------|----------|----------|-------|
| **1** | Multi-trip foundation + richer expenses & settlement | No | No | Multiple trips, categories, advanced splits, settle-up history, local receipt photos |
| **2** | Multi-currency, personal finance & insights | Optional (FX) | No | Real currencies + live FX, personal ledger, budgets, analytics, Trip Wrapped |
| **3** | Accounts & cloud sync | Yes | Yes | Supabase auth + storage, local-first sync, backup, profiles |
| **4** | Collaboration & sharing | Yes | Yes | Shared trips, invites/QR, ghost members, realtime, comments, approve/dispute, activity feed, notifications |
| **5** | Smart capture & payments | Yes | Yes | Receipt OCR, itemized line-item splitting, NL/voice entry, settle-up deep links, open banking import |
| **6** | Growth, monetization & polish | Yes | Mixed | Freemium/Pro, i18n, widgets, share-sheet, shared "kitty" model, photo memories, AI query |

**Ordering rationale.** Phases 1–2 are *all local* — they harden the foundation and
add real user value without the cost and risk of a backend, and they deliberately
shape the schema so it's sync-ready. Auth and open banking are intentionally **late**
(Phase 3 and Phase 5 respectively): they carry the most compliance, security, and
maintenance burden, and they're far cheaper to build correctly once the data model is
stable. Collaboration (Phase 4) depends on auth+sync (Phase 3). Smart capture (Phase 5)
is highest-effort/highest-delight and assumes the collaborative model exists.

---

## 4. Phases in detail

### Phase 1 — Multi-trip foundation (local-first, no backend)

**Goal.** Turn the single implicit ledger into many first-class **trips**, and enrich
the expense and settlement models — all 100% offline, no accounts, no network. This is
the keystone phase: trips become the unit that everything later (sync, sharing) hangs on.

**Why it differentiates.** Competitors bolt multi-group onto a cloud account. Delime
gets a polished multi-trip experience that works on a plane with zero setup — and the
advanced/weighted splitting below is more flexible than most free competitors offer.

**Scope / deliverables.**

1. **Trip entity.** New `trips` table and `Trip` model:
   `id (uuid)`, `name`, `type` (`vacation` | `household` | `couple` | `event` | `other`),
   `base_currency` (default `EUR` — single-currency until Phase 2), `start_date?`,
   `end_date?`, `cover_color` (from the avatar palette) and optional `cover_photo_path?`,
   `status` (`active` | `archived`), `created_at`, `updated_at`.
2. **Schema migration.** Add `trip_id` foreign key to `people` and `purchases`
   (cascade with trip delete). Migrate all existing rows into one auto-created default
   trip named e.g. *"My Trip"*. Bump DB version; add an upgrade test proving an existing
   populated DB migrates with zero data loss.
3. **Trips list (new home).** A trips screen becomes the entry point: list of active
   trips with name, type icon, date range, member count, and a quick net-balance pill.
   Create / edit / archive / delete a trip. Archived trips live in a separate section.
   Tapping a trip opens the existing bottom-nav shell (Purchases / Settle / People)
   **scoped to that trip**.
4. **Trip scoping.** `AppState` gains a `currentTrip`; all derived data (purchases,
   people, balances, settlements) is filtered to the current trip. People are
   trip-scoped (a person belongs to a trip); a future phase introduces cross-trip
   identities — do **not** prematurely share people across trips here.
5. **Expense categories.** Add a `category` field to `Purchase` (built-in set:
   Food, Drinks, Transport, Accommodation, Groceries, Activities, Shopping, Other,
   plus a custom string). Surface a category picker in the add/edit flow and a category
   chip in the purchase list.
6. **Advanced split strategies.** Generalize splitting beyond equal/custom into a
   `SplitStrategy`: `equal`, `exactAmounts`, `percentages`, `shares` (integer weights).
   Each must reconcile exactly to the total using the existing leftover-unit
   distribution rule. Keep `SettlementService` pure; put split math in `utils/money.dart`
   (or a new `utils/split.dart`) with exhaustive tests. The add-purchase save button
   stays disabled until payer total and split total both equal the purchase total,
   regardless of strategy.
7. **Settle-up upgrades.** Add a `settlements` table recording confirmed payments
   (`id`, `trip_id`, `from_person`, `to_person`, `amount_cents`, `note?`, `settled_at`).
   On the settle screen, let a suggested payment be **marked as settled** (locally),
   which records a settlement and removes it from outstanding balances. Show a
   settlement history. Add a **"simplify debts" on/off** toggle: on = current greedy
   minimizer; off = show direct debtor→creditor pairs without netting through others.
8. **Local receipt photos.** Allow attaching one or more photos to a purchase, stored
   on local device storage with the path persisted in a new `attachments` table
   (`id`, `purchase_id`, `file_path`, `created_at`). **No OCR and no upload** in this
   phase — capture/display only. Use `image_picker` (+ camera) and a local app
   documents directory.

**Data-model summary (Phase 1 end).**
`trips` · `people(trip_id)` · `purchases(trip_id, category)` · `payers` · `splits` ·
`settlements(trip_id)` · `attachments(purchase_id)`.

**Code / module changes (mapped to existing structure).**
- `models/`: add `trip.dart`; extend `purchase.dart` (category) and contribution model
  for split strategy; add `settlement_record.dart`, `attachment.dart`.
- `data/database.dart`: schema v-bump + migrations for all new tables/columns.
- `data/app_repository.dart`: CRUD for trips, settlements, attachments; scope existing
  queries by `trip_id`.
- `state/app_state.dart`: `currentTrip`, trip list, trip-scoped derived data, settle
  actions, simplify-debts flag.
- `services/settlement_service.dart`: accept a "simplify or not" parameter; subtract
  recorded settlements from outstanding balances. Keep pure.
- `utils/`: split-strategy math + rounding (extend `money.dart` or add `split.dart`).
- `screens/`: new `trips_screen.dart` (home) + `add_edit_trip` flow; rework
  `home_screen.dart` to be trip-scoped; extend `add_purchase_screen.dart` (categories,
  split strategies, photo attach); extend `settlement_screen.dart` (mark settled,
  history, toggle).
- `widgets/`: trip card, category chip/picker, split-strategy editor, receipt thumbnail.

**Out of scope (Phase 1):** accounts, networking, sync, OCR, live FX (rate stays
fixed/EUR-only here), personal finance, payments, sharing.

**Acceptance criteria.**
- User can create, edit, archive, and delete multiple trips; data is fully isolated per
  trip; existing single-ledger data is migrated into a default trip with no loss.
- All four split strategies always reconcile to the exact total (covered by tests
  including non-divisible totals).
- A suggested payment can be marked settled and reflected in balances + history; the
  simplify-debts toggle changes the suggested payment set correctly.
- Photos attach to a purchase and display; nothing leaves the device.
- The app launches and runs with airplane mode on, no account, from a clean install.
- `scripts/quality_gates.sh` passes; CI builds release APK + no-codesign iOS.

**Testing.** Migration upgrade test; split-strategy reconciliation tests (incl.
leftover-cent edge cases); settlement-with-recorded-payments tests; repository CRUD for
trips/settlements/attachments over in-memory `sqflite_common_ffi`; `AppState` trip
scoping + toggle tests; widget tests for trips list and split editor.

---

### Phase 2 — Multi-currency, personal finance & insights (local; optional network for FX)

**Goal.** Make money real-world correct across currencies, and broaden Delime from a
twice-a-year holiday tool into something with weekly retention via a personal ledger
and insights. Still no account required.

**Why it differentiates.** Per-expense rate-locking + offline-graceful FX is something
even paid competitors fumble; "Trip Wrapped" is a shareable growth loop; the personal
ledger keeps users in the app between trips.

**Scope / deliverables.**

1. **True multi-currency.** Replace the fixed 1 EUR = 61.5 MKD constant. Each amount
   carries a `currency` code + minor-unit scale. A trip has a base/display currency;
   individual expenses may be entered in other currencies and are reconciled to the
   base. Settlement can be shown in each person's preferred currency.
2. **Live FX with rate-locking.** Fetch daily rates from a free FX provider, cache
   locally, and **lock the rate at expense time** (store the rate used on the expense).
   Offline behavior: fall back to last-cached rate or manual entry; never block expense
   creation on network. Keep all conversions exact at the minor-unit level.
3. **Personal (non-shared) ledger.** A per-user expense log that is **not** part of any
   trip and never shared. Categories, notes, optional receipt photo. Reuses the
   category + money primitives from Phase 1.
4. **Budgets.** Trip budgets ("we allocated X, here's the burn-down") and personal
   monthly/category budgets with simple over-budget indicators.
5. **Insights & export.** Category breakdowns, per-person spend, spend-over-time, and a
   trip cost summary. CSV export for a trip and for personal data.
6. **Trip Wrapped.** A shareable, image-exportable end-of-trip recap (total spent,
   biggest expense, who paid most, category split, a fun stat or two). Generated
   locally; share via the OS share sheet.

**Out of scope (Phase 2):** accounts, sync, OCR/itemization, payments, collaboration.

**Acceptance criteria.** Expenses can be entered in multiple currencies and reconcile
exactly to the trip base; rates are locked per expense and survive offline; personal
ledger is fully separate from trips; budgets show correct burn-down; CSV export
round-trips; Trip Wrapped renders and shares. Local-first + offline guarantees from
Phase 1 still hold. Quality gates + CI green.

---

### Phase 3 — Accounts & cloud sync (backend arrives; local-first preserved)

**Goal.** Introduce optional accounts and a **local-first sync** layer so users can back
up and (in Phase 4) share — without changing the offline core. Signing in is opt-in;
the app still works fully signed-out.

**Scope / deliverables.**
- **Supabase project**: Auth (email/OTP + Sign in with Apple + Google), Postgres schema
  mirroring the local tables, Storage bucket for receipts/avatars, RLS policies
  (row visible iff requester is a member of the row's trip; personal data visible only
  to its owner).
- **Sync engine** per §2: local SQLite ⇄ Postgres, queued offline mutations replayed on
  reconnect, soft deletes, `updated_at` everywhere, documented conflict policy in
  `/docs/SYNC.md`. Provide a clear sync status indicator + manual "sync now".
- **Profiles & avatar upload** (falls back to the existing initials+colour avatar).
- **Backup/restore**: signing in backs up all local trips + personal data to the cloud;
  signing in on a new device restores them.
- **Migration of receipts** from local-only paths (Phase 1) to Storage, keeping a local
  cache.

**Out of scope (Phase 3):** sharing trips with *other* users, realtime collaboration UI,
comments/approvals (all Phase 4). Build the plumbing; don't expose multi-user yet.

**Acceptance criteria.** A signed-out user is unaffected. A signed-in user's data
backs up and restores across devices; offline edits sync on reconnect without data loss;
RLS prevents reading other users' data; conflict policy behaves as documented. Offline
core still works with sync disabled. Quality gates + CI green; add backend/integration
tests for sync and RLS.

---

### Phase 4 — Collaboration & sharing

**Goal.** Turn trips into real shared ledgers between people.

**Scope / deliverables.**
- **Shared trips**: invite a person to a trip via share link or QR code.
- **Ghost / placeholder members**: add "Marc" and split with him before he has an
  account; he later **claims** that identity via an invite link, merging into a real
  user. (This is critical for adoption — never force signup before the first expense.)
- **Realtime updates** across members (Supabase Realtime), an **activity feed** per trip,
  and immutable **edit history** (who changed what, when).
- **Comments** on expenses and **approve / dispute** flow — lightweight: most expenses
  need no approval, but anyone can flag one, opening a thread rather than blocking
  settlement.
- **Roles**: trip admin (manage members, close trip) vs member.
- **Push notifications** (FCM/APNs): expense added, you were tagged/charged, someone
  settled with you, "trip ending — settle up?".
- **Two-party settle confirmation**: marking settled requests confirmation from the
  other side so settlement is a mutual fact.

**Acceptance criteria.** Two devices/accounts share a trip and see each other's changes
in realtime; ghost members can be created offline and later claimed with correct merge;
disputes/comments work; roles are enforced; notifications deliver; settle-up requires
mutual confirmation. Offline-first still holds (edits queue and sync). Gates + CI green.

---

### Phase 5 — Smart capture & payments

**Goal.** Make adding an expense feel effortless, and close the settlement loop by
helping money actually move. Highest delight, highest effort.

**Scope / deliverables.**
- **Receipt OCR**: snap a receipt → auto-fill merchant, total, date into the add flow
  (on-device ML Kit or a cloud OCR/LLM call; user always confirms).
- **Itemized / line-item splitting** (the flagship differentiator): parse line items and
  assign "who had what" — per-item payer/split — reconciling exactly to the receipt
  total. Builds on the Phase 1 split strategies.
- **Natural-language / voice entry**: "I paid 30 euros for the taxi, split between
  everyone" → a pre-filled, user-confirmed expense.
- **Settle-up deep links**: pre-fill PayPal / Revolut / Wise requests and SEPA/IBAN
  details so a tap takes you to a ready-to-send payment (Delime never holds funds).
- **Open banking import** (the "cardless" path — intentionally last): GoCardless /
  open-banking transaction import for EU banks, one-tap "this one's shared". Highest
  compliance burden; gate behind Pro and a clear consent flow.

**Acceptance criteria.** OCR fills a valid expense the user confirms; itemized splits
reconcile exactly; NL/voice produces a correct draft; settle deep links open the right
prefilled payment; bank import maps transactions to draft expenses with explicit
consent. Manual entry remains a first-class path. Gates + CI green.

---

### Phase 6 — Growth, monetization & polish

**Goal.** Make Delime sustainable, localized, and delightful.

**Scope / deliverables.**
- **Freemium / Pro**: free core (splitting, a couple of trips); Pro unlocks OCR,
  itemized splits, bank import, unlimited trips, advanced insights, Trip Wrapped exports.
  Privacy-respecting; no ads.
- **i18n**: Macedonian, Albanian, English at minimum; locale-aware number/currency/date.
- **Shared "kitty"/pot model**: everyone contributes to a pot, expenses draw it down,
  reconcile over/under-contribution at the end — an alternative to the debt model.
- **Photo gallery / memories**: trip photos interleaved with expenses (money + memories).
- **AI query**: "how much did I spend on food in Greece last summer?" over the user's data.
- **Platform polish**: home-screen widgets, OS share-sheet target ("share to Delime"),
  light/system themes alongside dark, accessibility pass, Wear OS / watch quick-add.

**Acceptance criteria.** Pro gating works and is restorable across devices; full app
localized for target locales; kitty model reconciles exactly; AI query answers from real
user data with privacy preserved; widgets/share-sheet/themes/a11y verified. Gates + CI green.

---

## 5. Cross-cutting workstreams (run continuously)

- **Testing**: keep `test/` mirroring `lib/`; every logic change ships tests; add
  backend/integration tests from Phase 3.
- **CI/CD**: keep `.github/workflows/ci.yml` green (format, analyze, no stray `print()`,
  no empty dirs, tests, release APK, no-codesign iOS). Add backend tests + (later) store
  build lanes.
- **Docs**: keep `README.md` current; add `/docs/SYNC.md` (Phase 3), `/docs/SCHEMA.md`
  (living data model), and per-phase change notes.
- **Accessibility & performance**: audit each phase; large trips/personal ledgers must
  stay smooth (paginate/virtualize lists as data grows).
- **Security & privacy**: RLS reviews each backend change; explicit consent for any data
  leaving the device; no PII in logs.

## 6. Definition of done (every phase)

1. All *Acceptance criteria* for the phase are met.
2. `scripts/quality_gates.sh` passes locally and in CI.
3. Schema migrations are forward-only, tested on populated old DBs, lossless.
4. The app builds a working release APK and a no-codesign iOS build.
5. The app remains fully usable offline and signed-out (where the phase allows).
6. `README.md` and `/docs` updated to reflect new behavior.
7. No half-finished feature is reachable in a release build (feature-flag if needed).

---

## 7. How an AI agent should use this document

- Read this whole file, then **work strictly within the lowest incomplete phase**. Do
  not pull work forward from a later phase, and do not skip foundational schema work.
- Respect every item in §1 (Guiding principles) and §2 (Architectural decisions).
- Prefer small, reviewable changes that each keep the app releasable. Land schema +
  migration + tests together.
- When a phase is genuinely complete against its Acceptance criteria and Definition of
  done, summarize what changed and stop for human review before starting the next phase.
