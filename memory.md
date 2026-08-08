# memory.md — AlarmApp proje hafızası

Son güncelleme: 2026-08-08 · VERSION `0.0.8`

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
- [x] Uyanma / ertele / Saat-UI + Watch prompt — `0.0.7`
- [x] Post-dismiss grup “Uyandın mı?” + kompakt create + AppLog — `0.0.8` (spec `2026-08-08-post-dismiss-wake-ve-form-design.md`)
  - Watch: dismiss sonrası grupta kalan pending → soft offer; Evet = `groupToday` + `.wakePrompt`
  - Create: Disclosure kapalı; `repeats` default `false`; ses `Picker` menu
  - `AppLog` / `RecordingLogSink`; fail-safe catch’lerde log (analitik yok)
  - **Kalan:** gerçek iPhone↔Watch E2E; F5 kalibrasyon / FP (v2)
- [ ] SkipWeek UI

## Tasarım kilidi (2026-08-08)

- Birincil uyanma sinyali: **kapat sonrası** grup önerisi (sensör erken prompt ikincil / S7)
- Apple Saat Sleep Schedule **okunamaz**; `isWakeSchedule` uygulama içi Saat kartı
- Algılama: onay olmadan iptal yok
- F5-style erken prompt mevcut; tam F5 saha testi v2

## Kod notları

- Saatler `ClockTime` (Codable)
- Instance ufku varsayılan 14 gün (alarm `daysOfWeek` üzerinden)
- `SkipWeek` haftanın Pzt startOfDay + 7 gün
- Cihaz tabanı: iPhone 11+ · iOS 17+
- Katalog `id` ↔ bundle `.caf` adı aynı; Critical path `criticalAlertsEnabled` (varsayılan `false`)
- `CreateAlarmRequest.repeats` varsayılan **`false`**
- `PostDismissWakeOfferPolicy` + `countPendingInGroupToday`
- `AppLog` kategorileri: swiftdata / notifications / wcsession / wake
- `TodayContext.autoWakeDetectionEnabled` (legacy decode → `true`); S7 → `pushTodayContext`
- `TodayContext.wakeAlarmId` / `wakeGroupId` / `nextWakeFireDate` (legacy → nil); Watch wake detection uses context, not full local catalog
- `InstanceSummary.alarmId` (legacy → zero UUID); ringing candidate can use context-only summaries
- WC: notActivated → enqueue outbound; flush on `activationDidComplete`
- HealthKit entitlement: iOS + Watch `.entitlements` + `project.yml`
- `handleWakeEvent` legacy; yeni UI `cancel(scope:reason: .wakePrompt)`
- Status `.snoozed` + reason `.snoozed` (karıştırma)
