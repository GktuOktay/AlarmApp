# Design: AlarmApp Agent Toolkit (Lean)

**Date:** 2026-08-06  
**Status:** Approved — toolkit implementation in progress / delivered per plan  
**Approach:** Lean toolkit (project-local only)  
**Language:** Agent files English; product docs Turkish

---

## 1. Purpose

Before application coding, establish Cursor agent guidance so implementation follows product docs, architecture constraints, and Apple-native interaction quality — without vendoring third-party apps or mixing web design skills into this native Swift project.

**Out of scope for this design:** app scaffolding, domain logic, Xcode project, copying emilkowalski web `apple-design` skill, git submodules / `vendor/` clones, global `~/.cursor` skills.

---

## 2. Decisions locked

| Decision | Choice |
|---|---|
| Where tooling lives | Project-only: `AGENTS.md`, `.cursor/rules`, `.cursor/skills` |
| Reference “repos” | Catalog + screen mapping in `docs/09-referans-kaynaklar.md` — links only, no clones |
| Web apple-design skill | **Excluded** (web/CSS/Motion) |
| Apple feel guidance | New native skill: `apple-feel-swiftui` |
| Superpowers | Keep existing `docs/superpowers/{plans,specs}`; do not invent a new framework |
| Agent file language | English |
| Product docs language | Turkish (unchanged) |
| Toolkit size | Lean: 1 AGENTS + 4 rules + 3 skills + 1 references doc |

---

## 3. File layout

```
AlarmApp/
├── AGENTS.md
├── .cursor/
│   ├── rules/
│   │   ├── alarmapp-core.mdc              # alwaysApply: true
│   │   ├── alarmapp-core-package.mdc      # globs: AlarmAppCore/**
│   │   ├── alarmapp-watch.mdc             # globs: AlarmApp-Watch/**
│   │   └── alarmapp-docs.mdc              # globs: docs/**
│   └── skills/
│       ├── apple-feel-swiftui/SKILL.md
│       ├── alarmapp-phase-workflow/SKILL.md
│       └── watch-connectivity-safe/SKILL.md
├── docs/
│   ├── 09-referans-kaynaklar.md
│   └── superpowers/                       # existing — unchanged by this design
└── (application code — later phases, not this design)
```

---

## 4. Components

### 4.1 `AGENTS.md`

Short orientation for every session:

- What the product is (one sentence from PRD)
- Layout pointer (Core / iOS / Watch — when they exist)
- Read order: `docs/00`–`07`, `docs/09`, phase plans under `docs/superpowers/plans/`
- Product decisions path: `docs/superpowers/specs/2026-08-06-urun-kararlari.md`
- Point to `.cursor/rules` and `.cursor/skills`
- Explicit: no coding until toolkit phase plan is executed and product decisions approved

### 4.2 Rules

Keep each rule concise (target ≤50 lines), one concern, actionable.

**`alarmapp-core.mdc`** (`alwaysApply: true`)

- Local-first; no default cloud sync or analytics SDK
- `AlarmAppCore` must not `import SwiftUI`
- Fail-safe: never silently cancel alarms
- Follow phase plans; do not implement Watch/HealthKit before MVP readiness
- Conventional Commits; MIT license headers on new source files when licensing is in place
- Before F1 domain algorithms, require locked product decisions in `urun-kararlari.md`

**`alarmapp-core-package.mdc`** (`AlarmAppCore/**`)

- Layers only: Domain / Data / Connectivity
- Types and protocols copied from `docs/03`; do not invent `WatchMessage` cases without updating `03`
- Tests via `swift test`; no UIKit/WatchKit/SwiftUI in Core

**`alarmapp-watch.mdc`** (`AlarmApp-Watch/**`)

- Watch = quick decisions; phone = planning
- Offline-first wake: cancel locally, then sync
- “Uyandım” control ≥ 44×44 pt + haptic; 10s undo
- Store `TodayContext` cache only — not full history

**`alarmapp-docs.mdc`** (`docs/**`)

- Product docs stay Turkish
- Do not replace product docs with English agent prose
- References = link catalog only; no vendored clones under the repo

### 4.3 Skills

