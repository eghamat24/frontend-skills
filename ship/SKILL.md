---
name: ship
description: >
  Automates safe end-to-end feature delivery: plan the task via /plan, split
  it into dependency-ordered units, then for each unit checkpoint the git
  state, implement within scope, run the project's own verification commands,
  invoke /review, and triage findings by risk — low auto-applied, medium/high
  always confirmed, certain destructive operations always confirmed
  regardless of risk label. Re-verifies and re-reviews after fixes, caps each
  unit at 5 iterations, then runs a final cross-unit integration verification
  and review before reporting. Exposes a single command: /ship <task
  description>. Use when the user invokes /ship, or asks to implement a
  feature end-to-end with planning, verification, and review built in rather
  than done by hand afterward.
---

# Ship — Plan → Implement → Verify → Review Loop

This skill defines no conventions, YAGNI rules, risk criteria, or review taxonomy of its own — it
only orchestrates existing skills and adds the loop/checkpoint/safety logic below. It reads, at the
time each step runs, and never copies into this file:

- **`../develop/SKILL.md`** — coding conventions, and the project-instructions lookup (`PROJECT.md`
  or equivalent) that its Workflow step 1 already performs.
- **`../review/SKILL.md`** — both its `/review` command (diff review, composing `../develop` and
  the standalone `ponytail` plugin's rules, scored per `../review/references/RISK.md`) and its
  `/plan` command (pseudocode-level planning under the same two rulesets). `/ship` never resolves
  or reads the `ponytail` plugin itself — only `/review`/`/plan` do — so this is descriptive, not a
  path `/ship` follows.
- **`../review/references/RISK.md`** — the low/medium/high criteria `/review` scores findings
  against. `/ship` consumes the risk label `/review` returns; it does not redefine or re-derive it.
- **The target project's own verification configuration** (test runner, linter, typechecker, build
  command — e.g. `package.json` scripts, CI config) **and its `CLAUDE.md`/`PROJECT.md`** for which
  of those apply. `/ship` discovers these at runtime in whatever project it's installed into; it
  never invents or hardcodes a command.

## Flow

```text
understand task → plan → split into units
  ↓
for each unit:
    checkpoint → implement (scoped) → verify → review → triage/fix
      → re-verify → re-review → unit done
  ↓
final integration verification → final review → final summary
```

## 1. Understand & plan

Before writing any implementation code:

1. Invoke `/plan` (`../review/SKILL.md`'s `/plan` command) with the task description. `/plan` itself
   reads the project's `CLAUDE.md`/`PROJECT.md` (per `develop`'s Workflow step 1) and produces the
   pseudocode-level plan — don't redo that reading or restate its rules here, just use its output.
2. Use the plan's file/function structure to determine task units (see §2).

This ordering exists specifically to prevent premature architecture, speculative abstractions, or
any implementation before the shape of the task is actually understood.

## 2. Task decomposition

Split the task into units only when the plan reveals **multiple independently implementable and
independently verifiable components** — e.g. a backend API, a frontend data layer, a frontend UI,
an admin UI. Touching many files is not by itself a reason to split; the test is whether a piece can
be implemented and verified on its own without the others existing yet. Otherwise, treat the task as
one unit.

Order units by their real dependencies (e.g. an API before the frontend layer that calls it) and
execute them in that order.

Before implementation begins, show, per unit:

- **Name**
- **Scope** — what it does and does not include
- **Expected files/layers** touched
- **Dependencies** on previous units
- **Verification strategy** — which kinds of checks will apply (tests/lint/typecheck/build/other),
  determined in §3's step below once that unit starts, not guessed here

## 3. Per-unit loop

Run this loop for each unit, in dependency order:

**a. Git safety checkpoint.** Before touching any file for this unit: run `git status` and inspect
the current diff. Record which files are already modified going into this unit — these are
pre-existing, possibly-unrelated user changes that `/ship` must never overwrite, revert, or fold
into this unit's diff. This recorded baseline is also what §4's "no unintended files modified"
check and §6's "no unrelated files changed" check compare against. Never
run a destructive git operation (`git reset --hard`, `git checkout -- <file>`, or anything else that
discards or reverts changes) unless the user explicitly requests that exact operation.

