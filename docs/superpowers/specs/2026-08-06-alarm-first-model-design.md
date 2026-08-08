# Alarm-First Model Design

**Tarih:** 2026-08-06  
**Durum:** Kilitli — uygulama planı ile uyumlu  
**Üstür:** Aralık üreten `AlarmGroup` modeli (eski F1 / K1 aralık matematiği)

---

## Kararlar

1. **Alarm birincil.** Her alarm tek başına kurulur: `title`, `time` (`ClockTime`), `daysOfWeek`, `soundId`, `isActive`.
2. **Grup isteğe bağlı.** `Alarm.group` 0 veya 1. Tekil alarm geçerlidir.
3. **Grup işi.** İsim + toplu aksiyon (“Uyandım”, “Bugün kapat”, “Bu hafta pas geç”). Zaman / aralık / gün **grupta yok**.
4. **Aralık üreteci yok.** `timeStart` / `timeEnd` / `intervalMinutes` kaldırıldı. Eski K1 geçersiz.
5. **Takvim.** Ay görünümünde o güne düşen `AlarmInstance` noktaları; güne dokununca alarm listesi.
6. **Grup silinince** alarmlar **grupsuz** kalır (`nullify`). Alarm silinince instance’lar cascade.

```
AlarmGroup (optional) ──< Alarm ──< AlarmInstance
```

---

## Şema (özet)

| Model | Alanlar |
|---|---|
| `AlarmGroup` | `id`, `name`, `isActive`, `createdAt`, `updatedAt`, `alarms[]` |
| `Alarm` | `id`, `title`, `time`, `daysOfWeek`, `soundId`, `isActive`, `group?`, `instances[]` |
| `AlarmInstance` | `id`, `alarm?`, `scheduledDate`, `scheduledTime`, `status`, `cancelledReason?` |

Horizon: `CreateAlarm` seçili hafta günlerinde `horizonDays` (varsayılan 14) kadar instance üretir.

---

## Use case’ler

- `CreateAlarm` (+ isteğe bağlı `groupId`)
- `CreateGroup` (sadece isim)
- `assignAlarm` / `removeAlarmFromGroup`
- `cancelToday(groupId:)` / `cancelToday(alarmId:)`
- Çakışma: aynı gün kümesi ∩ aynı saat → uyarı (`AlarmOverlapDetector`)

---

## UI

- S1: Alarm listesi; grup badge; `+` → yeni alarm; Tab: Alarmlar | Takvim
- S2: `CreateAlarmView`
- S3: Alarm detay (instance listesi)
- S4: Ay ızgarası + gün detayı
