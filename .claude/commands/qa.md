---
description: Run the full Delime quality-gate suite (format, analyze, print check, empty dirs, tests)
---

Run `bash scripts/quality_gates.sh` and report the result.

If any gate fails:
- Show the relevant failing output.
- For format failures, run `dart format lib/ test/` and re-run the gates.
- For analyze failures (`--fatal-infos --fatal-warnings`), fix each info/warning
  surgically — do not suppress lints unless asked.
- For test failures, fix the code or the test per the actual intent; never delete
  a test to make the gate pass.

Do not commit or push unless explicitly asked.
