# Ürün Kararları — F1–F4 Öncesi Kilit

**Tarih:** 2026-08-06  
**Durum:** Öneri — kullanıcı onayı bekliyor  
**Kaynak:** `docs/00-PRD-urun-gereksinim-dokumani.md` §7 + `docs/05` / `docs/07` tutarsızlıkları

Bu kararlar **Faz 2 (MVP domain)** başlamadan önce onaylanmalı. Faz 1 (iskelet/CI) bunlara bağlı değildir.

---

## K1 — Alarm aralığı: bitiş saati dahil mi?

**Soru:** 06:00–07:00, 5 dk aralık → son alarm 06:55 mi 07:00 mü? (12 vs 13 instance)

**Öneri: Bitiş dahil (inclusive–inclusive).**  
06:00, 06:05, …, 07:00 → **13** instance.

**Gerekçe:** PRD F1 kabul kriteri örneği zaten 13 diyor; kullanıcı “07:00’a kadar” ifadesini genelde son çalarak anlar.

**Algoritma kilidi:** `t = start; while t <= end; t += interval` (`Calendar` ile).

- [ ] Onaylandı / [ ] Değiştirildi: ___________

---

## K2 — “Bu hafta pas geç” tanımı

**Soru:** Takvim haftası (Pzt–Paz) mı, bugünden itibaren 7 gün mü?

**Öneri: Takvim haftası, Pazartesi başlangıç (ISO / TR alışkanlığı).**  
`SkipWeek(groupId, weekStart:)` → o haftanın Pzt 00:00 … Paz 23:59.

**Gerekçe:** Önizleme metni (“Pzt–Cuma arası 5 gün…”) takvim diline oturur; E2E-6 “hafta bitince normale dön” ile uyumlu.

**Not:** UI’da hafta özeti gösterilirken “bu takvim haftası” ifadesi kullanılsın (yanlış anlama riskini düşürür).

- [ ] Onaylandı / [ ] Değiştirildi: ___________

---

## K3 — Grup silinince geçmiş istisnalar

**Soru:** Cascade silinsin mi, arşivlensin mi?

**Öneri: Cascade sil (SwiftData `deleteRule: .cascade` zaten `03`’te var).**  
Geçmiş istisna arşivi v1 kapsamı dışı (YAGNI). Local-first + 90 gün purge ile geçmiş zaten incelir.

- [ ] Onaylandı / [ ] Değiştirildi: ___________

---

## K4 — Critical Alert reddedilirse konumlandırma

**Soru:** Entitlement yoksa “sessiz modu delme” vaadi?

**Öneri:** App Store / pazarlama metninde **garanti yok**.  
v1: Time-Sensitive bildirimler + dürüst açıklama. Critical Alert: Faz 4 başvurusu; reddedilirse özellik kapalı kalır, ürün F1–F4 ile ayakta durur (NG4).

- [ ] Onaylandı / [ ] Değiştirildi: ___________

---

## Tutarlılık düzeltmeleri (doküman drift)

Onay sonrası ilgili docs güncellenir:

| Konu | Karar önerisi |
|---|---|
| Undo süresi | Watch **10 sn**; telefon snackbar **8 sn** (`01` Akış 3). E2E-3 metni “10 sn içinde geri al” olarak hizalanır. |
| Takvim renkleri | Yeşil = normal, turuncu = istisna, gri = tüm gruplar pasif (`00` F4). `01` Akış 5’teki “gri = istisna” çelişkisi düzeltilir. |
| HealthKit izin zamanı | Onboarding’de değil; S7’de F5 açılırken (`07` önerisi). |
| `WatchMessage` undo | Faz 3 öncesi `03`’e `wakeUndone(groupId:timestamp:)` (veya eşdeğeri) eklenir. |

- [ ] Drift düzeltmeleri docs’a işlendi (Faz 2 başı)

---

## Onay kaydı

| Rol | İsim | Tarih |
|---|---|---|
| Ürün | | |
| Teknik | | |
