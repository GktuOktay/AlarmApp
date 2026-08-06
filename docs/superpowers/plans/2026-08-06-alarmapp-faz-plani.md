# AlarmApp — Ana Faz Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement each phase plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> Bu dosya **orkestrasyon** planıdır. Her fazın ayrı detay planı vardır (aşağıdaki linkler). Kod yazmadan önce ilgili faz planını aç.

**Goal:** Local-first iOS + Apple Watch alarm uygulaması — gruplu alarmlar, Watch “Uyandım”, manuel gün/hafta kontrolleri, takvim istisnaları; v2’de otomatik uyanma algılama.

**Architecture:** Tek Xcode workspace; paylaşımlı `AlarmAppCore` Swift Package (Domain + Data + Connectivity); iOS ve watchOS ayrı SwiftUI target’lar; SwiftData; `UNUserNotificationCenter`; `WCSession` doğrudan (köprü yok).

**Tech Stack:** Swift 5.9+, SwiftUI, SwiftData, Observation (`@Observable`), WatchConnectivity, WidgetKit (complication), XCTest, SwiftLint, GitHub Actions. (v2: HealthKit, CoreMotion)

## Global Constraints

- Local-first; bulut/analytics yok (PRD NG2, ADR-3).
- `AlarmAppCore` **SwiftUI import etmez** (yalnızca Foundation / SwiftData / WatchConnectivity / HealthKit / CoreMotion).
- Bağımlılık yönü: UI → Core; tersi yok.
- Fail-safe: belirsizlikte alarm çalmaya devam eder; sessiz iptal yok.
- Minimum hedef: iOS 17+ / watchOS 10+ (SwiftData varsayımı, ADR-4).
- Lisans: MIT. Commit: Conventional Commits. Branch: `main` / `develop` / `feature/*`.
- PRD Açık Sorular 1–3, F1 domain kodundan önce kilitlenmeli (`docs/superpowers/specs/2026-08-06-urun-kararlari.md`).

---

## Phase 0 — Dokümantasyon Keşfi (tamamlandı)

### Kaynaklar

| Dosya | Kullanım |
|---|---|
| `docs/00-PRD-urun-gereksinim-dokumani.md` | G1–G5, F1–F4, açık sorular |
| `docs/01-ux-tasarim-ve-akislar.md` | S1–S8, W1–W3, akışlar |
| `docs/02-teknik-mimari.md` | ADR-1..6, katmanlar, wake akışı |
| `docs/03-veri-modeli-ve-arayuzler.md` | `@Model` şema, protokoller, `WatchMessage` |
| `docs/04-yol-haritasi-ve-sprintler.md` | Sprint 0–14 zaman çizelgesi |
| `docs/05-test-qa-plani.md` | Test piramidi, E2E |
| `docs/06-acik-kaynak-governance.md` | Repo layout, OSS dosyaları |
| `docs/07-detayli-ekran-ve-fonksiyon-spesifikasyonu.md` | Ekran → use case eşlemesi |

### Repo durumu

- Yalnızca `docs/` var; Xcode/SPM/Swift kaynak yok.
- Hedef layout: `06` §2 (`AlarmApp.xcworkspace`, `AlarmAppCore/`, `AlarmApp-iOS/`, `AlarmApp-Watch/`).

### Allowed APIs (kaynaklı)

| API | Kaynak |
|---|---|
| SwiftUI, SPM `AlarmAppCore` | ADR-1, `02` |
| SwiftData `@Model` / `ModelContainer` / `@Query` | ADR-4, `03` |
| `@Observable` | ADR-5 |
| `UNUserNotificationCenter` | ADR-6 |
| `WCSession` (`sendMessage`, `transferUserInfo`, `updateApplicationContext`) | ADR-2, `03` |
| WidgetKit (W3) | `04` Sprint 7 |
| HealthKit / CoreMotion | yalnızca Faz 4 (v2) |
| XCTest, SwiftLint, `xcodebuild test` | `05`, `06` |

### Anti-pattern guards

- Flutter / MethodChannel / EventChannel yok.
- Core içinde SwiftUI yok.
- Varsayılan bulut senkron veya analytics SDK yok.
- Critical Alert entitlement olmadan “DND’yi kesin deler” vaadi yok (NG4).
- `WatchMessage`’a dokümanda olmayan case ekleme (undo için önce `03` güncelle).

### Bloklayıcı ürün kararları

PRD §7 soruları 1–3 → `docs/superpowers/specs/2026-08-06-urun-kararlari.md` (öneriler hazır; onay bekliyor).

---

## Faz özeti (uygulama)

