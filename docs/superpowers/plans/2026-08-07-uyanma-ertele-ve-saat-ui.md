# Uyanma Onayı, Erteleme ve Saat-UI — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Alarm bazlı erteleme, iki katmanlı çalma/kapat UI (iOS + Watch), Saat-benzeri liste, ve Apple-benzeri erken-uyanma prompt’u (HealthKit Sleep + hareket; onaysız iptal yok).

**Architecture:** Domain use case’ler ve repository metotları `AlarmAppCore` içinde TDD ile; UI iOS/Watch target’larda; WatchConnectivity ile offline-first sync; `WakeDetectionEngine` yalnızca prompt üretir, cancel etmez.

**Tech Stack:** Swift 5.9+, SwiftUI, SwiftData, XCTest, UNUserNotificationCenter, WatchConnectivity, HealthKit, CoreMotion (iOS 17+ / watchOS 10+).

**Spec:** `docs/superpowers/specs/2026-08-07-uyanma-ertele-ve-saat-ui-design.md`

## Global Constraints

- Local-first; bulut/analytics yok.
- `AlarmAppCore` SwiftUI import etmez (Foundation / SwiftData / WatchConnectivity / HealthKit / CoreMotion OK).
- Fail-safe: belirsizlik veya cevap yok → alarmlar devam; sessiz iptal yok.
- `WatchMessage` case eklenince aynı changeset’te `docs/03` güncellenir.
- Ajan doğrulaması: `cd AlarmAppCore && swift test` — tam `xcodebuild` varsayılan değil.
- Commit: Conventional Commits + Türkçe özet; IDE/AI trailer yok (`alarmapp-commits`).
- Model: yalnızca Auto.

---

## File map

| Path | Responsibility |
|---|---|
| `AlarmAppCore/.../Enums.swift` | `CancelReason` genişletme |
| `AlarmAppCore/.../Models.swift` | `Alarm` snooze + wake schedule alanları |
| `AlarmAppCore/.../CreateAlarm.swift` | Request/Prepared alanları |
| `AlarmAppCore/.../SnoozePolicy.swift` | Süre clamp + fireDate hesabı (pure) |
| `AlarmAppCore/.../BulkCancelScope.swift` | Scope enum + pencere filtresi (pure) |
| `AlarmAppCore/.../WakeSchedulePolicy.swift` | Tek `isWakeSchedule` invariant (pure) |
| `AlarmAppCore/.../Protocols.swift` | Repository + özet tipleri |
| `AlarmAppCore/.../SwiftDataAlarmRepository.swift` | dismiss / snooze / bulk / setWake |
| `AlarmAppCore/.../WatchContracts.swift` | Yeni `WatchMessage` case’leri |
| `AlarmAppCore/.../WakeDetectionEngine.swift` | Prompt kararı (pure + protocol) |
| `AlarmAppCore/Tests/...` | Yeni test sınıfları |
| `docs/03-veri-modeli-ve-arayuzler.md` | Şema + mesaj sözleşmesi |
| `AlarmApp-iOS/Views/AlarmListView.swift` | Uyku \| Uyanma + Diğer |
| `AlarmApp-iOS/Views/CreateAlarmView.swift` | Ertele + süre + wake flag |
| `AlarmApp-iOS/Views/AlarmRingingView.swift` | 2 katman çalma UI |
| `AlarmApp-iOS/Views/SettingsView.swift` | F5 / otomatik uyanma toggle |
| `AlarmApp-Watch/...` | Çalma + prompt UI + detection wiring |
| `AlarmAppCore/.../Connectivity/` | WCSession gerçek implementasyon (placeholder’dan) |
| `CHANGELOG.md` / `VERSION` / `memory.md` | Kullanıcı notları + kapı |

---

### Task 1: Snooze policy + CancelReason + Alarm alanları (Core)

