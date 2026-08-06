# memory.md — AlarmApp proje hafızası

Kalıcı, kısa, ajanlar arası hatırlatmalar. Her oturumda ilgiliyse oku; önemli karar veya durumu buraya ekle. Uzun dokümanları kopyalama — `docs/` yolunu yaz.

Son güncelleme: 2026-08-06

---

## Repo

- GitHub: https://github.com/GktuOktay/AlarmApp
- Yerel klasör: `Desktop/Projects/Hobies/AlarmApp`
- Sürüm: `0.0.0` (`VERSION` + kullanıcıya dönük `CHANGELOG.md`)
- İlk push / remote bağlantısı: insan veya ajan; **commit mesajında Cursor/Co-authored-by asla olmamalı** (gerekirse `git commit-tree` kullan)

## Ürün (özet)

- Konumlandırma: Alarmları grupla; uyanınca bilek anlasın, kalanı kapatsın.
- v1 uyanma: sistem sensörle “uyandın” demez — Watch “Uyandım” veya telefonda Bugün kapat / Bu hafta pas geç.
- v2: HealthKit + CoreMotion tahmini + zorunlu kullanıcı onayı (fail-safe).
- Çekirdek özellik: alarm grubu (başlangıç–bitiş–aralık–günler → tekil alarm örnekleri).

## Açık kapılar

- [ ] `docs/superpowers/specs/2026-08-06-urun-kararlari.md` K1–K4 kullanıcı onayı
- [ ] Git remote ilk içerik push (boş repo hazır)
- [ ] Faz 1 / Sprint 0 Xcode iskeleti henüz yok

## Önerilen ürün kararları (henüz kilitlenmedi)

- K1: Bitiş saati dahil → örn. 06:00–07:00 / 5 dk = 13 alarm
- K2: “Bu hafta” = takvim haftası Pzt–Paz
- K3: Grup silinince istisnalar cascade silinsin
- K4: Critical Alert garantisiz konumlandırma

## Agent toolkit (kurulu)

- `AGENTS.md`, `.cursor/rules/*`, `.cursor/skills/*`, `docs/09-referans-kaynaklar.md`
- Model kuralı: yalnızca **Auto**; premium modeller yasak (`alarmapp-token-usage`)
- Commit: Cursor izi yok (`alarmapp-commits`)

## Bilinçli yapılmayanlar

- Web `apple-design` skill karıştırılmadı
- Referans uygulamalar klonlanmadı (yalnızca `docs/09` linkleri)
- Uygulama kodu / Xcode workspace henüz yok
