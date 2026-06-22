# Rule: Money handling

**All monetary values are integer EUR cents.** No exceptions, no floats, no MKD storage.

- EUR is canonical. Store/compute everything in `int` cents.
- MKD is input/display only, fixed rate `Money.mkdPerEur = 61.5`. Rate never changes.
- All conversion + formatting goes through `Money` (`lib/utils/money.dart`):
  - `eurToCents(double)` / `mkdToCents(double)` — parse user input
  - `centsToEur(int)` / `centsToMkd(int)` — for display math
  - `formatEur` / `formatMkd` / `formatBoth` — display strings
- Splitting an amount across people: use `Money.splitEqually(totalCents, count)`.
  It distributes the leftover cent so parts sum **exactly** to the total
  (`1000 / 3 -> [334, 333, 333]`). Never round shares independently — that loses
  or invents cents.
- `Contribution.amountCents`, `Purchase.totalCents`, DB `amount`/`total` columns
  are all cents.

**Invariant:** a `Purchase` is valid only when
`totalCents == payersTotal == splitsTotal`. Validate before saving.