**Files:**
- Create: `AlarmAppCore/Sources/AlarmAppCore/Domain/SnoozePolicy.swift`
- Modify: `AlarmAppCore/Sources/AlarmAppCore/Domain/Enums.swift`
- Modify: `AlarmAppCore/Sources/AlarmAppCore/Data/Models.swift`
- Modify: `AlarmAppCore/Sources/AlarmAppCore/Domain/CreateAlarm.swift`
- Modify: `AlarmAppCore/Sources/AlarmAppCore/Domain/Protocols.swift` (`AlarmSummary`)
- Test: `AlarmAppCore/Tests/AlarmAppCoreTests/SnoozePolicyTests.swift`

**Interfaces:**
- Produces: `SnoozePolicy.clampMinutes(_:) -> Int`, `SnoozePolicy.fireDate(from:minutes:) -> Date`
- Produces: `CancelReason.userDismiss`, `.snoozed`, `.wakePrompt`, `.nextHoursWindow`
- Produces: `Alarm.snoozeEnabled`, `.snoozeMinutes`, `.isWakeSchedule`

- [ ] **Step 1: Failing test — clamp + fireDate**

```swift
final class SnoozePolicyTests: XCTestCase {
    func testClampMinutes() {
        XCTAssertEqual(SnoozePolicy.clampMinutes(0), 1)
        XCTAssertEqual(SnoozePolicy.clampMinutes(9), 9)
        XCTAssertEqual(SnoozePolicy.clampMinutes(99), 30)
    }

    func testFireDate() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let fire = SnoozePolicy.fireDate(from: now, minutes: 9)
        XCTAssertEqual(fire.timeIntervalSince(now), 9 * 60, accuracy: 0.001)
    }
}
```

- [ ] **Step 2: Run test — expect fail**

Run: `cd AlarmAppCore && swift test --filter SnoozePolicyTests`  
Expected: compile fail / `SnoozePolicy` missing

- [ ] **Step 3: Implement `SnoozePolicy` + enum + model fields**

```swift
public enum SnoozePolicy {
    public static let defaultMinutes = 9
    public static let minMinutes = 1
    public static let maxMinutes = 30

    public static func clampMinutes(_ value: Int) -> Int {
        min(max(value, minMinutes), maxMinutes)
    }

    public static func fireDate(from now: Date, minutes: Int) -> Date {
        now.addingTimeInterval(TimeInterval(clampMinutes(minutes) * 60))
    }
}
```

`CancelReason` ekle: `userDismiss`, `snoozed`, `wakePrompt`, `nextHoursWindow`.  
`Alarm` + `PreparedAlarm` + `CreateAlarmRequest` + `AlarmSummary`: `snoozeEnabled` (default true), `snoozeMinutes` (default 9), `isWakeSchedule` (default false).  
`createAlarm` persist sırasında bu alanları yaz.

- [ ] **Step 4: Run tests — expect pass**

Run: `cd AlarmAppCore && swift test --filter SnoozePolicyTests`  
Expected: PASS (mevcut CreateAlarm testleri de yeşil kalsın: `swift test`)

- [ ] **Step 5: Commit**

```bash
TREE=$(git write-tree)
PARENT=$(git rev-parse HEAD)
COMMIT=$(printf '%s\n' "özellik: alarm erteleme alanları ve SnoozePolicy

Alarm bazlı erteleme süresi için domain sabitleri ve model alanlarını ekler." | git commit-tree "$TREE" -p "$PARENT")
git update-ref "refs/heads/$(git branch --show-current)" "$COMMIT"
```

(Önce `git add` ilgili dosyalar; `git commit-tree` yolunu `alarmapp-commits` kuralına göre kullan.)

---

### Task 2: Wake schedule tekillik + BulkCancelScope (pure Domain)

