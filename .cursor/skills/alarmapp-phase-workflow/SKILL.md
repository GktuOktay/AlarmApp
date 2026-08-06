---
name: alarmapp-phase-workflow
description: Phased AlarmApp feature workflow — product decisions, plans, docs, TDD Core then UI. Use when starting features, continuing implementation, or choosing what to build next.
---

# AlarmApp phase workflow

## Order (mandatory)

1. **Read `memory.md`** — current gates, decisions, repo state.
2. **Product decisions** — For F1/SkipWeek/instance math, confirm `docs/superpowers/specs/2026-08-06-urun-kararlari.md` is approved (K1–K3 at minimum).
3. **Open the plan** — Relevant file under `docs/superpowers/plans/`.
4. **Read cited docs** — `docs/00`–`07`, `docs/09` as referenced by the plan task.
5. **TDD in `AlarmAppCore`** — Use cases/repositories first (`swift test`).
6. **UI last** — iOS then Watch per phase; invoke `apple-feel-swiftui` for UI polish.
7. **Update `memory.md` + Turkish end-user `CHANGELOG.md`** when a user-visible milestone lands (bump `VERSION` if needed).

## Phase gates

| Phase | May build | Must not skip ahead to |
|---|---|---|
| Toolkit | AGENTS, rules, skills, `docs/09` | App domain code |
| Hazırlık / Sprint 0 | Workspace, empty Core, CI, OSS files | Watch sync, F5 |
| MVP | F1, F3, notifications, S1/S2/S3/S8 | Watch F2, F4 calendar, HealthKit |
| v1.0 | F2 Watch, F4 calendar, W3 | F5 auto-wake |
| v1.1 | Store prep, localization | Treating F5 as required |
| v2.0 | F5 HealthKit/CoreMotion | Silent cancel without confirmation |

## Rules of engagement

- One plan task at a time; verify checklist before the next.
- Prefer `subagent-driven-development` or `executing-plans` for multi-task plans.
- If docs conflict, stop and resolve in docs (don’t invent product behavior).
