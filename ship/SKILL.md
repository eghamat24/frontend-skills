---
name: ship
description: >
  Automates safe end-to-end feature delivery: preflight the project, plan the
  task via the review skill's /plan, confirm behaviour-changing decisions,
  split it into dependency-ordered units, then for each unit checkpoint the
  git state, implement within scope, run the project's own verification
  commands, verify the task's acceptance criteria, run /review in a fresh
  subagent, and triage findings by risk — low auto-applied, medium/high
  always confirmed, certain destructive operations always confirmed
  regardless of risk label. Re-verifies and re-reviews the fix delta, caps
  each unit at 3 iterations, then runs a final cross-unit integration
  verification and review before reporting. Exposes a single command:
  /ship <task description>. Use when the user invokes /ship, or asks to
  implement a feature end-to-end with planning, verification, and review
  built in rather than done by hand afterward.
---

# Ship — Plan → Implement → Verify → Review Loop

This skill defines no conventions, YAGNI rules, risk criteria, or review taxonomy of its own — it
only orchestrates existing skills and adds the loop/checkpoint/safety logic below. It reads, at the
time each step runs, and never copies into this file:

- **`../develop/SKILL.md`** — coding conventions.
- **`../review/SKILL.md`** — both its `/review` command (diff review, composing `../develop` and
  the standalone `ponytail` plugin's rules, scored per `../review/references/RISK.md`) and its
  `/plan` command. `/plan` is a *section* of the `review` skill, not a registered skill of its own —
  see §1 for how to invoke it concretely.
- **`../review/references/RISK.md`** — the low/medium/high criteria `/review` scores findings
  against. `/ship` consumes the risk label `/review` returns; it does not redefine or re-derive it.
- **The target project's own verification configuration** (test runner, linter, typechecker, build
  command — e.g. `package.json` scripts, CI config) **and its project-instruction docs** (§0). `/ship`
  discovers these at runtime in whatever project it's installed into; it never invents or hardcodes
  a command.

**Every step that says "invoke" means a real tool call** (Skill tool or Agent tool, as specified).
Never replace one with an inline, shortened, or from-memory version. If the tool call isn't
available, stop and say so rather than improvising.

## Flow

```text
preflight → plan → clarification gate → split into units
  ↓
for each unit:
    checkpoint → implement (scoped) → diff sanity → verify → acceptance check
      → review (subagent) → triage/fix → re-verify → re-review delta → unit done
  ↓
final integration verification → final review (subagent) → report
```

## 0. Preflight (once per `/ship` run)

Before planning, gather everything the loop will need, so nothing is discovered mid-unit:

1. **Project-instruction docs.** Read every `CLAUDE.md`, `PROJECT.md`, and `AGENTS.md` from the repo
   root down to the directory of each file the task is likely to touch (nested apps, e.g.
   `new/CLAUDE.md`, count). Nearer files win over farther ones, and all of them win over `develop`.
   Also load any task-specific checklist/guide the project provides (e.g. a migration guide under
   `docs/`) — it feeds §3d.
2. **Verification commands.** List the applicable ones from the project's config and instruction
   docs (tests, lint, typecheck, build, other). Dry-run each once. Record any that are missing or
   broken (e.g. a lint script with an invalid flag, a repo with no `test` script) as **unavailable**
   — don't fix them, don't invent replacements.
3. **Conventions.** Read `../develop/SKILL.md` and `../develop/references/GENERAL.md` once, plus the
   layer references `develop`'s Workflow says apply to the expected layers. These stay loaded for
   the rest of the run; re-read a reference only if it changes on disk or a unit touches a layer
   not yet loaded.
4. **Review dependency.** Confirm the `ponytail` plugin resolves per `../review/SKILL.md`'s
   "Locating the ponytail plugin". If it doesn't, stop and tell the user to install it.

Report preflight as a short block (≤4 lines): docs read, checks available/unavailable, conventions
loaded, ponytail resolved.

## 1. Plan

Call the **Skill tool** with `skill: "review"` and `args: "plan: <task description>"`, then follow
its `/plan` section exactly. Do not write an inline plan instead. Pass along the preflight findings
(instruction docs, task checklist) so `/plan` doesn't redo that reading.

This ordering exists to prevent premature architecture, speculative abstractions, or any
implementation before the shape of the task is actually understood.

## 2. Clarification gate & task decomposition

**Clarification gate.** From the plan, list every decision that **changes observable behaviour or
conflicts with a project rule** (e.g. diverging from a legacy quirk, picking an id/endpoint the
task doesn't specify, a UI choice that contradicts the project's `CLAUDE.md`). If any exist, ask
about all of them together in one question block before implementing. If none exist, continue
without pausing. Decisions made later without asking must be listed in the report (§7).

**Decomposition.** Split the task into units only when the plan reveals **multiple independently
implementable and independently verifiable components** — e.g. a backend API, a frontend data
layer, a frontend UI, an admin UI. Touching many files is not by itself a reason to split; the test
is whether a piece can be implemented and verified on its own without the others existing yet.
Otherwise, treat the task as one unit.