**Files:**
- Create: `AlarmAppCore/Sources/AlarmAppCore/Domain/WakeSchedulePolicy.swift`
- Create: `AlarmAppCore/Sources/AlarmAppCore/Domain/BulkCancelScope.swift`
- Test: `AlarmAppCore/Tests/AlarmAppCoreTests/WakeAndBulkPolicyTests.swift`

**Interfaces:**
- Produces: `WakeSchedulePolicy.applying(selectedId:currentWakeId:) -> UUID?` (yeni wake id; eski temizlenir)
- Produces: `enum BulkCancelScope: Sendable, Equatable, Codable { case groupToday(UUID); case allNextHours(Int); case allToday }`
- Produces: `BulkCancelScope.includes(instanceFire:now:dayStart:dayEnd:groupId:alarmGroupId:) -> Bool`

- [ ] **Step 1: Failing tests**

```swift
func testWakeScheduleReplacesPrevious() {
    let a = UUID(), b = UUID()
    XCTAssertEqual(WakeSchedulePolicy.applying(selectedId: b, currentWakeId: a), b)
}

func testNextHoursOnlyInsideWindow() {
    let now = Date(timeIntervalSince1970: 1_000_000)
    let inside = now.addingTimeInterval(60 * 60)
    let outside = now.addingTimeInterval(4 * 60 * 60)
    let scope = BulkCancelScope.allNextHours(3)
    XCTAssertTrue(scope.includesFireDate(inside, now: now))
    XCTAssertFalse(scope.includesFireDate(outside, now: now))
}
```

Helper: `includesFireDate` `allNextHours` için `[now, now + hours*3600)` yarı açık aralık.

- [ ] **Step 2: Run — expect fail**

Run: `cd AlarmAppCore && swift test --filter WakeAndBulkPolicyTests`

- [ ] **Step 3: Implement policies**

`WakeSchedulePolicy.applying` seçilen id’yi döner (repository eski flag’i temizler).  
`BulkCancelScope` + fireDate üyelik:

```swift
public enum BulkCancelScope: Codable, Sendable, Equatable {
    case groupToday(UUID)
    case allNextHours(Int)
    case allToday

    public func includesFireDate(_ fire: Date, now: Date) -> Bool {
        switch self {
        case .allNextHours(let hours):
            let end = now.addingTimeInterval(TimeInterval(max(hours, 0) * 3600))
            return fire >= now && fire < end
        case .groupToday, .allToday:
            return true // day/group filtering done by repository with calendar
        }
    }
}
```

- [ ] **Step 4: `swift test --filter WakeAndBulkPolicyTests` → PASS**

- [ ] **Step 5: Commit** — `özellik: uyanma schedule ve toplu iptal kapsam politikaları`

---

### Task 3: Repository — dismiss, snooze, bulk cancel, setWakeSchedule

**Files:**
- Modify: `AlarmAppCore/Sources/AlarmAppCore/Domain/Protocols.swift`
- Modify: `AlarmAppCore/Sources/AlarmAppCore/Data/SwiftDataAlarmRepository.swift`
- Test: `AlarmAppCore/Tests/AlarmAppCoreTests/AlarmActionRepositoryTests.swift`  
  (In-memory `ModelContainer` — mevcut testlerdeki factory varsa onu kullan; yoksa `ModelContainerFactory` ile ephemeral container.)

**Interfaces:**
- Produces:
  - `dismissAlarm(alarmId:instanceId:now:) async throws -> [UUID]`
  - `snoozeAlarm(alarmId:instanceId:now:) async throws -> AlarmSchedule`
  - `cancel(scope:BulkCancelScope, now:) async throws -> [UUID]`
  - `setWakeScheduleAlarm(alarmId: UUID?) async throws`
- Consumes: Task 1–2 policies; mevcut `cancelPending` scheduler UI tarafında çağrılır — repository cancelled id listesi döner.

- [ ] **Step 1: Failing repository tests** (özet senaryolar)

