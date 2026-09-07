---
name: review
description: >
  Simplicity/YAGNI-focused code review and planning for this project, composed
  from two sources of truth read at runtime: vendor/ponytail (general
  over-engineering/YAGNI rules) and ../develop (this repo's own Vue/JS/CSS
  conventions). Exposes two commands: /review (diff-scoped simplicity +
  convention review, never applies fixes without confirmation) and /plan
  (pseudocode-level feature planning under the same two rulesets). Use when
  the user invokes /review or /plan, or asks to review a diff/PR/branch for
  over-engineering or convention violations, or to plan a feature before
  writing code.
---

# Review — Composed Simplicity Review & Planning

This skill does not define its own rules. It orchestrates two existing rule sets, each read
fresh at the time `/review` or `/plan` runs, so updates to either source are picked up
automatically without ever being copied here:

- **`../vendor/ponytail`** (git submodule — general YAGNI ladder, over-engineering tags,
  marker-comment convention). Canonical files: `../vendor/ponytail/AGENTS.md` and
  `../vendor/ponytail/skills/ponytail/SKILL.md` for the ladder and rules,
  `../vendor/ponytail/skills/ponytail-review/SKILL.md` for the diff-scoped tag taxonomy
  (`delete`/`stdlib`/`native`/`yagni`/`shrink`), `../vendor/ponytail/skills/ponytail-audit/SKILL.md`
  for the repo-wide variant of the same taxonomy, and `../vendor/ponytail/skills/ponytail-debt/SKILL.md`
  for the `ponytail:` marker-comment convention (a deliberate, already-justified simplification —
  don't re-flag it as a new finding). Written `../vendor/...` — sibling-relative to this skill's own
  directory, the same convention `../develop` already uses — rather than a bare `vendor/...`, because
  this skill is installed as a Junction under a global skills directory (see the repo's
  `install.ps1`), where a bare or cwd-relative path wouldn't reliably resolve.
- **`../develop`** (this repo's own skill — Vue3/JS/CSS conventions, architecture layering, naming).
  Canonical entry point: `../develop/SKILL.md`, which itself decides which `../develop/references/*.md`
  files apply to a given file.

Never copy rule text from either source into this file or into a report. Read the source files
directly each time; if their content changes, this skill's behavior changes with it.

The one exception is `references/RISK.md` — the operational low/medium/high risk criteria a finding
is scored against. That's this skill's own original content (neither ponytail nor `develop` defines
it), so it lives here rather than being invented ad hoc per report.

## `/review`

Diff-scoped review that merges ponytail's simplicity lens with `develop`'s convention lens into one
report. Never edits anything until you say so.

1. **Resolve the target.** If the request names a branch, PR, or explicit diff range, use that.
   Otherwise default to the current uncommitted changes; if there are none, diff against the
   repo's base branch — detect it (e.g. `git symbolic-ref refs/remotes/origin/HEAD`, or check which
   of `main`/`develop`/etc. actually exists) rather than assuming a name. Use `git diff` / `git log`
   to get the real changed files and hunks — never guess file names or content from memory.
2. **Trace the flow.** For each changed file, find what it imports/calls and what imports/calls it
   (grep for the file's exports and for its own import statements). Read enough of that
   surrounding code to judge whether an abstraction, parameter, or branch in the diff is actually
   used elsewhere or is speculative — a diff read in isolation can't tell the difference.
3. **Skip already-tracked debt.** If a touched line already carries a `ponytail:` marker comment
   (see `ponytail-debt`'s convention), don't raise it as a new finding — it's a deliberate,
   already-justified simplification with its own noted ceiling/upgrade path.
4. **Apply ponytail's lens.** Read `../vendor/ponytail/AGENTS.md`, `../vendor/ponytail/skills/ponytail/SKILL.md`,
   and `../vendor/ponytail/skills/ponytail-review/SKILL.md` (or `ponytail-audit/SKILL.md` instead, if the
   resolved target in step 1 is repo-wide rather than a diff). Apply the YAGNI ladder and tag
   taxonomy to the changed/touched code: unnecessary abstractions, premature generalization, unused
   flexibility, hand-rolled stdlib, dependencies duplicating a native feature, anything failing the
   ladder in `AGENTS.md`.
5. **Apply `develop`'s lens.** Follow `../develop/SKILL.md`'s own Workflow exactly as written for
   this: always read `../develop/references/GENERAL.md` first, then load only the reference files
   that `develop`'s own scoping logic (its Workflow step 3) says are relevant to the layers the
   *changed* files actually touch — never hardcode a fixed file list here, since that logic already
   lives in `develop` and may change independently of this skill. Flag violations of naming,
   architecture layering, JS/CSS style, i18n, or commit conventions.
6. **Merge into one unified report.** One entry per finding, regardless of which lens produced it:
   - File and line range.
   - Rule violated and its source — either a ponytail tag (e.g. `yagni`, `stdlib`) or a `develop`
     reference file/section (e.g. `GENERAL.md` § Explicit Conditions).
   - Evidence: why this is flagged (e.g. "this abstraction has one caller across the traced flow").
   - A concrete simplified/corrected code suggestion.
   - One line noting whether applying the fix changes behavior, and a risk level (low/medium/high)
     per the operational definitions in `references/RISK.md` — apply those criteria, don't invent
     your own low/medium/high boundary, and always include the finding-specific one-sentence reason
     `RISK.md` requires alongside the label.
7. **Never apply anything automatically.** After presenting the full report, ask explicitly whether
   to apply each fix, or all of them, and only edit files after confirmation.

## `/plan`

Pseudocode-level feature planning under the same two rulesets — no real implementation code.

1. Take the feature/task description from the request.
2. Read this project's `CLAUDE.md` (or whatever override doc `../develop/SKILL.md`'s own Workflow
   step 1 names, e.g. `PROJECT.md`) for the project's actual stack and any deliberate deviations.
3. Produce a plan down to pseudocode level — file/function structure, not real code — applying:
   - Ponytail's ladder (`../vendor/ponytail/AGENTS.md` / `../vendor/ponytail/skills/ponytail/SKILL.md`): every abstraction
     in the plan must be justified by a real, current need surfaced in the task description, never
     a speculative future one.
   - `develop`'s conventions (via `../develop/SKILL.md`'s own scoping logic, same as step 5 above):
     architecture layering, naming, file placement.
4. Do not write real implementation code in this mode — pseudocode and structure only.

## Keeping ponytail current

`vendor/ponytail` (this repository's `../vendor/ponytail` from this skill's own perspective) is a
git submodule pinned to a specific commit. Since this skill reads it at runtime rather than copying
its rules, update it independently whenever you want the latest ladder or tag taxonomy — run this
from the repository root, not from inside the installed skill directory:

```bash
git submodule update --remote vendor/ponytail
```

Commit the resulting submodule pointer bump like any other dependency update.
