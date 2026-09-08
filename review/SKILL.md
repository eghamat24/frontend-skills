---
name: review
description: >
  Comprehensive, evidence-driven engineering review and planning for this
  project. /review adapts its own depth to the size and risk of the change —
  there is no separate --deep/--logic/--architecture flag — and evaluates
  logic correctness, complexity, architecture, maintainability, duplication,
  performance, state/data-flow, error handling, and regression risk, not only
  bugs and convention violations. Composed from two sources of truth read at
  runtime: a bundled, self-contained copy of Ponytail's rules under ./skills/
  (simplicity/YAGNI principles that inform the review, not a separate
  competing pass) and ../develop (this repo's own Vue/JS/CSS conventions).
  /plan does pseudocode-level feature planning under the same two rulesets.
  Use when the user invokes /review or /plan, or asks to review a diff/PR/
  branch for bugs, over-engineering, architecture, maintainability, or
  convention violations, or to plan a feature before writing code.
---

# Review — Composed Engineering Review & Planning

This skill does not define its own YAGNI/simplicity or convention rules — it reads them from two
sources at the time `/review` or `/plan` runs, rather than duplicating them as prose in this file:

- **`./skills/`** — a bundled, self-contained copy of the specific Ponytail files this skill
  actually needs (general YAGNI ladder, over-engineering tags, marker-comment convention), so
  `/review` and `/plan` work even when `review` is installed on its own (e.g.
  `npx skills add ... --skill review`) with no external `vendor/` dependency alongside it.
  Canonical files: `./skills/ponytail/AGENTS.md` and `./skills/ponytail/SKILL.md` for the ladder
  and rules, `./skills/ponytail-review/SKILL.md` for the diff-scoped tag taxonomy
  (`delete`/`stdlib`/`native`/`yagni`/`shrink`), `./skills/ponytail-audit/SKILL.md` for the
  repo-wide variant of the same taxonomy, and `./skills/ponytail-debt/SKILL.md` for the
  `ponytail:` marker-comment convention (a deliberate, already-justified simplification — don't
  re-flag it as a new finding). These files are a point-in-time copy of the upstream Ponytail
  project, not a live link — see "Keeping ponytail current" for how to refresh them. They are
  supporting material for this skill only, not separate installable skills in their own right.
- **`../develop`** (this repo's own skill — Vue3/JS/CSS conventions, architecture layering, naming).
  Canonical entry point: `../develop/SKILL.md`, which itself decides which `../develop/references/*.md`
  files apply to a given file. Written sibling-relative (`../develop`, not a bare `develop`),
  because this skill is installed as a Junction/copy under a global skills directory alongside
  `develop` as its own separate top-level skill (see the repo's `install/install.ps1`), where a
  bare or cwd-relative path wouldn't reliably resolve.

**Relationship with Ponytail.** Ponytail is a guiding engineering principle woven through the
review below — prefer simplicity, avoid unnecessary abstraction and premature generalization,
follow YAGNI, reuse existing project patterns, prefer a native/simple solution when it's sufficient
— not a separate pass that competes with the engineering review or runs alongside it. When judging
complexity, architecture, duplication, or abstraction (see `/review` step 7), never recommend
additional abstraction, decomposition, indirection, or refactoring unless the traced flow shows
concrete evidence of meaningful complexity, coupling, duplication, maintenance cost, or behavioral
risk — not because a cleverer or more elegant design is theoretically possible. The goal is never
the smallest diff or fewest lines; it's the simplest maintainable implementation that correctly
solves the actual requirement. When Ponytail's own ladder flags something as unnecessarily complex,
treat that as a real engineering-quality finding. When complexity is justified — real business
rules, a framework or API constraint, required integration behavior — say so explicitly and do not
recommend simplifying it for aesthetic reasons alone.

Never copy rule text from either source into this file or into a report — read the source files
directly each time. For `develop`, that means every invocation always sees its current rules. For
the bundled Ponytail copy under `./skills/`, it means this skill's own prose never goes stale
relative to its own bundled files, but the bundle itself only updates when someone refreshes it
(again, see "Keeping ponytail current").

The one exception is `references/RISK.md` — the operational low/medium/high risk criteria a finding
is scored against. That's this skill's own original content (neither ponytail nor `develop` defines
it), so it lives here rather than being invented ad hoc per report.

## `/review`

Comprehensive, evidence-driven engineering review of the actual change — logic correctness,
complexity, architecture, maintainability, duplication, performance, state/data-flow, error
handling, and regression risk, not only bugs and convention violations. There is no separate
`--deep`/`--logic`/`--architecture` mode: `/review` itself calibrates how far to go from the size
and risk of what changed (step 2) — plain `/review` always performs whatever depth the change
actually warrants. It never edits anything until you say so.

Findings stay evidence-driven throughout, exactly as before: report something because the traced
flow, a concrete scenario, or a stated rule shows it actually matters — never because another
implementation is merely possible, because of a personal style preference, because a function
could theoretically be shorter, because an abstraction could theoretically exist, or because a
micro-optimization exists with no measurable impact. A report that flags everything imaginable is
a worse outcome than a shorter report that flags what's real.

1. **Resolve the target.** If the request names a branch, PR, or explicit diff range, use that.
   Otherwise default to the current uncommitted changes; if there are none, diff against the
   repo's base branch — detect it (e.g. `git symbolic-ref refs/remotes/origin/HEAD`, or check which
   of `main`/`develop`/etc. actually exists) rather than assuming a name. Use `git diff` / `git log`
   to get the real changed files and hunks — never guess file names or content from memory.
2. **Calibrate the depth.** Judge how far this specific change actually warrants going, from its
   real size, blast-radius, and risk — never from a flag, since there isn't one. A tiny, isolated
   change (a small utility, a single conditional, a config value) needs correctness, conventions,
   and a light complexity check, and nothing more. A medium feature needs the full logic,
   complexity, architecture, maintainability, duplication, and state/data-flow review plus
   regression analysis. A large or business-critical change (payment, auth, booking, shared state,
   data integrity) needs all of that plus end-to-end edge-case tracing, performance, and a thorough
   error-handling review. Re-calibrate mid-review if step 3's traced flow shows the change is more
   or less consequential than the diff alone suggested — depth follows evidence, not the initial
   guess.
3. **Understand before judging: trace the real flow.** Read the changed code and enough of its
   surrounding code to judge it in context. Trace its important callers and callees (grep for its
   exports and for its own import statements). Inspect related components, composables, stores,
   services, utilities, API/data models, and tests wherever the change's actual behavior depends on
   them. Build a real picture of the runtime/data flow, not just the diff's shape — a diff read in
   isolation can't tell you whether an abstraction, parameter, or branch is actually used elsewhere
   or is speculative, and it can't tell you whether five changed lines break a caller three files
   away. Compare the implementation against existing patterns already used for similar things in
   this codebase, and diff against the resolved base branch when its history matters (see step 7's
   Regression bullet).
4. **Skip already-tracked debt.** If a touched line already carries a `ponytail:` marker comment
   (see `ponytail-debt`'s convention), don't raise it as a new finding — it's a deliberate,
   already-justified simplification with its own noted ceiling/upgrade path.
5. **Apply ponytail's simplicity lens.** Read `./skills/ponytail/AGENTS.md`, `./skills/ponytail/SKILL.md`,
   and `./skills/ponytail-review/SKILL.md` (or `./skills/ponytail-audit/SKILL.md` instead, if the
   resolved target in step 1 is repo-wide rather than a diff). Apply the YAGNI ladder and tag
   taxonomy as part of judging the Complexity/Architecture/Duplication-Abstraction dimensions in
   step 7 — see "Relationship with Ponytail" above for how this fits into one engineering review
   rather than a separate pass.
6. **Apply develop's convention lens.** Follow `../develop/SKILL.md`'s own Workflow exactly as
   written for this: always read `../develop/references/GENERAL.md` first, then load only the
   reference files that `develop`'s own scoping logic (its Workflow step 3) says are relevant to
   the layers the *changed* files actually touch — never hardcode a fixed file list here, since
   that logic already lives in `develop` and may change independently of this skill. A violation of
   naming, architecture layering, JS/CSS style, i18n, or commit conventions is a `CONVENTION`
   finding (see Report format) unless it also has real behavioral impact, in which case it's a
   `BUG`/`LOGIC` finding instead — never both.
7. **Evaluate the engineering dimensions the change actually touches.** Judge every dimension below
   that the calibrated depth (step 2) and the change's actual nature make relevant — skip a
   dimension outright when it plainly doesn't apply (a pure CSS change has no logic/state
   dimension) rather than forcing a finding to fill a checklist slot. Every dimension stays subject
   to the evidence rule above: report only what the traced flow or a concrete scenario actually
   shows.
   - **Logic & correctness.** Business logic, data transformations, calculations, conditionals,
     state transitions, filtering/sorting, accumulation/reduction, null/undefined handling, empty
     states, multiple-item scenarios, partial/missing data, duplicated values, overwriting previous
     state, async behavior, API/data-shape assumptions, and consistency between related
     components/services. For anything non-trivial, reason through concrete scenarios — single
     item, multiple items, empty input, null input, zero values, mixed configurations, previous
     state + new state — and show the actual path through the code. Never conclude that logic
     "looks correct" without demonstrating it against a real path or scenario.
   - **Complexity.** Cognitive: deeply nested conditions, excessive branching, complicated boolean
     expressions, hard-to-follow control flow, a function doing too many things. Algorithmic:
     unnecessary O(n²) behavior, repeated traversals, unnecessary sorting, repeated expensive
     calculations — only when the impact is real, not theoretical. Structural: too many
     responsibilities in one function/component, an oversized service, unnecessary intermediate
     transformations or layers. Ask both directions: is this more complicated than the problem
     requires, and — just as important — has it been oversimplified into something fragile or
     incorrect? Complexity reflecting real business rules, necessary edge cases, or framework/API
     constraints is justified, not a finding. For a significant function/component/service, state
     `Complexity: LOW/MEDIUM/HIGH` with a one-line evidence-based reason — reasoning internally
     first (what's the simplest reasonable implementation; is the current one close to it; what
     complexity here is necessary vs. unnecessary; is any abstraction premature; is anything
     duplicated unnecessarily) and surfacing that reasoning in the report only when it leads to a
     meaningful conclusion, not as a mandatory rating for every function touched.
   - **Architecture.** Whether responsibilities sit in the right layer per `develop`'s own
     architecture (component vs. composable, composable vs. store, store vs. service, service vs.
     utility), business logic leaking into UI, UI concerns leaking into services, inappropriate
     shared state, excessive coupling, low cohesion, circular dependencies, duplicated business
     rules across layers. Whether the change introduces a new pattern when an existing project
     pattern already solves the problem, and whether a new abstraction is actually earning its
     place or is premature. Never recommend additional abstraction, decomposition, or indirection
     just to remove a small amount of duplication.
   - **Maintainability.** How easy this will be to change six months from now: clarity of
     responsibility, naming, hidden assumptions, fragile contracts, implicit behavior, duplicated
     business rules, magic values, hard-to-follow transformations, coupling between unrelated parts
     of the system. Flag specifically where a future developer could plausibly make an incorrect
     change because the intent isn't clear from the code itself.
   - **Duplication & abstraction.** Distinguish harmless repetition from duplicated business logic,
     state rules, or calculations — only the latter is worth an abstraction, and only when it
     actually improves the design. Just as much, flag over-abstraction: helper layers with no
     meaningful behavior, wrappers used only once, premature generalization, configuration added
     for a hypothetical future requirement. Prefer the simplest design that correctly solves the
     actual requirement.
   - **Performance** (when relevant to what changed). Unnecessary renders, watchers, or computed
     recalculations; repeated API requests; repeated array traversals; expensive object cloning or
     transformations; unnecessary DOM work; algorithmic complexity that won't scale as input grows.
     Never report a micro-optimization with no meaningful impact.
   - **State & data-flow.** Ownership of state, prop mutation, derived vs. stored state,
     synchronization between components, stale state, race conditions, state leakage, accidental
     mutation, reference-identity assumptions, state that can become inconsistent. Pay particular
     attention to logic that only works today because two parts of the app happen to share the same
     object reference.
   - **Error handling & failure paths.** API failures, unexpected response shapes,
     null/undefined/partial/empty data, rejected promises, failed state transitions, silent
     failures, inconsistent UI state after a failure. Flag a missing handler only when the failure
     can meaningfully affect behavior.
   - **Regression / base-branch analysis.** Using the base-branch diff from steps 1/3: check
     whether the base branch contains a newer fix this branch reintroduces a bug around, overwrites,
     or duplicates differently, and whether any behavior changed unintentionally relative to it.
     Never assume the base branch is automatically correct — use it as evidence, then verify the
     actual behavior yourself.
   - **Scope & change quality.** Whether the change is appropriately scoped, whether unrelated code
     was touched, whether refactoring was introduced that the task didn't call for, whether the
     diff is larger than the change needs to be, whether an existing project abstraction was
     bypassed without reason, and whether the implementation follows established project patterns.
8. **Produce one unified report.** One entry per finding, regardless of which lens or dimension
   produced it — see **Report format** below for the exact schema. A `BUG` or `LOGIC` finding both
   mean behavior is or can be incorrect — use `BUG` for a confirmed, reproducible instance and
   `LOGIC` for a correctness defect in the reasoning/design that risks producing one (e.g. an
   assumption about upstream data shape that isn't actually guaranteed). An engineering-quality
   finding (`COMPLEXITY`/`ARCHITECTURE`/`MAINTAINABILITY`/`PERFORMANCE`/`DUPLICATION`/`ABSTRACTION`/
   `STATE`/`SCALABILITY`) means the implementation works but has a meaningful cost. A `CONVENTION`
   finding means a project rule is violated with no meaningful behavioral impact. A `REGRESSION`
   finding is the base-branch-comparison variant of `BUG`/`LOGIC` — behavior that was correct on the
   base branch and is now wrong, reintroduced, or unintentionally overwritten. Never mix these —
   pick the one that actually describes the finding, never inflate a style preference into any of
   them.
9. **Never apply anything automatically.** After presenting the full report, ask explicitly whether
   to apply each fix, or all of them, and only edit files after confirmation.

### Report format

Every individual finding:
- **File and line range.**
- **Category** — one of `BUG`, `LOGIC`, `COMPLEXITY`, `ARCHITECTURE`, `MAINTAINABILITY`,
  `PERFORMANCE`, `DUPLICATION`, `ABSTRACTION`, `STATE`, `ERROR-HANDLING`, `SCALABILITY`,
  `CONVENTION`, `REGRESSION`.
- **Severity** — `CRITICAL` / `HIGH` / `MEDIUM` / `LOW` — how much this finding matters,
  engineering-wise.
- **Rule or principle violated, and its source** — a ponytail tag (e.g. `yagni`, `stdlib`), a
  `develop` reference file/section (e.g. `GENERAL.md` § Explicit Conditions), or, for a
  `BUG`/`LOGIC`/`STATE`/`ERROR-HANDLING`/`PERFORMANCE` finding with no written rule behind it, the
  concrete scenario or traced-flow reasoning that surfaced it.
- **Evidence** — why this is flagged, grounded in the actual traced code (e.g. "this abstraction
  has one caller across the traced flow"; "with an empty `items` array this reduces over nothing
  and returns the wrong default").
- **Why it matters.**
- **Concrete scenario**, when applicable — especially for `LOGIC` findings, walk the actual
  input/state through the code (single item, multiple items, empty, null, zero, mixed, previous +
  new state) rather than asserting a conclusion.
- **Recommended fix** — concrete, not "consider refactoring this."
- **Merge-blocking** — yes/no.
- **Risk level** (`low`/`medium`/`high`, per `references/RISK.md`'s operational criteria) plus its
  required one-sentence, finding-specific reason. This is a separate axis from Severity above:
  Severity is how much the finding matters; Risk is whether *applying the fix* is likely to change
  behavior. `ship`'s implement → review → fix loop reads this field to decide whether a fix can be
  auto-applied — never invent your own scale here, and never omit it.

Close every report with these two summaries, always present even when there are zero findings — a
clean, trivial change still gets a fast, honest `MERGE` verdict, not extra analysis work:

**Engineering Assessment**
```
Logic correctness: HIGH / MEDIUM / LOW
Complexity: LOW / MEDIUM / HIGH
Architecture: GOOD / FAIR / POOR
Maintainability: GOOD / FAIR / POOR
Performance: GOOD / FAIR / POOR / NOT RELEVANT
Technical debt introduced: NONE / LOW / MEDIUM / HIGH
```
- **What is good** — the strongest aspects of the implementation, stated plainly. A review that
  only criticizes is an incomplete review.
- **What should change** — the findings above, in priority order.
- **What can be left as-is** — acceptable complexity or existing patterns that should explicitly
  *not* be refactored just because they could theoretically be different. This is what keeps step
  7's Architecture/Duplication guidance from silently drifting into "recommend refactoring
  everything."

**Final recommendation**
```
Implementation quality: POOR / FAIR / GOOD / VERY GOOD / EXCELLENT
Logic correctness: LOW / MEDIUM / HIGH
Complexity: LOW / MEDIUM / HIGH
Maintainability: LOW / MEDIUM / HIGH
Architecture: LOW / MEDIUM / HIGH
Technical debt: NONE / LOW / MEDIUM / HIGH
Merge recommendation: MERGE / MERGE AFTER FIXES / NEEDS REWORK / DO NOT MERGE
```

## `/plan`

Pseudocode-level feature planning under the same two rulesets — no real implementation code.

1. Take the feature/task description from the request.
2. Read this project's `CLAUDE.md` (or whatever override doc `../develop/SKILL.md`'s own Workflow
   step 1 names, e.g. `PROJECT.md`) for the project's actual stack and any deliberate deviations.
3. Produce a plan down to pseudocode level — file/function structure, not real code — applying:
   - Ponytail's ladder (`./skills/ponytail/AGENTS.md` / `./skills/ponytail/SKILL.md`): every abstraction
     in the plan must be justified by a real, current need surfaced in the task description, never
     a speculative future one.
   - `develop`'s conventions (via `../develop/SKILL.md`'s own scoping logic, same as `/review`'s
     step 6 above): architecture layering, naming, file placement.
4. Do not write real implementation code in this mode — pseudocode and structure only.

## Keeping ponytail current

`./skills/` is a vendored, point-in-time copy of five files from the upstream
[Ponytail](https://github.com/DietrichGebert/ponytail) project — not a live link, so it does not
update on its own. This is a deliberate trade-off: it's what makes `review` installable on its own
(`npx skills add ... --skill review`, with no sibling `vendor/` directory required), at the cost of
needing a manual refresh step to pick up upstream changes.

The repository root's `vendor/ponytail` git submodule remains the upstream source these files are
refreshed from (see the repo root's own README for why it's kept). To refresh, from the repository
root — not from inside an installed `review` skill directory:

```bash
git submodule update --remote vendor/ponytail
cp vendor/ponytail/AGENTS.md                          review/skills/ponytail/AGENTS.md
cp vendor/ponytail/skills/ponytail/SKILL.md            review/skills/ponytail/SKILL.md
cp vendor/ponytail/skills/ponytail-review/SKILL.md     review/skills/ponytail-review/SKILL.md
cp vendor/ponytail/skills/ponytail-audit/SKILL.md      review/skills/ponytail-audit/SKILL.md
cp vendor/ponytail/skills/ponytail-debt/SKILL.md       review/skills/ponytail-debt/SKILL.md
```

Then diff `review/skills/` to see exactly what changed upstream, and commit the submodule pointer
bump together with the refreshed copies as one dependency-update commit.
