# Veri Modeli ve Arayüz Sözleşmeleri (Rev. 2 — Tamamen Native Swift)
## Akıllı Alarm Uygulaması

**İlişkili doküman:** `02-teknik-mimari.md`
**Değişiklik notu:** Önceki revizyondaki "Platform Kanal Sözleşmesi" (MethodChannel/EventChannel) bölümü tamamen kaldırıldı — artık gerek yok. Veri şeması SQL yerine SwiftData `@Model` sınıfları olarak ifade ediliyor.

---

## 1. Veri Şeması (SwiftData — `AlarmAppCore` paketi içinde, iPhone tarafı tek doğruluk kaynağı)

```swift
import SwiftData
import Foundation

// Not: Saat alanları uygulamada `ClockTime` (saat+dakika, Codable) olarak saklanır;
// dokümandaki DateComponents ile aynı bilgi modelidir.

@Model
final class AlarmGroup {
    @Attribute(.unique) var id: UUID
    var name: String
    var timeStart: DateComponents      // saat/dakika
    var timeEnd: DateComponents
    var intervalMinutes: Int
    var daysOfWeek: [Weekday]          // enum: mon, tue, wed, thu, fri, sat, sun
    var soundId: String
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \AlarmInstance.group)
    var instances: [AlarmInstance] = []

    @Relationship(deleteRule: .cascade)
    var exceptions: [AlarmException] = []
}

@Model
final class AlarmInstance {
    @Attribute(.unique) var id: UUID
    var group: AlarmGroup?
    var scheduledDate: Date            // gün başlangıcı (00:00, yerel)
    var scheduledTime: DateComponents  // "06:25"
    var status: AlarmStatus            // enum: pending, fired, cancelled, snoozed
    var cancelledReason: CancelReason? // enum: wakeWatch, manualToday, manualWeek, exception
    var updatedAt: Date
}

@Model
final class AlarmException {
    @Attribute(.unique) var id: UUID
    var group: AlarmGroup?             // nil ise tüm gruplar için geçerli
    var type: ExceptionType            // enum: singleDay, dateRange, weeklyOverride
    var startDate: Date
    var endDate: Date?                 // dateRange için dolu
    var action: ExceptionAction        // enum: skip, replace
    var replacementGroupId: UUID?
    var createdAt: Date
}

@Model
final class WakeEventLog {
    @Attribute(.unique) var id: UUID
    var groupId: UUID
    var detectedAt: Date
    var source: WakeSource             // enum: watchManual, watchAuto, phoneManual
    var confirmed: Bool
    var createdAt: Date
}
```

**Indeksleme notu:** SwiftData, `#Index` makrosuyla (iOS 18+) veya sorgu tarafında `#Predicate` optimizasyonuyla `(group, scheduledDate)` bileşimini hızlandırabilir. GRDB'ye geçilirse bu doğrudan bir composite SQL index'e karşılık gelir.

**Veri temizliği politikası:** Değişmedi — 90 günden eski `fired`/`cancelled` kayıtlar arka planda (`BGAppRefreshTask` ile) temizlenir.

**Migration:** `SchemaMigrationPlan` ile versiyonlu şema geçişleri tanımlanır; her yeni alan/model değişikliği yeni bir `VersionedSchema` olarak eklenir, `MigrationStage.lightweight` veya `.custom` ile geçiş kuralları yazılır.

---

## 2. Watch Tarafı — Hafif Önbellek (değişmedi kavramsal olarak, artık SwiftData ile)

Watch, tam veri modelini tutmaz; iPhone'dan `updateApplicationContext` ile gelen "bugünkü aktif gruplar" verisini kendi küçük SwiftData store'unda (veya basitçe `Codable` + dosya sistemi) saklar:

```swift
struct TodayContext: Codable {
    let date: Date
    let activeGroups: [ActiveGroupSummary]
}

struct ActiveGroupSummary: Codable, Identifiable {
    let id: UUID            // groupId
    let name: String
    var remainingInstances: [InstanceSummary]
}

struct InstanceSummary: Codable, Identifiable {
    let id: UUID
    let time: DateComponents
    var status: AlarmStatus
}
```

