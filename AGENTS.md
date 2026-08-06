# AlarmApp — Agent Guide

Native Swift/SwiftUI iOS + Apple Watch alarm app. Positioning: *Group your alarms; when you wake, your wrist understands and silences the rest.*

## Before you code

1. Read `memory.md` (project memory — decisions, gates, repo state).
2. Read product docs: `docs/00` … `docs/07` (Turkish).
3. Read references: `docs/09-referans-kaynaklar.md`.
4. Follow phase plans under `docs/superpowers/plans/`.
5. Lock product decisions in `docs/superpowers/specs/2026-08-06-urun-kararlari.md` before F1 domain algorithms.
6. Agent toolkit design: `docs/superpowers/specs/2026-08-06-agent-toolkit-design.md`.

Do **not** scaffold app code until the agent toolkit is in place and the user has approved product decisions (K1–K4).

## Intended layout (when scaffolded)

- `AlarmAppCore/` — Swift Package (Domain / Data / Connectivity); **no SwiftUI**
- `AlarmApp-iOS/` — SwiftUI iPhone app (S1–S8)
- `AlarmApp-Watch/` — SwiftUI watchOS app (W1–W3)
- `docs/` — PRD, UX, architecture, plans
- `memory.md` — short persistent project memory
- `CHANGELOG.md` — **end-user Turkish** version notes
- `VERSION` — SemVer string (starts at `0.0.0`)

## Agent tooling

- **Rules:** `.cursor/rules/` (always-apply + path globs)
- **Skills:** `.cursor/skills/` — use when relevant:
  - `apple-feel-swiftui` — native UI / motion / haptics
  - `alarmapp-phase-workflow` — phased feature work
  - `watch-connectivity-safe` — WCSession / wake sync

## Versioning

- Current version: see root `VERSION`.
- `CHANGELOG.md` is for **end users**, Turkish, plain sentences — no agent/tooling jargon.
- Technical session state goes in `memory.md`, not the changelog.
- **Commit messages:** Turkish, consistent sentences; no IDE co-author trailers (`alarmapp-commits`).
- Remote: https://github.com/GktuOktay/AlarmApp

## Hard constraints (summary)

- **Model:** Auto only — no premium models (`alarmapp-token-usage`)
- **Commits:** Turkish text; no IDE / AI attribution traces (`alarmapp-commits`)
- Local-first; no default cloud or analytics SDK
- Fail-safe: never silently cancel alarms
- v1 wake = explicit user action (Watch “Uyandım” or phone controls); auto-detect is v2 only
- No web design skills or vendored third-party app clones
- License: MIT (`LICENSE`)