# memory.md — AlarmApp proje hafızası

Kalıcı, kısa, ajanlar arası hatırlatmalar. Her oturumda ilgiliyse oku; önemli karar veya durumu buraya ekle. Uzun dokümanları kopyalama — `docs/` yolunu yaz.

Son güncelleme: 2026-08-06

---

## Repo

- GitHub: https://github.com/GktuOktay/AlarmApp
- Yerel: `Desktop/Projects/Hobies/AlarmApp`
- Sürüm: **0.0.1**
- Lisans: **MIT** (`LICENSE`, © Göktuğ Oktay)
- Commit: Türkçe metin; `git commit-tree`; IDE ortak yazar satırı yasak
- Bu makinede tam Xcode yok (yalnızca Command Line Tools) → `swift test` / `xcodebuild` burada çalışmıyor; CI/macOS+Xcode veya kullanıcı makinesi gerekir

## Ürün (özet)

- Konumlandırma: Alarmları grupla; uyanınca bilek anlasın, kalanı kapatsın.
- v1 uyanma: manuel (Watch “Uyandım” / telefon kontrolleri)
- v2: HealthKit + CoreMotion + onay (fail-safe)
- Çekirdek: alarm grubu

## Açık kapılar

- [ ] Ürün kararları K1–K4 onayı (`docs/superpowers/specs/2026-08-06-urun-kararlari.md`) — MVP domain öncesi
- [x] Git remote + ilk içerik
- [x] OSS: LICENSE, README, CONTRIBUTING, CoC, SECURITY
- [x] `AlarmAppCore` kaynak iskeleti
- [ ] Kullanıcıda: Xcode seç + `brew install xcodegen` + `scripts/generate-xcode.sh` → `.xcodeproj`
- [ ] MVP domain (F1/F3) — kararlar kilitlenince

## Önerilen ürün kararları (kilit bekliyor)

- K1: Bitiş dahil → 13 alarm örneği
- K2: Takvim haftası Pzt–Paz
- K3: Cascade sil
- K4: Critical Alert garantisiz

## Bilinçli yapılmayanlar

- Domain use case’leri (CreateAlarmGroup vb.) henüz yok
- WatchConnectivity / HealthKit henüz yok
- Web apple-design skill yok
