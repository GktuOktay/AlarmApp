# Ürün Kararları — F1–F4 Öncesi Kilit

**Tarih:** 2026-08-06  
**Durum:** Kilitli (önerilen değerler — F1 koduna geçiş ile onaylandı)  
**Kaynak:** `docs/00-PRD-urun-gereksinim-dokumani.md` §7

---

## Mimari sabit

- Uygulama **tamamen cihaz üzerinde** çalışır; sunucu / bulut zorunluluğu yoktur (local-first, PRD G5 / NG2).

---

## K1 — Alarm aralığı: bitiş saati dahil

**Karar: Bitiş dahil (inclusive–inclusive).**  
06:00–07:00, 5 dk → **13** alarm (06:00 … 07:00).  
Algoritma: `t = start; while t <= end; t += interval` (`Calendar` / dakika aritmetiği).

- [x] Onaylandı

---

## K2 — “Bu hafta pas geç”

**Karar: Takvim haftası, Pazartesi başlangıç.**  
`SkipWeek` → o haftanın Pzt 00:00 … Paz gün sonu.

- [x] Onaylandı

---

## K3 — Grup silinince istisnalar

**Karar: Cascade sil** (`deleteRule: .cascade`).

- [x] Onaylandı

---

## K4 — Critical Alert

**Karar:** Sessiz modu delme **garanti edilmez**. Time-Sensitive + dürüst App Store metni; entitlement yoksa F1–F4 ayakta kalır.

- [x] Onaylandı

---

## Tutarlılık

| Konu | Kilit |
|---|---|
| Undo | Watch 10 sn; telefon snackbar 8 sn |
| Takvim renkleri | Yeşil normal / turuncu istisna / gri tümü pasif |
| HealthKit izni | S7’de F5 açılırken (onboarding zorunlu değil) |

- [ ] Drift düzeltmeleri `docs/01` / `05` metinlerine işlenecek (ayrı PR)

## Onay kaydı

| Rol | Not | Tarih |
|---|---|---|
| Ürün/Teknik | F1’e geçiş + local-first teyidi | 2026-08-06 |
