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
│   └── references/
│       └── RISK.md
│
├── ship/
│   └── SKILL.md
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

Simplicity/YAGNI-focused code review and planning, composed from two sources: the standalone
[Ponytail](https://github.com/DietrichGebert/ponytail) Claude Code plugin (general
over-engineering/YAGNI rules, read from the plugin's installed files at runtime) and this repo's
own `develop` skill (project-specific conventions). **Requires the `ponytail` plugin to be
installed separately** — `/plugin install ponytail@ponytail` — it is a runtime peer-dependency, not
a bundled copy, so `review` is no longer self-contained. See `review/SKILL.md` (its "Locating the
ponytail plugin" section explains how its files are found at runtime) and
`review/references/RISK.md` for the operational low/medium/high risk criteria every finding is
scored against.

### Prerequisites

- The [`ponytail`](https://github.com/DietrichGebert/ponytail) Claude Code plugin, installed via
  `/plugin install ponytail@ponytail`, is required at runtime by `review` (and therefore `ship`,
  which calls `/review`). Without it, `/review` and `/plan` stop and ask you to install it rather
  than falling back to any local copy.

### `ship`

Automates the implement → review → fix loop for a task, unit by unit: implements per `develop`'s
conventions, reviews via `/review`, auto-applies low-risk fixes, and always stops to confirm before
applying a medium/high-risk fix. See `ship/SKILL.md`.

## Global Installation (Windows)

Instead of installing skills into each project individually, you can link this entire repository
into Claude Code's global skills directory once, and use `/plan`, `/review`, and `/ship` from every
project on the machine. This works by creating Windows directory Junctions from
`$HOME\.claude\skills\<name>` to the corresponding directory in this repository — nothing is
copied, so this repository stays the single source of truth: any edit here takes effect
immediately, everywhere, with no re-installation step.

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
