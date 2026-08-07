# Veri Modeli ve Arayüz Sözleşmeleri (Rev. 3 — Alarm-First)
## Akıllı Alarm Uygulaması

**İlişkili doküman:** `02-teknik-mimari.md`  
**Değişiklik notu:** Rev. 3 — `Alarm` birincil varlık; `AlarmGroup` isteğe bağlı kapsayıcı. Aralık üreteci kaldırıldı. Spec: `docs/superpowers/specs/2026-08-06-alarm-first-model-design.md`.

---

## 1. Veri Şeması (SwiftData — `AlarmAppCore`)

```swift
@Model
final class AlarmGroup {
    @Attribute(.unique) var id: UUID
    var name: String
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Alarm.group)
    var alarms: [Alarm] = []

    @Relationship(deleteRule: .cascade, inverse: \AlarmException.group)
    var exceptions: [AlarmException] = []
}

@Model
final class Alarm {
    @Attribute(.unique) var id: UUID
    var title: String
    var time: ClockTime
    var daysOfWeek: [Weekday]
    var soundId: String          // AlarmSoundCatalog id; "default" = sistem bildirimi
    var soundVolume: Double      // 0.0…1.0 (UI yüzde; Domain clamp)
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
    var group: AlarmGroup?

    @Relationship(deleteRule: .cascade, inverse: \AlarmInstance.alarm)
    var instances: [AlarmInstance] = []
}

@Model
final class AlarmInstance {
    @Attribute(.unique) var id: UUID
    var alarm: Alarm?
    var scheduledDate: Date
    var scheduledTime: ClockTime
    var status: AlarmStatus
    var cancelledReason: CancelReason?
    var updatedAt: Date
}

@Model
final class AlarmException { /* group?, type, startDate, endDate?, action, … */ }

@Model
final class WakeEventLog { /* groupId, detectedAt, source, confirmed */ }
```

**Ses kataloğu:** `AlarmSoundCatalog` — `default` + bundle CC0 `.caf` tonları (`classic_bell`, `digital_beep`, …). Katalog `id` ↔ dosya adı aynı kalmalı.  
**Veri temizliği:** 90 günden eski `fired`/`cancelled` kayıtlar arka planda temizlenir.  
**Migration:** 0.0.x şema kırılması kabul; temiz kurulum.

---

## 2. Watch — Hafif Önbellek

```swift
struct TodayContext: Codable {
    let date: Date
    let activeGroups: [ActiveGroupSummary]  // gruplu sabah senaryosu
}

struct ActiveGroupSummary: Codable, Identifiable {
    let id: UUID
    let name: String
    var remainingInstances: [InstanceSummary]
}
```

---

## 3. Domain Arayüzü

```swift
protocol AlarmRepository {
    func createAlarm(from prepared: PreparedAlarm) async throws -> CreateAlarmResult
    func createGroup(name: String) async throws -> UUID
    func assignAlarm(alarmId: UUID, to groupId: UUID?) async throws
    func cancelToday(groupId: UUID) async throws -> [UUID]
    func cancelToday(alarmId: UUID) async throws -> [UUID]
    func skipWeek(groupId: UUID, weekStart: Date) async throws
    func scheduleException(_ draft: AlarmExceptionDraft) async throws
    func handleWakeEvent(groupId: UUID, source: WakeSource, timestamp: Date) async throws
    func todayContext() async throws -> TodayContext
    func fetchActiveAlarms() async throws -> [AlarmSummary]
    func fetchActiveGroups() async throws -> [AlarmGroupSummary]
    func instances(on day: Date) async throws -> [DayAlarmItem]
}

protocol NotificationScheduling {
    func prepareCategories() async
    func requestAuthorization() async throws -> Bool
    func schedule(
        instanceId: UUID,
        fireDate: Date,
        title: String,
        body: String,
        soundId: String,
        soundVolume: Double
    ) async throws
    func cancelPending(instanceIds: [UUID]) async
}
```

`AlarmSchedule` oluşturma / uzatma / erteleme yolları aynı `soundId` + `soundVolume` taşır. Critical Alert yokken (`criticalAlertsEnabled` varsayılan `false`) normal bildirim sesi kullanılır; düzey Critical entitlement ile anlamlıdır (K4).
