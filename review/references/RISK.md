# RISK.md — Operational Risk Levels for `/review` Findings

Every finding `/review` reports carries exactly one risk level — `low`, `medium`, or `high` — plus a
one-sentence reason specific to that finding, not just the label. "medium — merges two
similar-but-not-identical blocks; a null-handling difference may be lost" is a valid reason;
"medium" alone is not.

These levels are also what `ship`'s implement → review → fix loop reads to decide whether a fix can
be auto-applied — see `../../ship/SKILL.md`. Don't duplicate that decision logic here; this file only
defines what each level *means*.

---

## low

The change is purely structural; behavior is provably identical after the fix.

Signals:
- Removing a delegation-only wrapper (it forwards its arguments and return value with no logic of
  its own).
- Removing an interface/abstraction with exactly one implementation and no external mocks or tests
  depending on it.
- Removing genuinely unreachable or unused code (verified via the traced flow, not assumed).
- Pure renaming or formatting.
- Merging code that is byte-for-byte identical — not just similar — across the merged locations.

## medium

The change is structural but carries a real (not certain) chance of altering behavior.

Signals:
- Merging two "similar but not identical" code blocks — the risk is that a subtle intentional
  difference between them gets lost in the merge.
- Simplifying nested conditionals — the risk is that evaluation order, short-circuiting, or a rare
  branch changes.
- Removing a parameter/option that isn't obviously called from elsewhere within the diff's visible
  scope (but wasn't confirmed fully dead via the traced flow — if it were, it would be `low`).

## high

The change likely or definitely affects behavior, touches sensitive logic, or the reviewer isn't
confident in the analysis.

Signals:
- Touches validation, auth, error handling, or payment/booking/user-data logic.
- Removes a `try`/`catch`.
- The affected function/component has more than one call site in the codebase.
- No automated test covers the affected code.
- The reviewer's own analysis is inconclusive (the traced flow didn't settle whether the change is
  safe).

---

## Applying these levels

A finding earns the *highest* level any single signal above puts it at — e.g. a merge of two
similar-but-not-identical blocks that also touches auth logic is `high`, not `medium`, because the
auth signal alone qualifies it for `high`. When no signal from `medium` or `high` applies, the
finding is `low` only if it also affirmatively matches a `low` signal — the default for an
unclassified finding is never `low` by omission.