Order units by their real dependencies (e.g. an API before the frontend layer that calls it) and
execute them in that order.

Before implementation begins, show, per unit:

- **Name**
- **Scope** — what it does and does not include
- **Expected files/layers** touched
- **Dependencies** on previous units
- **Verification strategy** — which preflight checks apply, and the acceptance checklist (§3d)

## 3. Per-unit loop

Run this loop for each unit, in dependency order:

**a. Git safety checkpoint.** Before touching any file for this unit: run `git status` and inspect
the current diff. Record which files are already modified going into this unit — these are
pre-existing, possibly-unrelated user changes that `/ship` must never overwrite, revert, or fold
into this unit's diff. This recorded baseline is also what §4's "no unintended files modified"
check and §6's "no unrelated files changed" check compare against. Never run a destructive git
operation (`git reset --hard`, `git checkout -- <file>`, or anything else that discards or reverts
changes) unless the user explicitly requests that exact operation.

**b. Implement, scoped.** Write the unit's code following the conventions loaded in preflight, with
project-instruction docs taking precedence. Stay inside the unit's declared scope from §2. If
implementation discovers that an out-of-scope file or subsystem genuinely must change, stop and
explain: which file/subsystem is outside scope, why it's required, and what behavior depends on it
— then ask whether to expand the unit's scope. Do not expand it silently. A change that is merely
convenient, speculative, cleanup, or otherwise unrelated to the unit's declared scope never gets
folded in, expansion or not.

**Diff sanity.** After implementing, run `git diff --stat`. Flag any file whose changed-line count
is far out of proportion to the intended edit (line-ending churn, a formatter rewriting the whole
file) and fix it before verifying — a 6-line change must not show up as 1500 lines.

**c. Verify.** Run the preflight checks relevant to this unit's changed layers.
- Failure caused by this unit → fix it (within scope), then re-run that check.
- Failure that's unrelated or pre-existing → report it as such; do not modify unrelated code just to
  force it green.
- Unavailable checks (from preflight) → report as unavailable, don't skip silently.

Verification results are tracked separately from `/review` findings — never merge the two into one
list.

**d. Acceptance check.** A passing build is not evidence the task is done. Derive a checklist of
what the task actually requires and check each item with evidence:
- Use the project's own checklist/guide from preflight when one exists.
- For a migration/port, "same style and logic" is the requirement: legacy user-facing strings
  verbatim, same endpoints and params, same validation rules and triggers, same state resets and
  interactions, and every style value (font sizes, paddings, radii, colors) matched against the
  legacy source or its computed CSS.
- Check by grep/diff against the legacy code, and in the browser (e.g. `chrome-devtools`
  `get_css_styles` on legacy vs. new) when one is available.
- Any item that can't be checked (login required, no browser, no backend) is marked
  **UNVERIFIED** with the reason — never silently skipped or reported as passing.

A failed item caused by this unit is fixed within scope, like a failing check in step c.

**e. Review — in a fresh subagent.** Launch a `general-purpose` subagent via the **Agent tool**.
Give it only: the unit's diff range (or file list if uncommitted), the task statement, the
project-instruction doc paths from preflight, and this instruction:

> Load `<abs path>/review/SKILL.md` and run its `/review` command on this range exactly as written.
> Return findings in its report schema, each with its `RISK.md` label. Do not edit any files; stop
> after the report — `/ship` decides what gets applied.

Never replace this with a self-review in the main context — the author reviewing its own code in
the same context misses what a fresh reviewer catches.

**f. Triage every finding the review returns:**

- **`risk: low`** — apply the fix automatically, no confirmation needed, *unless* it falls into a
  destructive-operation category (§5) — those always require confirmation regardless of the risk
  label `/review` assigned. Log what changed and why.
- **`risk: medium` or `risk: high`** — stop. Show the full finding (file, lines, rule violated and
  its source, evidence, suggested fix, and its specific risk reason from `RISK.md`). If several
  medium/high findings came back in the same review, present them together in one question block
  and ask per finding. Wait for the answers before doing anything else.
  - **Yes** (with or without a modification): apply as instructed, log it, resume the loop.
  - **No:** do not apply it. Record it as **seen-and-declined for this unit, for the remainder of
    this `/ship` run**. Its identity is **file + symbol (function/component) + rule + evidence
    summary** — line numbers are a hint only, since other fixes shift them.
  - **Modified instruction:** apply what was actually instructed, log it as a modified fix (not the
    original suggestion), resume the loop.
- **Declined-finding recurrence:** if a later review in this same unit returns a finding matching
  an already-declined one's identity **unchanged** (same file, symbol, rule, and evidence — even if
  its lines moved), do not re-prompt — carry it forward silently as declined. Re-prompt only when
  it has *materially* changed (different symbol, rule, evidence, or reasoning) or is genuinely new.