**b. Implement, scoped.** Write the unit's code following `../develop`'s conventions — read
`../develop/references/GENERAL.md` first, then whichever other reference files `develop`'s own
Workflow says apply to the layers this unit's files touch. Stay inside the unit's declared scope
from §2. If implementation discovers that an out-of-scope file or subsystem genuinely must change,
stop and explain: which file/subsystem is outside scope, why it's required, and what behavior
depends on it — then ask whether to expand the unit's scope. Do not expand it silently. A change
that is merely convenient, speculative, cleanup, or otherwise unrelated to the unit's declared scope
never gets folded in, expansion or not.

**c. Verify.** Determine which verification commands actually apply — from the project's own
configuration and `CLAUDE.md`/`PROJECT.md`, never invented — among tests, lint, typecheck, build, or
other framework checks, scoped to what this unit's changed layers make relevant. Run them.
- Failure caused by this unit → fix it (within scope), then re-run that check.
- Failure that's unrelated or pre-existing → report it as such; do not modify unrelated code just to
  force it green.

Verification results are tracked separately from `/review` findings — never merge the two into one
list.

**d. Review.** Invoke `/review` scoped to just this unit's diff.

**e. Triage every finding `/review` returns:**

- **`risk: low`** — apply the fix automatically, no confirmation needed, *unless* it falls into a
  destructive-operation category (§5) — those always require confirmation regardless of the risk
  label `/review` assigned. Log what changed and why.
- **`risk: medium` or `risk: high`** — stop immediately. Show the full finding (file, lines, rule
  violated and its source, evidence, suggested fix, and its specific risk reason from `RISK.md`).
  Ask explicitly whether to apply it. Wait for the answer before doing anything else — don't queue
  it, don't continue to other findings or other units until this one is answered.
  - **Yes** (with or without a modification): apply as instructed, log it, resume the loop.
  - **No:** do not apply it. Record this exact finding as **seen-and-declined for this unit, for the
    remainder of this `/ship` run** — its identity is its file, line range, rule violated, and
    evidence. Resume the loop.
  - **Modified instruction:** apply what was actually instructed, log it as a modified fix (not the
    original suggestion), resume the loop.
- **Declined-finding recurrence:** if a later `/review` call in this same unit returns a finding
  matching an already-declined one's identity (same file/lines, same rule/source, same evidence)
  **unchanged**, do not re-prompt — carry it forward silently as declined. Re-prompt only when it
  has *materially* changed (different lines, different rule/evidence/reasoning) or is genuinely new.
  This tracking is scoped to the current `/ship` run for this unit only.

**f. Re-verify and re-review after fixes.** If this pass applied any fix (auto-applied low-risk, or
a confirmed medium/high fix) that touches actual logic rather than pure formatting/renaming, re-run
the verification checks from step c that are relevant to what changed — not the full suite
reflexively, and not at all if nothing meaningful changed — then re-run `/review` on the unit and
re-triage (back to step e) whatever it returns.

**g. Stopping condition.** A unit is clean once a `/review` + verification pass returns nothing that
is either auto-appliable, a failing check caused by this unit, or a new/changed finding requiring a
prompt. A previously-declined medium/high finding reappearing unchanged does not block this — it's
accepted-as-is and reported, not re-litigated. Repeat c–f until the unit reaches that state, or until
**5 iterations** (one iteration = one full c–f pass) have run for this unit, whichever comes first.
The cap is per unit — never shared or accumulated across units.

**h. Safety cap hit.** If 5 iterations pass without reaching the clean state in step g, stop looping
this unit. Show its current state and remaining (non-declined, unresolved) findings/failures, and
ask explicitly how to proceed: continue past the cap, accept the unit as-is, or abandon it. Never
loop silently past the cap.

## 4. Definition of done

