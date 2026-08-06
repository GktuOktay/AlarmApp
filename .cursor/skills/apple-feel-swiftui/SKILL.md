---
name: apple-feel-swiftui
description: Native SwiftUI/watchOS Apple-feel UI — springs, haptics, materials, Dynamic Type, reduced motion. Use when building or reviewing gesture-driven UI, sheets, swipes, notifications presentation, complications, or Watch hit targets. Do not use for web/CSS.
---

# Apple Feel (SwiftUI / watchOS)

Native-only guidance for AlarmApp. **Do not** apply web apple-design skills (CSS, Framer Motion, Pointer Events, `backdrop-filter` as primary API).

## Principles

1. **Response** — Feedback on press/touch-down, not only on release. Prefer `ButtonStyle` / `configuration.isPressed`, `sensoryFeedback`.
2. **Interruptibility** — Animations must be redirectable. Prefer SwiftUI `.spring` / animatable state over fixed “fire and forget” sequences that ignore new input.
3. **Spatial consistency** — Enter and exit along the same path; sheets/menus anchored to their source when the platform allows.
4. **Materials & hierarchy** — Use system materials (e.g. `.ultraThinMaterial`) and semantic colors; respect Reduce Transparency.
5. **Multimodal** — Pair meaningful commits with haptics (`sensoryFeedback` / Watch haptics). Causality + same-frame harmony; don’t over-haptic.
6. **Accessibility** — Dynamic Type, VoiceOver labels, Reduce Motion (cross-fade / shorter, not vestibular springs).

## Concrete defaults

| Interaction | Guidance |
|---|---|
| Default UI motion | Critically damped feel — snappy settle, little/no bounce |
| Flick / drag release | Slight bounce only if momentum justifies it |
| Watch “Uyandım” | ≥ 44×44 pt, high contrast, haptic on confirm |
| Phone destructive/quick actions | Swipe actions + undo snackbar (see UX docs) |

## Platform pointers

- HIG Notifications: https://developer.apple.com/design/human-interface-guidelines/notifications
- HIG Complications: https://developer.apple.com/design/human-interface-guidelines/complications
- Icons: SF Symbols app — see `docs/09-referans-kaynaklar.md`
- AlarmApp UX: `docs/01-ux-tasarim-ve-akislar.md`, `docs/07-…`

## Anti-patterns

- Porting web spring code or CSS transitions into this repo
- Custom typefaces that fight Dynamic Type without reason
- Tiny Watch controls; color-only status without secondary cues