1. `dismissAlarm` → o instance `cancelled` + `userDismiss`
2. `snoozeAlarm` → eski `snoozed`/`cancelled` + `snoozed`; yeni pending `fireDate ≈ now+snoozeMinutes`; `AlarmSchedule` döner
3. `snoozeEnabled == false` → hata veya no-op error `snoozeDisabled`
4. `cancel(.allNextHours(3))` → yalnızca pencere içi pending
5. `setWakeScheduleAlarm(b)` → yalnızca `b.isWakeSchedule == true`

- [ ] **Step 2: Run — expect fail (protocol methods missing)**

- [ ] **Step 3: Implement repository methods**

`snoozeAlarm`: alarm `snoozeMinutes` oku → `SnoozePolicy.fireDate` → yeni `AlarmInstance` (scheduledDate = startOfDay(fire), scheduledTime from fire) → save.  
`cancel(scope:)`:
- `groupToday` → mevcut `cancelToday(groupId:)` + reason `wakePrompt` veya `manualToday` (çağıran bağlam; varsayılan `manualToday`, wake UI `wakePrompt` geçirebilir — imzaya `reason: CancelReason` ekle).
- `allToday` → günün tüm pending.
- `allNextHours` → fireDate penceresi (instance scheduledDate+time birleşimi).

`handleWakeEvent` mevcut kalsın; UI yeni `cancel(scope:reason:)` kullansın.

- [ ] **Step 4: `swift test` → PASS**

- [ ] **Step 5: Commit** — `özellik: ertele dismiss ve toplu iptal repository metotları`

---

### Task 4: WatchMessage + docs/03 + Codable tests

**Files:**
- Modify: `AlarmAppCore/Sources/AlarmAppCore/Domain/WatchContracts.swift`
- Modify: `docs/03-veri-modeli-ve-arayuzler.md`
- Test: `AlarmAppCore/Tests/AlarmAppCoreTests/WatchMessageTests.swift`

**Interfaces:**
- Produces:
```swift
public enum WatchMessage: Codable, Sendable {
    case todayContextUpdate(TodayContext)
    case wakeConfirmed(groupId: UUID, timestamp: Date)
    case snoozeApplied(alarmId: UUID, instanceId: UUID, fireDate: Date)
    case dismissApplied(alarmId: UUID, instanceId: UUID)
    case bulkCancelApplied(scope: BulkCancelScope, timestamp: Date)
}
```

- [ ] **Step 1: Round-trip tests for each new case**

- [ ] **Step 2: Run — fail**

- [ ] **Step 3: Implement enum + update `docs/03` Alarm alanları, CancelReason, repository, WatchMessage**

- [ ] **Step 4: `swift test --filter WatchMessageTests` → PASS**

- [ ] **Step 5: Commit** — `özellik: WatchMessage ertele ve toplu iptal senkron case’leri`

---

### Task 5: iOS S1/S2 Saat-benzeri UI + ertele alanları

**Files:**
- Modify: `AlarmApp-iOS/Views/AlarmListView.swift`
- Modify: `AlarmApp-iOS/Views/CreateAlarmView.swift`
- Modify: `AlarmApp-iOS/Views/AlarmDetailView.swift` (gerekirse)
- Modify: `AlarmApp-iOS/Localizable.xcstrings`
- Skill: `.cursor/skills/apple-feel-swiftui/SKILL.md`

**Interfaces:**
- Consumes: `Alarm.isWakeSchedule`, snooze fields, `setWakeScheduleAlarm`
- Produces: Kullanıcıya Uyku kartı + Diğer liste; formda Ertele toggle + süre picker (1…30, varsayılan 9)

- [ ] **Step 1: AlarmListView — iki bölüm**

Üst kart: wake schedule alarm veya “Alarm Yok” + DEĞİŞTİR.  
`Diğer`: `alarms.filter { !$0.isWakeSchedule }`.  
Tipografi: büyük saat, gri meta, yeşil toggle, turuncu DEĞİŞTİR (spec §3.5).

