# Agent Toolkit (Lean) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create project-local Cursor agent guidance (AGENTS.md, 4 rules, 3 skills, references doc) per the approved design — no app code.

**Architecture:** Copy content from `docs/superpowers/specs/2026-08-06-agent-toolkit-design.md`. English agent files; Turkish `docs/09`. No web apple-design; no vendor clones.

**Tech Stack:** Markdown, Cursor `.mdc` rules, Agent Skills (`SKILL.md`)

## Global Constraints

- Project-only paths under AlarmApp (no `~/.cursor`)
- No CSS/Framer Motion/web Pointer Events as primary guidance
- Rules target ≤50 lines each
- Spec: `docs/superpowers/specs/2026-08-06-agent-toolkit-design.md`

## File map

| Path | Responsibility |
|---|---|
| `AGENTS.md` | Session orientation |
| `.cursor/rules/*.mdc` | Persistent constraints |
| `.cursor/skills/*/SKILL.md` | On-demand workflows |
| `docs/09-referans-kaynaklar.md` | Reference catalog (TR) |

---

### Task 1: AGENTS.md + docs/09

**Files:**
- Create: `AGENTS.md`
- Create: `docs/09-referans-kaynaklar.md`
- Modify: `docs/superpowers/specs/2026-08-06-agent-toolkit-design.md` (status → Approved)

- [ ] **Step 1:** Write `AGENTS.md` per design §4.1
- [ ] **Step 2:** Write `docs/09-referans-kaynaklar.md` per design §4.4 with real URLs
- [ ] **Step 3:** Mark design status Approved
- [ ] **Step 4:** Commit `docs: add AGENTS.md and reference catalog`

### Task 2: Cursor rules

**Files:**
- Create: `.cursor/rules/alarmapp-core.mdc`
- Create: `.cursor/rules/alarmapp-core-package.mdc`
- Create: `.cursor/rules/alarmapp-watch.mdc`
- Create: `.cursor/rules/alarmapp-docs.mdc`

- [ ] **Step 1:** Write all four rules per design §4.2 (≤50 lines each)
- [ ] **Step 2:** Commit `chore: add AlarmApp Cursor rules`

### Task 3: Cursor skills

**Files:**
- Create: `.cursor/skills/apple-feel-swiftui/SKILL.md`
- Create: `.cursor/skills/alarmapp-phase-workflow/SKILL.md`
- Create: `.cursor/skills/watch-connectivity-safe/SKILL.md`

- [ ] **Step 1:** Write three skills per design §4.3 with valid frontmatter
- [ ] **Step 2:** Commit `chore: add AlarmApp project skills`

### Task 4: Verification

- [ ] **Step 1:** Confirm all paths exist
- [ ] **Step 2:** `rg` for web stack in `.cursor/skills` — expect no matches for `framer-motion`, `backdrop-filter` as guidance
- [ ] **Step 3:** Confirm `docs/09` has no submodule/vendor clone instructions
- [ ] **Step 4:** Commit any checklist fixes; hand off to ürün kararları approval then Faz 1