| Faz | Sürüm | Sprint | Çıktı | Detay plan |
|---|---|---|---|---|
| **1** | Hazırlık | 0 | Workspace, Core iskelet, CI, OSS | [faz-1-hazirlik](./2026-08-06-faz-1-hazirlik.md) |
| **2** | MVP 0.1 | 1–3 | F1 + F3 + bildirim + S1/S2/S3/S8 (Watch yok) | Sonraki chat’te yazılacak |
| **3** | v1.0 | 4–7 | F2 Watch + F4 takvim + W3 complication | Sonraki chat’te yazılacak |
| **4** | v1.1 | 8–9 | App Store, lokalizasyon, Critical Alert başvurusu | Sonraki chat’te yazılacak |
| **5** | v2.0 | 10–14 | F5 otomatik uyanma (opsiyonel) | Sonraki chat’te yazılacak |
| **V** | — | her faz sonu | Regresyon / doküman uyumu | Her faz planının son task’ı |

```
Hafta:  1        2–4           5–8            9–10      11–15
        │Hazırlık│── MVP 0.1 ──│─── v1.0 ────│─ v1.1 ─│─ v2.0 (opsiyonel) ─│
```

**Önerilen durak:** v1.1 (Sprint 9) — F5 opsiyonelse ~9 hafta.

---

## Faz 1 — Hazırlık (Sprint 0) — ŞİMDİ

**Ne:** İskelet + CI + lisans; iş mantığı yok.

**Doğrulama:**
- [ ] `AlarmApp.xcworkspace` açılır; iOS + Watch target’lar `AlarmAppCore` import eder
- [ ] `swift test` (Core) geçer
- [ ] CI workflow dosyası mevcut
- [ ] `LICENSE`, `README.md`, `CONTRIBUTING.md` mevcut

**Detay:** `2026-08-06-faz-1-hazirlik.md`

---

## Faz 2 — MVP (Sprint 1–3)

**Ne (dokümandan kopyala):**
- Modeller: `03` §1 (`AlarmGroup`, `AlarmInstance`, `AlarmException`, `WakeEventLog`)
- Protokoller: `AlarmRepository`, `NotificationScheduling` (`03` §3)
- Use case’ler: `CreateAlarmGroup`, `CancelGroupForToday`, `SkipWeek` (`02`, `07`)
- UI: S1, S2, S3, S8 (`01`, `07`); F3 aksiyonları
- Bildirim: `UNUserNotificationCenter` sarmalayıcı + actionable actions

**Doğrulama:** `05` birim test tabloları + MVP bug bash; TestFlight aday.

**Anti-pattern:** Watch/WCSession bu fazda yok; HealthKit yok.

---

## Faz 3 — v1.0 (Sprint 4–7)

**Ne:**
- `WatchConnectivityService` + `WatchMessage` (`03` §4)
- `HandleWakeEvent` / `UndoWakeEvent` (`02` §3, `07` W1/W2)
- W1, W2, W3; S4, S5 + `ScheduleException`
- Offline-first: önce Watch local iptal, sonra kuyruk

**Doğrulama:** E2E-1..E2E-6 (`05`); erişilebilirlik denetimi.

**Anti-pattern:** Platform channel yok; tam geçmiş Watch’ta tutulmaz.

---

## Faz 4 — v1.1 (Sprint 8–9)

**Ne:** Critical Alert başvurusu, App Store metadata, TR+EN String Catalog, Instruments, beta döngüsü.

**Doğrulama:** Regresyon checklist (`05`); Privacy Nutrition Label.

---

## Faz 5 — v2.0 (Sprint 10–14, opsiyonel)

**Ne:** HealthKit + CoreMotion heuristik; onaylı iptal; yanlış pozitif <%15; fail-safe.

**Doğrulama:** E2E-7; F5 varsayılan kapalı eğer FP > %15.

---

## Doğrulama fazı (her faz bitişinde)

1. Allowed API dışı import yok mu? (`AlarmAppCore` içinde `import SwiftUI` grep)
2. PRD kabul kriterleri ilgili F’ler için tick’li mi?
3. `swift test` + ilgili `xcodebuild test` yeşil mi?
4. Açık soru / doküman drift’i varsa `03`/`07` güncellendi mi?

---

## Uygulama sırası (ajanlar için)

1. Kullanıcı ürün kararlarını onaylar (`urun-kararlari.md`).
2. **Faz 1** detay planı çalıştırılır.
3. Her sonraki faz için ayrı `writing-plans` detay dosyası üretilir (önceki faz yeşil olduktan sonra).
4. Tek chat’te tüm 15 haftayı kodlama — yapma; faz sınırında dur.
