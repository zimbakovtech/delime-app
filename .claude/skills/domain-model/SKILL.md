---
name: domain-model
description: Reference for Delime's domain — people, purchases, payers vs splits, balances, and the greedy settlement algorithm. Load before changing money math, settlement logic, or the data model.
---

# Delime domain model

## Entities

- **Person** — `id` (uuid), `name`, `colorValue` (avatar colour, int ARGB).
  Colour auto-assigned via `AvatarPalette.suggestColorValue(used)` to avoid clashes.
- **Purchase** — a named expense. `totalCents`, `createdAt` (epoch millis), plus
  two contribution lists:
  - **payers** — who actually handed over money, and how much each paid.
  - **splits** — who the cost is divided among, and each person's share.
- **Contribution** — `{ personId, amountCents }`. Used for both payers and splits.
- **Balance** (derived) — per person: `paidCents`, `owedCents`, `netCents = paid - owed`.
- **Settlement** (derived) — `{ fromPersonId, toPersonId, amountCents }`: one payment.

## Hard invariant

A purchase is valid only when:

```
totalCents == sum(payers.amountCents) == sum(splits.amountCents)
```

Payers and splits are independent — one person can pay €30 while the cost splits
4 ways. Use `Purchase.payersTotal` / `splitsTotal` to check.

## Money

Everything is **integer EUR cents**. See `.claude/rules/money.md`. Split shares
with `Money.splitEqually` so cents never leak.

## Balances → settlements

`SettlementService` (pure, `lib/services/settlement_service.dart`):

1. `computeBalances(people, purchases)` — sums each person's paid and owed across
   all purchases. Net positive = creditor (is owed); net negative = debtor (owes).
2. `computeSettlements(balances)` — **greedy minimum-transaction**: repeatedly
   match the biggest creditor with the biggest debtor, settle `min(their amounts)`,
   drop whoever hits zero. Loops until all balanced.

Properties to preserve / test:
- Sum of all `netCents` is always 0 (closed system).
- After settlement, every balance is zeroed.
- Greedy gives few transactions but not provably minimal for all inputs — that's
  the accepted tradeoff. Don't "optimize" it without a spec + tests.

These are recomputed on demand via `AppState.balances` / `AppState.settlements` —
never stored.