**A unit** is done only when all of the following hold:
- Implementation is complete and stayed within its declared scope (any expansion was asked for and
  approved, per step b).
- Applicable verification passes, or every failing check was confirmed unrelated/pre-existing and
  recorded as such.
- `/review` has no new unresolved findings requiring action.
- Every declined finding is recorded as accepted-as-is.
- No files outside this unit's own changes were modified, per the step a checkpoint.
- The unit did not exceed the 5-iteration safety cap (or, if it did, was explicitly resolved per
  step h).

**The task** is done only after every unit meets the above, *and* the final integration phase (§6)
has run and resolved.

## 5. Destructive-operation safety (hard boundary)

Independent of whatever risk label `/review` assigns, the following always require explicit
confirmation before being applied — never treated as auto-appliable, even if `/review` scored them
low risk:

- Deleting source files that aren't provably dead, or deleting migrations.
- Dropping/removing database columns or data.
- Removing a public API endpoint.
- Removing a dependency when other usage in the codebase isn't fully established.
- Any destructive git operation.
- A broad automated rewrite spanning many files at once.
- Any irreversible data transformation.

This is a boundary `/ship` itself enforces on top of `/review`'s output, not a redefinition of
`RISK.md`'s criteria.

## 6. Final integration phase

After every unit is done:

1. Inspect the complete task diff across all units.
2. Verify no files outside the units' intended changes were modified, cross-checking against every
   unit's step-a checkpoint baseline.
3. Run the project-wide or affected-area verification appropriate to the full change (broader than
   any single unit's checks where the units' contracts meet).
4. Run `/review` once more against the complete task diff (an explicit range covering the full
   change, not the default single-unit scope).
5. Triage whatever it returns using the exact same risk rules as step 3e (low auto-applies unless
   destructive per §5, medium/high always confirmed).
6. The task is not complete until this phase is resolved — individually clean units can still
   disagree at their boundaries (e.g. a backend API unit and a frontend-integration unit that each
   passed alone but whose contracts drifted); this phase is what catches that.

## 7. Final reporting

Produce one report with these sections, never merging findings and verification results together:

**Units** — per unit: what was implemented, files/layers touched, number of review iterations,
which verification commands ran, and their result.

**Resolved** — every auto-applied low-risk fix, every confirmed medium/high fix (noting
modifications), each with file, line(s), what changed, and why.

**Declined — accepted as-is** — every declined medium/high finding, each with file, line(s), its
risk level and reason, and confirmation it was declined rather than fixed.

**Verification** — tests/lint/typecheck/build results, listed separately from review findings; any
failure marked as caused-by-this-task (and how it was fixed) or pre-existing/unrelated (and left
alone).

**Safety / scope** — whether pre-existing unrelated changes were preserved, whether every unit
stayed in scope (and whether any expansion was approved), whether any safety cap was reached.

**Final status** — exactly one of:

- `COMPLETE`
- `COMPLETE WITH DECLINED FINDINGS`
- `COMPLETE WITH PRE-EXISTING VERIFICATION FAILURES`
- `STOPPED AT SAFETY CAP`
- `ABANDONED`

## 8. Commit behavior

Never run `git commit` automatically. At the end, optionally offer a suggested commit message based
on the completed task — only execute a commit if the user explicitly asks for one.

## Constraints

- Never auto-apply a medium or high risk fix, ever, regardless of recurrence across iterations or
  units, or a prior "yes" on a similar-looking finding elsewhere.
- Never auto-apply a destructive operation (§5), regardless of the risk label `/review` assigned it.
- The 5-iteration safety cap is per unit, never global across the task.
- Never run a destructive git operation, or silently expand a unit's scope, or fold in a merely
  convenient/speculative/cleanup change.
- Never invent a verification command — only run what the project's own configuration/instructions
  establish as applicable.
- Never commit automatically.
- This skill must not reimplement `/review`'s analysis, `/plan`'s planning rules, `develop`'s
  conventions, or `RISK.md`'s criteria — only orchestrate calls to them and act on their output,
  referencing all of them by path.
