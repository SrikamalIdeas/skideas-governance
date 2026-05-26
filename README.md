# skideas-governance

Shared SDLC governance for all SrikamalIdeas projects.

This repository is the **single source of truth** for:
- Engineering constitution (principles, workflow gates, quality standards)
- Speckit agents (orchestrator + all lifecycle agents)
- Spec / plan / tasks / checklist templates
- Preflight validation scripts
- Speckit extension configs

---

## Why this exists

Every SKIdeas project (heysiaai, skideas-common-core, future services) used to maintain its
own copy of the SDLC governance files. When rules improved, every project had to be updated
manually — causing drift. This repo eliminates that problem.

---

## Contents

```
.github/agents/                    ← Speckit lifecycle agents
  orchestrator.lifecycle.agent.md  ← Master orchestrator (entry point for all features)
  speckit.*.agent.md               ← Individual Speckit phase agents

.specify/
  templates/                       ← Spec, plan, tasks, checklist, constitution templates
  scripts/bash/                    ← Preflight and setup scripts
  extensions/git/                  ← Git extension commands and scripts
  extensions.yml                   ← Speckit extension registration
  integration.json                 ← Speckit integration config
  init-options.json                ← Speckit init options

bootstrap/
  init-project.sh                  ← Bootstrap a new project with full governance
  sync-governance.sh               ← Upgrade existing project to a newer governance version

VERSION                            ← Current governance version (semver)
```

---

## Bootstrapping a new project

Run once in your new project root:

```bash
curl -fsSL https://raw.githubusercontent.com/SrikamalIdeas/skideas-governance/main/bootstrap/init-project.sh | bash
```

Or clone governance and run locally:

```bash
git clone https://github.com/SrikamalIdeas/skideas-governance.git /tmp/skideas-governance
cd /path/to/your-new-project
bash /tmp/skideas-governance/bootstrap/init-project.sh
```

This copies all governance artifacts into your project and writes `.specify/governance-version`.

---

## Upgrading governance in an existing project

```bash
curl -fsSL https://raw.githubusercontent.com/SrikamalIdeas/skideas-governance/main/bootstrap/sync-governance.sh | bash -s -- v1.1.0
```

Or with a local clone:

```bash
cd /path/to/your-project
bash /tmp/skideas-governance/bootstrap/sync-governance.sh v1.1.0
```

Standard governance files (agents, templates, scripts, extensions) are overwritten.
Project-specific files (constitution.md, specs/, backlog/, memory/) are **never** touched.

---

## Versioning

Governance uses semantic versioning:
- **Patch** (`1.0.x`): bug fixes in scripts/agents, wording corrections
- **Minor** (`1.x.0`): new agents, new templates, new script features (backward compatible)
- **Major** (`x.0.0`): breaking workflow changes (branch strategy, gate model changes)

Projects should pin a governance version and upgrade deliberately.

---

## Constitution layering

The `constitution-template.md` in `.specify/templates/` is a **generic base** covering
principles and workflow gates common to all SKIdeas projects.

Each project starts with this template and adds project-specific policies in its own
`constitution.md` (e.g., service architecture rules, encryption policy, redaction policy).

The base template is **guidance** — project constitutions are the authoritative policy for
their respective repositories.

---

## Current version: 1.0.0

| Version | Date       | Notes                             |
|---------|------------|-----------------------------------|
| 1.0.0   | 2026-05-26 | Initial extraction from heysiaai  |
