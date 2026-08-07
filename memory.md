# memory.md — AlarmApp proje hafızası

Son güncelleme: 2026-08-07

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
- [ ] Watch “Uyandım”
- [ ] SkipWeek UI

## Kod notları

- Saatler `ClockTime` (Codable)
- Instance ufku varsayılan 14 gün (alarm `daysOfWeek` üzerinden)
- `SkipWeek` haftanın Pzt startOfDay + 7 gün
- Cihaz tabanı: iPhone 11+ · iOS 17+
- Katalog `id` ↔ bundle `.caf` adı aynı; Critical path `criticalAlertsEnabled` (varsayılan `false`)