- [ ] **Step 2: CreateAlarmView / edit**

Toggle Ertele; açıksa `Picker`/`Step` Erteleme süresi.  
Opsiyonel “Uyku / uyanma alarmı” toggle → save’de `setWakeScheduleAlarm`.  
Tekerlek `DatePicker` `.wheel` hourAndMinute (Saat hissi).

- [ ] **Step 3: İnsan Xcode Preview / Run** (ajan `xcodebuild` atlar)

- [ ] **Step 4: Commit** — `özellik: Saat benzeri alarm listesi ve erteleme formu`

---

### Task 6: Çalma UI (iOS + Watch) + bildirim aksiyonları

**Files:**
- Create: `AlarmApp-iOS/Views/AlarmRingingView.swift`
- Create: `AlarmApp-Watch/Views/AlarmRingingView.swift` (veya mevcut Watch target yapısına uygun path)
- Modify: `AlarmApp-Watch/AlarmApp_WatchApp.swift` — placeholder kaldır
- Modify: bildirim delegate / category wiring (iOS app entry)
- Modify: `Localizable.xcstrings` (+ Watch strings varsa)

**Interfaces:**
- Consumes: `dismissAlarm`, `snoozeAlarm`, `cancel(scope:reason:)`
- Ekran 1: Kapat / Ertele (snoozeEnabled) / Daha fazla  
- Ekran 2: grup bugünü (groupId nil ise gizli) / 3 saat / bugün tümü  
- Vazgeç → dismiss sheet, no-op

- [ ] **Step 1: Paylaşılan view model logic tercihen Core’da değil UI’da — aksiyonlar doğrudan repo**

```swift
enum RingingPrimaryAction { case dismiss, snooze, more }
enum RingingBulkAction { case groupToday, nextThreeHours, allToday }
```

- [ ] **Step 2: iOS fullScreenCover / notification response → AlarmRingingView**

- [ ] **Step 3: Watch aynı 2 katman; buton ≥ 44pt; haptic on confirm**

- [ ] **Step 4: UNNotificationCategory — Ertele alarm `snoozeMinutes` kullanacak şekilde (sabit 5 dk kaldır)**

Mevcut `AlarmNotificationAction.snooze` handler’ı repository `snoozeAlarm` çağırsın.

- [ ] **Step 5: Commit** — `özellik: telefon ve Watch çalma ekranı aksiyonları`

---

### Task 7: WatchConnectivity gerçek köprü + sync handlers

**Files:**
- Replace/extend: `AlarmAppCore/Sources/AlarmAppCore/Connectivity/ConnectivityPlaceholder.swift` → `WCSessionWatchConnectivity.swift` (Core’da WCSession OK)
- iOS + Watch app: session activate, incoming `WatchMessage` → repository
- Skill: `.cursor/skills/watch-connectivity-safe/SKILL.md`

**Interfaces:**
- `sendMessage` if reachable else `transferUserInfo`
- iPhone→Watch today: `updateApplicationContext`
- Incoming: `snoozeApplied` / `dismissApplied` / `bulkCancelApplied` / `wakeConfirmed` → idempotent repo

- [ ] **Step 1: Unit — encode payload round-trip already Task 4; burada service protocol fake ile send yolu test edilebilir**

- [ ] **Step 2: Implement service + wire both apps**

- [ ] **Step 3: PR notu şablonu — gerçek cihaz E2E (simülatör iddiası yok)**

- [ ] **Step 4: Commit** — `özellik: WatchConnectivity ile ertele ve iptal senkronu`

---

### Task 8: WakeDetectionEngine + Watch prompt + S7 toggle

**Files:**
- Create: `AlarmAppCore/Sources/AlarmAppCore/Domain/WakeDetectionEngine.swift`
- Create: Watch sensor adapter (Watch target) — HK + CM okur, engine’e sample verir
- Modify: `AlarmApp-iOS/Views/SettingsView.swift` + `AppPreferences.swift`
- Test: `AlarmAppCore/Tests/AlarmAppCoreTests/WakeDetectionEngineTests.swift`