**`apple-feel-swiftui`**

- Trigger: building or reviewing SwiftUI/watchOS UI, motion, sheets, swipes, haptics, Dynamic Type, materials
- Content: interruptible springs (SwiftUI `.spring` / animation APIs), feedback on press-down, system materials, spatial consistency (symmetric enter/exit), reduced motion, SF Symbols + system text styles, Watch hit targets
- Pointers to Apple HIG Notifications and Complications
- **Hard exclusion:** CSS, Framer Motion, web Pointer Events, `backdrop-filter` as primary guidance

**`alarmapp-phase-workflow`**

- Trigger: feature work, “continue”, phase execution
- Order: product decisions locked → open relevant `docs/superpowers/plans/*` → read cited product docs → TDD in Core → UI
- Forbid skipping phases (e.g. Watch before MVP)

**`watch-connectivity-safe`**

- Trigger: WCSession, wake sync, `WatchMessage`
- Contract from `docs/03`: `sendMessage` then `transferUserInfo` fallback
- Offline-first; real-device verification note for WC changes
- Adding undo (or any new message case) requires updating `docs/03` first

### 4.4 `docs/09-referans-kaynaklar.md` (Turkish)

Link catalog with “when to use” and AlarmApp mapping. No clones.

| Source | Use for |
|---|---|
| awesome-swiftui / Clendar | S4 calendar patterns |
| Ice Cubes (Thomas Ricouard) | Modular SwiftUI organization, production patterns |
| jogendra/example-ios-apps / Countio | Simple Watch companion patterns |
| Apple HIG — Notifications, Complications | Notifications + W3 |
| SF Symbols (Apple app) | Icon consistency |
| Mobbin | Visual inspiration for onboarding/alarm flows (screenshots, not code) |

Include canonical URLs when writing the file. State clearly: study patterns; do not copy GPL/incompatible code blindly; prefer re-implementation against our docs.

---

## 5. Data flow / agent behavior

```
User asks for work
  → AGENTS.md + always-apply rules load
  → If UI/motion: apple-feel-swiftui
  → If phase/feature: alarmapp-phase-workflow
  → If Watch sync: watch-connectivity-safe
  → Glob rules apply when editing matching paths
  → References doc consulted when designing S4/Watch/onboarding visuals
  → Implementation only after toolkit plan executed + ürün kararları approved
```

---

## 6. Error handling / anti-patterns

| Anti-pattern | Guard |
|---|---|
| Import web apple-design skill | Explicit exclusion in this spec + skill header |
| Submodule Ice Cubes / Clendar | `09` links only; docs rule forbids vendor clones |
| Invent WatchMessage cases | watch-connectivity-safe + core-package rule |
| Skip to F5 HealthKit early | phase-workflow + core always-apply |
| Silently cancel alarms | core always-apply fail-safe |
| English rewrite of PRD | docs rule |

---

## 7. Verification checklist (toolkit delivery)

- [ ] All listed paths exist
- [ ] Each `SKILL.md` has valid YAML frontmatter (`name`, `description`)
- [ ] Each rule has correct `alwaysApply` / `globs`
- [ ] Rules stay roughly ≤50 lines each
- [ ] `rg` finds no web stack primary guidance inside `.cursor/skills` (`framer-motion`, `pointerdown` web samples as required API, etc.)
- [ ] `docs/09` has no submodule instructions
- [ ] `AGENTS.md` points at docs, plans, and ürün kararları

---

## 8. Delivery sequence (after this spec is approved)

1. `writing-plans` → implementation plan for this toolkit only  
2. Execute plan (create files)  
3. User approves `urun-kararlari.md`  
4. Then app coding (Faz 1 hazırlık / MVP) per existing phase plans  

---

## 9. Spec self-review (2026-08-06)

| Check | Result |
|---|---|
| Placeholders / TBD | None remaining |
| Internal consistency | Layout ↔ component sections aligned; web skill excluded everywhere |
| Scope | Toolkit only; app code deferred — focused enough for one plan |
| Ambiguity | Product decision *values* remain in `urun-kararlari.md` (separate gate); this spec only requires they be locked before F1 |
