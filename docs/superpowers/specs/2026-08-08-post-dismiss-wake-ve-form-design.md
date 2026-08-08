# Post-dismiss uyanma önerisi, kompakt form, AppLog — Tasarım notu

**Tarih:** 2026-08-08  
**Durum:** Uygulandı  
**İlişkili:** `2026-08-07-uyanma-ertele-ve-saat-ui-design.md`, PRD fail-safe, NG2 local-first

## Kararlar

1. **Apple Saat Uyku Programı okunamaz** (public API yok). Uygulamadaki Saat-benzeri `isWakeSchedule` kartı korunur.
2. **Birincil uyanma sinyali:** Watch’ta alarm **kapatıldıktan sonra**, aynı grupta bugün kalan pending varsa soft prompt:
   - “Uyandın mı? Bu gruptaki kalan alarmları kapatayım mı?”
   - Evet → `cancel(.groupToday, reason: .wakePrompt)`; Hayır / yok say → no-op
3. Erken sensör prompt’u (S7) **ikincil** kalır.
4. Create formu: Disclosure’lar kapalı; `repeats` varsayılan `false`; ses menü picker.
5. **AppLog** (`os.Logger` + test `LogSink`): fail-safe catch yollarına log; analitik SDK yok.

## Kapsam dışı

- Apple Clock Sleep Schedule / Shortcuts köprüsü
- F5 FP kalibrasyonu (v2)
- Ağır Calendar/fetch perf rewrite
