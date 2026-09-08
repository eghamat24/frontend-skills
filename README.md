# frontend-skills

Reusable frontend engineering conventions for AI coding agents, packaged as portable [Agent Skills](https://agentskills.io/).

This repository contains frontend development rules as installable Skills that can be used across compatible coding agents and projects.

## Structure

```text
frontend-skills/
│
├── install/
│   ├── install.ps1
│   ├── uninstall.ps1
│   └── status.ps1
│
├── develop/
│   ├── SKILL.md
│   └── references/
│       ├── GENERAL.md
│       ├── REPOSITORY.md
│       ├── SERVICE.md
│       ├── STORE.md
│       ├── COMPONENT.md
│       ├── VIEW.md
│       ├── COMPOSABLE.md
│       ├── ...
│
├── review/
│   ├── SKILL.md
│   ├── references/
│   │   └── RISK.md
│   └── skills/                     (bundled, self-contained copy of the Ponytail files
│       ├── ponytail/                this skill needs — not separate installable skills)
│       ├── ponytail-review/
│       ├── ponytail-audit/
│       └── ponytail-debt/
│
├── ship/
│   └── SKILL.md
│
├── vendor/
│   └── ponytail/   (git submodule — dev-time only, used to refresh review/skills/; see
│                     review/SKILL.md's "Keeping ponytail current")
│
├── README.md
└── LICENSE
```

Each top-level directory is an independently installable Skill.

## Skills

### `develop`

Frontend development conventions covering architecture, code style, naming, components, state management, styling, localization, and other project-level development practices.

The Skill uses `SKILL.md` as its entry point and `references/` for detailed rules.

### `review`

Simplicity/YAGNI-focused code review and planning, composed from two sources: a bundled,
self-contained copy of [Ponytail](https://github.com/DietrichGebert/ponytail)'s rules under
`review/skills/` (general over-engineering/YAGNI rules) and this repo's own `develop` skill
(project-specific conventions). Fully self-contained — installable on its own with
`npx skills add ... --skill review`, with no external `vendor/` dependency required at runtime. See
`review/SKILL.md` (its "Keeping ponytail current" section explains how the bundled copy is
refreshed) and `review/references/RISK.md` for the operational low/medium/high risk criteria every
finding is scored against.

### `ship`

Automates the implement → review → fix loop for a task, unit by unit: implements per `develop`'s
conventions, reviews via `/review`, auto-applies low-risk fixes, and always stops to confirm before
applying a medium/high-risk fix. See `ship/SKILL.md`.

## Submodules

This repo uses a git submodule (`vendor/ponytail`) as the upstream reference the `review` skill's
bundled `review/skills/` copy is periodically refreshed from (see `review/SKILL.md`'s "Keeping
ponytail current"). It is a **dev-time-only** dependency — `develop`, `review`, and `ship` all work
correctly, including via the global installer below, without it being initialized. You only need it
if you plan to refresh `review/skills/` from upstream Ponytail yourself:

```bash
git clone --recurse-submodules https://github.com/eghamat24/frontend-skills
```

If you already cloned without that flag, run:

```bash
git submodule update --init --recursive
```

## Global Installation (Windows)

Instead of installing skills into each project individually, you can link this entire repository
into Claude Code's global skills directory once, and use `/plan`, `/review`, and `/ship` from every
project on the machine. This works by creating Windows directory Junctions from
`$HOME\.claude\skills\<name>` to the corresponding directory in this repository — nothing is
copied, so this repository stays the single source of truth: any edit here takes effect
immediately, everywhere, with no re-installation step. (Refreshing `review`'s bundled Ponytail copy
under `review/skills/` is the one exception — that's a deliberate point-in-time copy, not a live
link; see `review/SKILL.md`'s "Keeping ponytail current".)

### Install

```powershell
.\install\install.ps1
```

Creates a Junction for each skill (`develop`, `review`, `ship`). Safe to run more than once — an
existing, correct Junction is left alone and reported as already installed. If a real
(non-Junction) directory or file already exists at one of these names, installation stops for that
entry and reports the conflict instead of touching it.

### Check status

```powershell
.\install\status.ps1
```

Read-only: reports whether each Junction exists, actually is a Junction, points at this repository,
and (for `develop`/`review`/`ship`) has a `SKILL.md`.

### Uninstall

```powershell
.\install\uninstall.ps1
```

Removes only the Junctions `install.ps1` created. It never deletes this repository — a Junction is
just a pointer, and removal is non-recursive, so only the pointer is removed and the real directory
it pointed to is untouched either way. Safe to run more than once.

All three scripts determine the repository root as the parent of their own folder (via
`$PSScriptRoot`) — no path in them is machine- or user-specific, so this works regardless of where
you clone the repository, as long as the three scripts stay together in `install/`. Neither script
requires Administrator privileges (directory Junctions are a normal-user NTFS feature), and neither
ever commits, modifies `SKILL.md`/`CLAUDE.md`, or touches a project's own `.claude/skills`.

You do not need to copy these skills into individual projects, and per-project installation (below)
remains available for non-Windows machines or when you want a project pinned to a specific version
of these skills instead of always tracking this repository's current state.

## Installation

Install the `develop` Skill into your project:

```bash
npx skills add https://github.com/eghamat24/frontend-skills --skill develop
```

To install all available Skills:

```bash
npx skills add https://github.com/eghamat24/frontend-skills
```

You can replace the repository URL with your own fork.

## Adding a Skill

Add a new top-level directory containing a `SKILL.md` and, optionally, a `references/` directory:

```text
<skill-name>/
├── SKILL.md
└── references/
```

Keep `SKILL.md` focused on the Skill's purpose, workflow, and instructions. Put detailed rules and supporting documentation in `references/`.
