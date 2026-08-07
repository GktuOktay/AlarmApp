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
- [ ] Uyanma / ertele / Saat-UI + Watch prompt — spec `2026-08-07-uyanma-ertele-ve-saat-ui-design.md`, plan `2026-08-07-uyanma-ertele-ve-saat-ui.md`
  - Core dismiss/snooze/bulk + Saat list/form + çalma UI + bildirim Ertele + **WCSession köprü / sync apply** hazır; WakeDetection sonraki
  - WC: reachable→sendMessage else transferUserInfo; today→applicationContext; gerçek cihaz E2E henüz doğrulanmadı
- [ ] SkipWeek UI

## Tasarım kilidi (2026-08-07)

- Çalma: Kapat / Ertele / Daha fazla → grup bugünü · 3s tümü · bugün tümü
- Ertele alarm bazlı (`snoozeMinutes`, varsayılan 9)
- Liste: Uyku \| Uyanma + Diğer (Saat hissi)
- Algılama: HK Sleep + hareket (+ HR yedek, sahte workout yok); onaysız iptal yok

## Kod notları

- Saatler `ClockTime` (Codable)
- Instance ufku varsayılan 14 gün (alarm `daysOfWeek` üzerinden)
- `SkipWeek` haftanın Pzt startOfDay + 7 gün
- Cihaz tabanı: iPhone 11+ · iOS 17+
- Katalog `id` ↔ bundle `.caf` adı aynı; Critical path `criticalAlertsEnabled` (varsayılan `false`)