---

## 3. Domain Katmanı Arayüzü (AlarmAppCore — artık "platform kanalı" değil, doğrudan protokol)

Önceki mimaride Dart↔Swift arasında JSON serileştirilen bir "sözleşme" gerekiyordu. Artık iOS ve watchOS target'ları aynı Swift tiplerini doğrudan import ettiği için, sözleşme basitçe bir **protokol arayüzü**:

```swift
protocol AlarmRepository {
    func createGroup(_ group: AlarmGroup) async throws
    func cancelToday(groupId: UUID) async throws
    func skipWeek(groupId: UUID, weekStart: Date) async throws
    func scheduleException(_ exception: AlarmException) async throws
    func handleWakeEvent(groupId: UUID, source: WakeSource, timestamp: Date) async throws
    func todayContext() async throws -> TodayContext
}

protocol NotificationScheduling {
    func schedule(instance: AlarmInstance) async throws
    func cancelPending(instanceIds: [UUID]) async
}

protocol WatchConnectivityService {
    func send(_ message: WatchMessage) async throws
    var incomingMessages: AsyncStream<WatchMessage> { get }
}
```

Bu protokoller `AlarmAppCore` paketinde tanımlanır; iOS ve watchOS target'ları kendi somut implementasyonlarını (ör. iOS'ta tam `SwiftDataAlarmRepository`, Watch'ta hafif `WatchCacheAlarmRepository`) enjekte eder. Bu, önceki mimarideki MethodChannel sözleşmesinin yerini alıyor — **JSON serileştirme yok, doğrudan tip-güvenli Swift çağrısı var.**

---

## 4. WatchConnectivity Mesaj Sözleşmesi (değişmedi — bu zaten native bir API'ydi)

```swift
enum WatchMessage: Codable {
    case todayContextUpdate(TodayContext)          // iPhone → Watch, updateApplicationContext
    case wakeConfirmed(groupId: UUID, timestamp: Date)  // Watch → iPhone, sendMessage/transferUserInfo
}
```

**Teslimat garantisi stratejisi (değişmedi):**
1. `WCSession.sendMessage` dene (anlık, `isReachable == true` ise)
2. Başarısız olursa `WCSession.transferUserInfo` ile kuyrukla (garanti teslimat, iPhone arka planda bile olsa işlenir)

```swift
func send(_ message: WatchMessage) async throws {
    let data = try JSONEncoder().encode(message)
    if session.isReachable {
        session.sendMessage(["payload": data], replyHandler: nil) { error in
            // fallback: transferUserInfo
        }
    } else {
        session.transferUserInfo(["payload": data])
    }
}
```

---

## 5. HealthKit Sorgu Şeması (v2, F5 — değişmedi, zaten native Swift'ti)

```swift
let heartRateType = HKQuantityType(.heartRate)
let query = HKAnchoredObjectQuery(
    type: heartRateType,
    predicate: predicateForAlarmWindow,
    anchor: nil,
    limit: HKObjectQueryNoLimit
) { ... }

let sleepType = HKCategoryType(.sleepAnalysis)
```

Heuristik girdiler (değişmedi): bazal nabza göre artış + `CMMotionActivity` hareket sinyali → kullanıcı onayına sunulan "olası uyanma" event'i.

---

## 6. Veri Gizliliği Notları (değişmedi)

- HealthKit verisi cihaz dışına hiçbir zaman gönderilmez.
- `WakeEventLog` opsiyoneldir, ayarlardan kapatılabilir/temizlenebilir.
- Üçüncü taraf analytics SDK'sı yok.
- **Ek not (Swift-only avantajı):** Flutter köprüsünün olmaması, veri akışının uçtan uca tek bir dilde ve tek bir process modelinde izlenebilir olması anlamına gelir — güvenlik denetimi (audit) için daha az yüzey alanı.
