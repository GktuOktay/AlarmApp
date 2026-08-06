# memory.md — AlarmApp proje hafızası

Son güncelleme: 2026-08-06

---

## Repo

- GitHub: https://github.com/GktuOktay/AlarmApp
- Sürüm: **0.0.2** (Xcode projesi üretildi; bir sonraki bump UI/bildirim ile)
- `xcode-select` → Xcode.app ✓
- Runtime: iOS 26.5 + watchOS 26.5 ✓
- `AlarmApp.xcodeproj` XcodeGen ile üretildi; iOS + Watch **build OK**; `swift test` 9/9 ✓
- Aç: `open AlarmApp.xcodeproj` → scheme AlarmApp-iOS

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
