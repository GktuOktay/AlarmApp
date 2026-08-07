# memory.md — AlarmApp proje hafızası

Son güncelleme: 2026-08-07 · VERSION `0.0.7`

---

## Repo

- GitHub: https://github.com/GktuOktay/AlarmApp
## Çalışma biçimi (kilit)

- Ajan: kod yazar + `AlarmAppCore` için `swift test` / `swift build` doğrular
- İnsan: Xcode’da app Run / Preview / simülatör (tam `xcodebuild` app derlemesini ajan varsayılan olarak atlar — yavaş)
- Toplu özellik yaz → insan bir kez derler

## Mimari sabit

- **Local-first / sunucusuz:** tüm özellikler cihazda; bulut zorunluluğu yok
- **Cihaz tabanı:** iPhone 11+ · iOS 17+ / watchOS 10+ (SwiftData)

## Ürün kararları (KİLİTLİ)

- **Alarm-first:** Alarm birincil; grup isteğe bağlı; tekrar/saat alarmda (`2026-08-06-alarm-first-model-design.md`)
- K1: ~~Aralık bitiş dahil~~ → **arşiv** (üreteç yok)
- K2: Takvim haftası Pzt–Paz
- K3: Grup silinince alarmlar nullify (grupsuz kalır); istisna cascade
- K4: Critical Alert garantisiz

## Açık kapılar

- [x] Alarm-first modeller + CreateAlarm + repo + bildirim
- [x] S1/S2/S3 alarm UI + S4 takvim iskeleti
- [x] Alarm ses kataloğu + soundVolume + S2 önizleme
- [x] Uyanma / ertele / Saat-UI + Watch prompt — `0.0.7` (spec `2026-08-07-uyanma-ertele-ve-saat-ui-design.md`)
  - Core dismiss/snooze/bulk + Saat list/form + çalma UI + bildirim Ertele + WCSession köprü / sync apply + WakeDetectionEngine + Watch “Uyandın mı?” + S7 toggle
  - **Kalan:** gerçek iPhone↔Watch E2E sync insan doğrulaması; F5 kalibrasyon / FP ölçümü (v2)
  - WC: reachable→sendMessage else transferUserInfo; today→applicationContext (+ `autoWakeDetectionEnabled`)
- [ ] SkipWeek UI

## Tasarım kilidi (2026-08-07)

- Çalma: Kapat / Ertele / Daha fazla → grup bugünü · 3s tümü · bugün tümü
- Ertele alarm bazlı (`snoozeMinutes`, varsayılan 9)
- Liste: Uyku \| Uyanma + Diğer (Saat hissi)
- Algılama: HK Sleep + hareket (+ HR yedek, sahte workout yok); onaysız iptal yok
- F5-style prompt bu milestone’a çekildi; tam F5 saha testi v2’de

## Kod notları

- Saatler `ClockTime` (Codable)
- Instance ufku varsayılan 14 gün (alarm `daysOfWeek` üzerinden)
- `SkipWeek` haftanın Pzt startOfDay + 7 gün
- Cihaz tabanı: iPhone 11+ · iOS 17+
- Katalog `id` ↔ bundle `.caf` adı aynı; Critical path `criticalAlertsEnabled` (varsayılan `false`)
- `TodayContext.autoWakeDetectionEnabled` (legacy decode → `true`); S7 → `pushTodayContext`
- `TodayContext.wakeAlarmId` / `wakeGroupId` / `nextWakeFireDate` (legacy → nil); Watch wake detection uses context, not full local catalog
- `InstanceSummary.alarmId` (legacy → zero UUID); ringing candidate can use context-only summaries
- WC: notActivated → enqueue outbound; flush on `activationDidComplete`
- HealthKit entitlement: iOS + Watch `.entitlements` + `project.yml`
- `handleWakeEvent` legacy; yeni UI `cancel(scope:reason: .wakePrompt)`
- Status `.snoozed` + reason `.snoozed` (karıştırma)
