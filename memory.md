# memory.md — AlarmApp proje hafızası

Son güncelleme: 2026-08-06

---

## Repo

- GitHub: https://github.com/GktuOktay/AlarmApp
## Çalışma biçimi (kilit)

- Ajan: kod yazar + `AlarmAppCore` için `swift test` / `swift build` doğrular
- İnsan: Xcode’da app Run / Preview / simülatör (tam `xcodebuild` app derlemesini ajan varsayılan olarak atlar — yavaş)
- Toplu özellik yaz → insan bir kez derler

## Mimari sabit

- **Local-first / sunucusuz:** tüm özellikler cihazda; bulut zorunluluğu yok

## Ürün kararları (KİLİTLİ)

- K1: Bitiş dahil → 06:00–07:00 / 5dk = 13
- K2: Takvim haftası Pzt–Paz
- K3: Cascade sil
- K4: Critical Alert garantisiz

## Açık kapılar

- [x] F1 generator + modeller + CreateAlarmGroup + overlap + SwiftData repo (kod)
- [ ] `swift test` yeşil (Xcode toolchain)
- [ ] XcodeGen ile `.xcodeproj`
- [ ] Bildirim zamanlama (UNUserNotificationCenter)
- [ ] S1/S2/S3 UI

## Kod notları

- Saatler `ClockTime` (Codable); dokümandaki `DateComponents` alanları bununla temsil
- Instance ufku varsayılan 14 gün
- `SkipWeek` haftanın Pzt startOfDay + 7 gün