**Interfaces:**
```swift
public struct WakeDetectionConfig: Sendable {
    public var windowHoursBeforeWake: Int // 4
    public var cooldownMinutes: Int // 20
    public var isEnabled: Bool
}

public enum WakeDetectionEvent: Sendable, Equatable {
    case offerPrompt(at: Date)
}

public struct WakeDetectionEngine: Sendable {
    public func evaluate(
        now: Date,
        wakeAlarmFire: Date?,
        sleepBecameAwake: Bool,
        motionAboveThreshold: Bool,
        lastPromptAt: Date?,
        config: WakeDetectionConfig
    ) -> WakeDetectionEvent?
}
```

Kurallar:
- `wakeAlarmFire` nil veya `now` pencere dışında → nil
- `config.isEnabled == false` → nil
- cooldown içinde → nil
- `sleepBecameAwake || motionAboveThreshold` → `.offerPrompt`
- **asla** repository cancel çağırmaz

Watch UI: prompt → Evet → Ringing bulk (varsayılan grup bugünü / wake alarm) · Hayır → no-op.

S7: “Otomatik uyanma sorusu” toggle → `AppPreferences` / UserDefaults; HealthKit izni istenince.

- [ ] **Step 1: Engine birim testleri (pencere, cooldown, fail-safe)**

- [ ] **Step 2: Implement engine**

- [ ] **Step 3: Watch wiring + Settings toggle (izin yoksa disabled açıklama)**

- [ ] **Step 4: `swift test` → PASS**

- [ ] **Step 5: Commit** — `özellik: Watch erken uyanma algılama ve onay promptu`

---

### Task 9: Dokümanlar, sürüm, memory

**Files:**
- Modify: `docs/07-detayli-ekran-ve-fonksiyon-spesifikasyonu.md` (S1/S2/S6/W1)
- Modify: `docs/00` / `docs/04` — F5 bu milestone notu (kısa)
- Modify: `CHANGELOG.md`, `VERSION` (örn. `0.0.7`), `memory.md`

- [ ] **Step 1: CHANGELOG kullanıcı Türkçe** — ertele süre, çalma seçenekleri, Watch “Uyandın mı?”, Saat listesi; jargon yok

- [ ] **Step 2: memory kapıları işaretle**

- [ ] **Step 3: Commit** — `belgeler: uyanma ertele milestone sürüm notları`

---

## Spec coverage checklist

| Spec § | Task |
|---|---|
| Ertele alanları / S2 | 1, 5 |
| Bulk scope 3h / today / group | 2, 3, 6 |
| Çalma 2 katman | 6 |
| Saat liste UI | 5 |
| WatchMessage | 4, 7 |
| WakeDetection / Apple prompt | 8 |
| Fail-safe / cooldown | 8 |
| docs/03 | 4 |
| CHANGELOG | 9 |

## Self-review notes

- Placeholder yok; sahte workout session yok (spec ile uyumlu).
- `CancelReason.snoozed` ile `AlarmStatus.snoozed` karışmasın: status instance’da `cancelled` veya `snoozed`; reason `snoozed` — Task 3’te tek seçim: status `.snoozed`, reason `.snoozed`.
- `handleWakeEvent` legacy; yeni UI `cancel(scope:reason: .wakePrompt)` kullanır.

---

## Execution handoff

Plan kaydedildi: `docs/superpowers/plans/2026-08-07-uyanma-ertele-ve-saat-ui.md`

**İki yürütme seçeneği:**

1. **Subagent-Driven (önerilen)** — her task için ayrı subagent, arada review  
2. **Inline Execution** — bu oturumda `executing-plans` ile sırayla

Hangisini istiyorsun?