**g. Re-verify and re-review the delta.** If this pass applied any fix that touches actual logic
rather than pure formatting/renaming, re-run the step-c checks and step-d items relevant to what
changed — not the full suite reflexively, and not at all if nothing meaningful changed. Then run a
subagent review (step e) scoped to **the fix delta only**, plus any finding marked "needs
re-check", and re-triage (step f).

**h. Stopping condition.** A unit is clean once a verify + review pass returns nothing that is
either auto-appliable, a failing check or acceptance item caused by this unit, or a new/changed
finding requiring a prompt. A previously-declined finding reappearing unchanged does not block this.
Repeat c–g until the unit is clean, or until **3 iterations** (one iteration = one full c–g pass)
have run for this unit. Also stop early if an iteration's review produces only findings that
restate earlier ones. The cap is per unit — never shared or accumulated across units.

**i. Safety cap hit.** If 3 iterations pass without reaching the clean state, stop looping this
unit. Show its current state and remaining (non-declined, unresolved) findings/failures, and ask
explicitly how to proceed: continue past the cap, accept the unit as-is, or abandon it. Never loop
silently past the cap.

## 4. Definition of done

**A unit** is done only when all of the following hold:
- Implementation is complete and stayed within its declared scope (any expansion was asked for and
  approved, per step b), and the diff-sanity check passed.
- Applicable verification passes, or every failing check was confirmed unrelated/pre-existing and
  recorded as such.
- Every acceptance item passes or is reported as UNVERIFIED with a reason.
- The review has no new unresolved findings requiring action.
- Every declined finding is recorded as accepted-as-is.
- No files outside this unit's own changes were modified, per the step-a checkpoint.
- The unit did not exceed the 3-iteration safety cap (or, if it did, was explicitly resolved per
  step i).

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

1. Inspect the complete task diff across all units, and run the diff-sanity check on it.
2. Verify no files outside the units' intended changes were modified, cross-checking against every
   unit's step-a checkpoint baseline.
3. Run the project-wide or affected-area verification appropriate to the full change (broader than
   any single unit's checks where the units' contracts meet), and re-check any acceptance item that
   spans units.
4. Run a subagent review (step e) against the complete task diff — an explicit range covering the
   full change, not a single unit. This step is mandatory; it is never skipped.
5. Triage whatever it returns using the exact same rules as step 3f.
6. The task is not complete until this phase is resolved — individually clean units can still
   disagree at their boundaries (e.g. a backend API unit and a frontend-integration unit that each
   passed alone but whose contracts drifted); this phase is what catches that.

## 7. Final reporting

Use exactly this template. Keep every line; write "none" for an empty one. Never merge findings and
verification results.

```markdown
## /ship report: <task>
**Status:** COMPLETE | COMPLETE WITH DECLINED FINDINGS | COMPLETE WITH PRE-EXISTING VERIFICATION FAILURES | COMPLETE WITH UNVERIFIED ACCEPTANCE ITEMS | STOPPED AT SAFETY CAP | ABANDONED  (pick one)

**Units:** <name>: files … | iterations N | checks: build ✅ lint ⚠️ pre-existing · test ⛔ unavailable
**Acceptance:** ✅ <item> · ✅ <item> · ⚠️ UNVERIFIED <item> (<reason>)
**Resolved:** <file:line>: <what> (low/auto | confirmed | modified)
**Declined:** <file:symbol>: <risk>: <reason>
**Decisions made:** <judgement calls not asked at the clarification gate, esp. ones differing from legacy/project rules>
**Scope/safety:** baseline preserved ✅ · scope expansions: none · cap reached: no
**Suggested commit:** <message>
```

When more than one status applies, pick the first in the list above that is true.

## 8. Commit behavior

Never run `git commit` automatically. The suggested commit message uses the user's `commit` skill
format if one is installed, otherwise the project's own convention (its instruction docs or recent
`git log`), otherwise `../develop/references/COMMIT.md`. Only execute a commit if the user
explicitly asks for one.

## Constraints

- Never auto-apply a medium or high risk fix, ever, regardless of recurrence across iterations or
  units, or a prior "yes" on a similar-looking finding elsewhere.
- Never auto-apply a destructive operation (§5), regardless of the risk label `/review` assigned it.
- The 3-iteration safety cap is per unit, never global across the task.
- Never run a destructive git operation, or silently expand a unit's scope, or fold in a merely
  convenient/speculative/cleanup change.
- Never invent a verification command — only run what the project's own configuration/instructions
  establish as applicable.
- Never replace a Skill/Agent invocation (`/plan`, per-unit review, final review) with an inline
  version, and never report an unchecked acceptance item as passing.
- Never commit automatically.
- This skill must not reimplement `/review`'s analysis, `/plan`'s planning rules, `develop`'s
  conventions, or `RISK.md`'s criteria — only orchestrate calls to them and act on their output,
  referencing all of them by path.
