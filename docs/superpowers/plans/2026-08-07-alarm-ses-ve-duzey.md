# Alarm Ses ve Ses Düzeyi Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Alarm başına CC0 uygulama sesi seçimi + `soundVolume` (0…1), bildirimde ses mapping, S2’de önizleme ve kaydırıcı.

**Architecture:** Katalog ve volume clamp Domain’de (`AlarmSoundCatalog`, `NotificationSoundResolver`). SwiftData `Alarm.soundVolume`. iOS bundle’da `.caf` dosyaları. `LocalNotificationScheduler` Critical entitlement yokken normal ses kullanır (K4). Önizleme yalnızca iOS (`AVAudioPlayer`).

**Tech Stack:** Swift 5.9+ / SwiftData / UserNotifications / AVFoundation (iOS only) / XCTest (`swift test` in AlarmAppCore)

**Spec:** `docs/superpowers/specs/2026-08-07-alarm-ses-ve-duzey-design.md`

## Global Constraints

- Local-first; no cloud/analytics SDK
- `AlarmAppCore` must not `import SwiftUI`
- Fail-safe: unknown/missing sound → `.default`; never silently skip scheduling
- Critical Alert not guaranteed (K4); volume forced only when `criticalAlertsEnabled == true`
- CC0 / public domain sounds only; no Apple system file copies
- Verify with `swift test` in `AlarmAppCore`; human runs Xcode app
- Commits: Turkish Conventional Commits; no IDE/AI trailers (`git commit-tree` if needed)
- Auto model only

## File map

| File | Responsibility |
|---|---|
| `AlarmAppCore/.../Domain/AlarmSoundCatalog.swift` | Sound list + resolve + clampVolume |
| `AlarmAppCore/.../Domain/NotificationSoundResolver.swift` | Map id/volume/critical → resolved enum |
| `AlarmAppCore/.../Domain/CreateAlarm.swift` | Request/Prepared + volume |
| `AlarmAppCore/.../Domain/Protocols.swift` | AlarmSummary, AlarmSchedule, NotificationScheduling |
| `AlarmAppCore/.../Data/Models.swift` | `Alarm.soundVolume` |
| `AlarmAppCore/.../Data/SwiftDataAlarmRepository.swift` | Persist + pass sound on schedules |
| `AlarmAppCore/.../Data/LocalNotificationScheduler.swift` | UNNotificationSound from resolver |
| `AlarmAppCore/Tests/.../AlarmAppCoreTests.swift` | Catalog / volume / CreateAlarm tests |
| `AlarmApp-iOS/Sounds/*.caf` + `SOUNDS.md` | Assets + license log |
| `AlarmApp-iOS/Sound/AlarmSoundPreview.swift` | AVAudioPlayer preview |
| `AlarmApp-iOS/Views/CreateAlarmView.swift` | Sound section UI |
| `AlarmApp-iOS/Views/AlarmDetailView.swift` | Sound summary |
| `docs/03`, `docs/07`, `docs/01`, `memory.md`, `CHANGELOG.md` | Doc sync |

---

### Task 1: AlarmSoundCatalog + NotificationSoundResolver

**Files:**
- Create: `AlarmAppCore/Sources/AlarmAppCore/Domain/AlarmSoundCatalog.swift`
- Create: `AlarmAppCore/Sources/AlarmAppCore/Domain/NotificationSoundResolver.swift`
- Modify: `AlarmAppCore/Tests/AlarmAppCoreTests/AlarmAppCoreTests.swift` (append new test types)
- Modify: `AlarmAppCore/Sources/AlarmAppCore/AlarmAppCore.swift` only if package needs explicit exports (usually automatic)

**Interfaces:**
- Produces: `AlarmSound`, `AlarmSoundCatalog.resolve`, `AlarmSoundCatalog.clampVolume`, `ResolvedNotificationSound`, `NotificationSoundResolver.resolve`

- [ ] **Step 1: Write failing tests**

Append to `AlarmAppCoreTests.swift`:

```swift
final class AlarmSoundCatalogTests: XCTestCase {
    func testResolveUnknownFallsBackToDefault() {
        let sound = AlarmSoundCatalog.resolve("nope")
        XCTAssertEqual(sound.id, "default")
        XCTAssertNil(sound.fileName)
    }

    func testClampVolume() {
        XCTAssertEqual(AlarmSoundCatalog.clampVolume(-1), 0)
        XCTAssertEqual(AlarmSoundCatalog.clampVolume(0.5), 0.5)
        XCTAssertEqual(AlarmSoundCatalog.clampVolume(2), 1)
    }

    func testCatalogContainsDefaultAndBundledIds() {
        let ids = Set(AlarmSoundCatalog.all.map(\.id))
        XCTAssertTrue(ids.contains("default"))
        XCTAssertTrue(ids.contains("classic_bell"))
        XCTAssertTrue(ids.contains("digital_beep"))
        XCTAssertTrue(ids.contains("mechanical_ring"))
        XCTAssertTrue(ids.contains("electronic_buzz"))
        XCTAssertTrue(ids.contains("soft_chime"))
        XCTAssertTrue(ids.contains("radar_pulse"))
    }
}

final class NotificationSoundResolverTests: XCTestCase {
    func testDefaultWithoutCritical() {
        let r = NotificationSoundResolver.resolve(
            soundId: "default",
            volume: 0.4,
            criticalEnabled: false
        )
        XCTAssertEqual(r, .systemDefault)
    }

    func testNamedWithoutCritical() {
        let r = NotificationSoundResolver.resolve(
            soundId: "classic_bell",
            volume: 0.8,
            criticalEnabled: false
        )
        XCTAssertEqual(r, .named("classic_bell"))
    }

    func testDefaultWithCriticalUsesVolume() {
        let r = NotificationSoundResolver.resolve(
            soundId: "default",
            volume: 0.25,
            criticalEnabled: true
        )
        XCTAssertEqual(r, .criticalDefault(volume: 0.25))
    }

    func testUnknownIdWithCriticalNamedFallsBackDefaultCritical() {
        let r = NotificationSoundResolver.resolve(
            soundId: "missing",
            volume: 1.5,
            criticalEnabled: true
        )
        XCTAssertEqual(r, .criticalDefault(volume: 1.0))
    }
}
```

Catalog ids must be exactly: `default`, `classic_bell`, `digital_beep`, `mechanical_ring`, `electronic_buzz`, `soft_chime`, `radar_pulse`.

- [ ] **Step 2: Run tests — expect FAIL**

```bash
cd AlarmAppCore && swift test --filter AlarmSoundCatalogTests
```

Expected: compile error / missing types.

- [ ] **Step 3: Implement catalog + resolver**

`AlarmSoundCatalog.swift`:

```swift
import Foundation

public struct AlarmSound: Identifiable, Sendable, Equatable {
    public let id: String
    public let displayNameKey: String
    /// Bundle resource name without extension; nil = system default notification sound.
    public let fileName: String?

    public init(id: String, displayNameKey: String, fileName: String?) {
        self.id = id
        self.displayNameKey = displayNameKey
        self.fileName = fileName
    }
}

public enum AlarmSoundCatalog {
    public static let all: [AlarmSound] = [
        AlarmSound(id: "default", displayNameKey: "sound.default", fileName: nil),
        AlarmSound(id: "classic_bell", displayNameKey: "sound.classic_bell", fileName: "classic_bell"),
        AlarmSound(id: "digital_beep", displayNameKey: "sound.digital_beep", fileName: "digital_beep"),
        AlarmSound(id: "mechanical_ring", displayNameKey: "sound.mechanical_ring", fileName: "mechanical_ring"),
        AlarmSound(id: "electronic_buzz", displayNameKey: "sound.electronic_buzz", fileName: "electronic_buzz"),
        AlarmSound(id: "soft_chime", displayNameKey: "sound.soft_chime", fileName: "soft_chime"),
        AlarmSound(id: "radar_pulse", displayNameKey: "sound.radar_pulse", fileName: "radar_pulse"),
    ]

    public static func resolve(_ id: String) -> AlarmSound {
        all.first { $0.id == id } ?? all[0]
    }

    public static func clampVolume(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
```

`NotificationSoundResolver.swift`:

```swift
import Foundation

public enum ResolvedNotificationSound: Equatable, Sendable {
    case systemDefault
    case named(String)
    case criticalDefault(volume: Float)
    case criticalNamed(String, volume: Float)
}

public enum NotificationSoundResolver {
    public static func resolve(
        soundId: String,
        volume: Double,
        criticalEnabled: Bool
    ) -> ResolvedNotificationSound {
        let sound = AlarmSoundCatalog.resolve(soundId)
        let v = Float(AlarmSoundCatalog.clampVolume(volume))
        if criticalEnabled {
            if let file = sound.fileName {
                return .criticalNamed(file, volume: v)
            }
            return .criticalDefault(volume: v)
        }
        if let file = sound.fileName {
            return .named(file)
        }
        return .systemDefault
    }
}
```

- [ ] **Step 4: Run tests — expect PASS**

```bash
cd AlarmAppCore && swift test --filter AlarmSoundCatalogTests && swift test --filter NotificationSoundResolverTests
```

- [ ] **Step 5: Commit**

```bash
# only catalog/resolver + tests; Turkish message via commit-tree if hooks inject trailers
```

Message: `özellik: Alarm ses kataloğu ve bildirim ses çözümleyicisini ekle`

---

### Task 2: soundVolume on domain + CreateAlarm

**Files:**
- Modify: `AlarmAppCore/Sources/AlarmAppCore/Domain/CreateAlarm.swift`
- Modify: `AlarmAppCore/Sources/AlarmAppCore/Domain/Protocols.swift` (`AlarmSummary`)
- Modify: `AlarmAppCore/Sources/AlarmAppCore/Data/Models.swift`
- Modify: `AlarmAppCore/Sources/AlarmAppCore/Data/SwiftDataAlarmRepository.swift` (create + summary mapping)
- Modify: `AlarmAppCore/Tests/AlarmAppCoreTests/AlarmAppCoreTests.swift`

**Interfaces:**
- Consumes: `AlarmSoundCatalog.clampVolume`, `AlarmSoundCatalog.resolve`
- Produces: `CreateAlarmRequest.soundVolume`, `PreparedAlarm.soundVolume`, `Alarm.soundVolume`, `AlarmSummary.soundVolume`

- [ ] **Step 1: Failing test**

```swift
func testPrepareClampsVolumeAndKeepsSoundId() throws {
    let prepared = try CreateAlarm().prepare(
        CreateAlarmRequest(
            title: "Ses",
            time: ClockTime(hour: 6, minute: 0),
            daysOfWeek: [.monday],
            soundId: "classic_bell",
            soundVolume: 1.8,
            repeats: true
        )
    )
    XCTAssertEqual(prepared.soundId, "classic_bell")
    XCTAssertEqual(prepared.soundVolume, 1.0)
}

func testPrepareUnknownSoundBecomesDefault() throws {
    let prepared = try CreateAlarm().prepare(
        CreateAlarmRequest(
            title: "Ses",
            time: ClockTime(hour: 6, minute: 0),
            daysOfWeek: [.monday],
            soundId: "nope",
            soundVolume: 0.3
        )
    )
    XCTAssertEqual(prepared.soundId, "default")
    XCTAssertEqual(prepared.soundVolume, 0.3)
}
```

- [ ] **Step 2: Run — expect FAIL** (missing `soundVolume`)

```bash
cd AlarmAppCore && swift test --filter testPrepareClampsVolumeAndKeepsSoundId
```

- [ ] **Step 3: Implement**

Add to `CreateAlarmRequest`:

```swift
public var soundVolume: Double
// init param: soundVolume: Double = 1.0
```

Add to `PreparedAlarm`:

```swift
public let soundVolume: Double
```

In `CreateAlarm.prepare`, both return paths:

```swift
let soundId = AlarmSoundCatalog.resolve(request.soundId).id
let soundVolume = AlarmSoundCatalog.clampVolume(request.soundVolume)
// pass into PreparedAlarm(...)
```

`Alarm` model:

```swift
public var soundVolume: Double
// init: soundVolume: Double = 1.0
```

`AlarmSummary`: add `soundVolume: Double` (default `1.0` in call sites).

Repo `createAlarm`: pass `soundVolume: prepared.soundVolume` into `Alarm(...)`.  
All `AlarmSummary(...)` constructions: include `soundVolume: alarm.soundVolume`.

Fix every `CreateAlarmRequest` / `PreparedAlarm` / `AlarmSummary` call site that no longer compiles (tests + repo).

- [ ] **Step 4: `swift test` — PASS**

- [ ] **Step 5: Commit**

Message: `özellik: Alarm modeline soundVolume alanını ekle`

---

### Task 3: AlarmSchedule + NotificationScheduling + LocalNotificationScheduler

**Files:**
- Modify: `AlarmAppCore/Sources/AlarmAppCore/Domain/CreateAlarm.swift` (`AlarmSchedule`, optionally `CreateAlarmResult`)
- Modify: `AlarmAppCore/Sources/AlarmAppCore/Domain/Protocols.swift`
- Modify: `AlarmAppCore/Sources/AlarmAppCore/Data/LocalNotificationScheduler.swift`
- Modify: `AlarmAppCore/Sources/AlarmAppCore/Data/SwiftDataAlarmRepository.swift` (every `AlarmSchedule(...)`)
- Modify: `AlarmApp-iOS/Views/CreateAlarmView.swift` (schedule call)
- Modify: `AlarmApp-iOS/AlarmApp_iOSApp.swift` (extend + snooze)

**Interfaces:**
- Consumes: `NotificationSoundResolver.resolve`
- Produces: updated `schedule(instanceId:fireDate:title:body:soundId:soundVolume:)`

- [ ] **Step 1: Extend `AlarmSchedule`**

```swift
public struct AlarmSchedule: Sendable, Equatable, Identifiable {
    public var id: UUID { instanceId }
    public let instanceId: UUID
    public let fireDate: Date
    public let soundId: String
    public let soundVolume: Double

    public init(
        instanceId: UUID,
        fireDate: Date,
        soundId: String = "default",
        soundVolume: Double = 1.0
    ) {
        self.instanceId = instanceId
        self.fireDate = fireDate
        self.soundId = soundId
        self.soundVolume = soundVolume
    }
}
```

Update every `AlarmSchedule(instanceId:fireDate:)` in repo to pass `alarm.soundId` / `alarm.soundVolume`.

- [ ] **Step 2: Protocol + scheduler**

```swift
func schedule(
    instanceId: UUID,
    fireDate: Date,
    title: String,
    body: String,
    soundId: String,
    soundVolume: Double
) async throws
```

`LocalNotificationScheduler`:

```swift
public struct LocalNotificationScheduler: NotificationScheduling {
    private let center: UNUserNotificationCenter
    private let criticalAlertsEnabled: Bool

    public init(
        center: UNUserNotificationCenter = .current(),
        criticalAlertsEnabled: Bool = false
    ) {
        self.center = center
        self.criticalAlertsEnabled = criticalAlertsEnabled
    }

    public func schedule(
        instanceId: UUID,
        fireDate: Date,
        title: String,
        body: String,
        soundId: String,
        soundVolume: Double
    ) async throws {
        guard fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = makeSound(soundId: soundId, soundVolume: soundVolume)
        content.categoryIdentifier = AlarmNotificationAction.categoryId
        content.userInfo = [
            "instanceId": instanceId.uuidString,
            "groupName": title,
            "soundId": soundId,
            "soundVolume": soundVolume,
        ]
        content.interruptionLevel = .timeSensitive
        // trigger + add as today
    }

    private func makeSound(soundId: String, soundVolume: Double) -> UNNotificationSound {
        switch NotificationSoundResolver.resolve(
            soundId: soundId,
            volume: soundVolume,
            criticalEnabled: criticalAlertsEnabled
        ) {
        case .systemDefault:
            return .default
        case .named(let name):
            return UNNotificationSound(named: UNNotificationSoundName(name))
        case .criticalDefault(let volume):
            return .defaultCriticalSound(withAudioVolume: volume)
        case .criticalNamed(let name, let volume):
            return UNNotificationSound.criticalSoundNamed(
                UNNotificationSoundName(name),
                withAudioVolume: volume
            )
        }
    }
}
```

Fail-safe: if named sound missing at runtime, iOS may still deliver without custom sound; do **not** cancel the request. Do not add extra guard that skips `center.add`.

- [ ] **Step 3: Update iOS call sites**

`CreateAlarmView` loop:

```swift
try await scheduler.schedule(
    instanceId: schedule.instanceId,
    fireDate: schedule.fireDate,
    title: result.title,
    body: String(format: String(localized: "notif.alarm_body"), timeText),
    soundId: schedule.soundId,
    soundVolume: schedule.soundVolume
)
```

`AlarmApp_iOSApp` extend loop: same from `schedule.soundId` / `soundVolume`.

Snooze:

```swift
let soundId = (info["soundId"] as? String) ?? "default"
let soundVolume = (info["soundVolume"] as? Double) ?? 1.0
try? await LocalNotificationScheduler().schedule(
    instanceId: instanceId,
    fireDate: fire,
    title: response.notification.request.content.title,
    body: String(localized: "notif.snoozed"),
    soundId: soundId,
    soundVolume: soundVolume
)
```

- [ ] **Step 4: `cd AlarmAppCore && swift test` — PASS**

- [ ] **Step 5: Commit**

Message: `özellik: Bildirim zamanlamasına ses ve düzey parametrelerini bağla`

---

### Task 4: CC0 ses paketini ekle

**Files:**
- Create: `AlarmApp-iOS/Sounds/classic_bell.caf` (and siblings matching catalog `fileName`)
- Create: `AlarmApp-iOS/Sounds/SOUNDS.md`
- Modify: `AlarmApp.xcodeproj/project.pbxproj` and/or `project.yml` so Sounds are in **iOS target Copy Bundle Resources**

**Interfaces:**
- Consumes: catalog file names from Task 1
- Produces: bundle resources loadable by `UNNotificationSound(named:)`

- [ ] **Step 1: Source CC0 WAV/AIFF**

Download only CC0 / public-domain alarm-like tones (e.g. BigSoundBank). Prefer ≤30 s. Map to:

| id / fileName | Character |
|---|---|
| classic_bell | bell / chime |
| digital_beep | short digital beep |
| mechanical_ring | mechanical alarm ring |
| electronic_buzz | electronic buzzer |
| soft_chime | soft chime |
| radar_pulse | repeating pulse |

Do **not** copy Apple system UISounds.

- [ ] **Step 2: Convert to CAF**

```bash
# example per file
afconvert -f caff -d LEI16 source.wav AlarmApp-iOS/Sounds/classic_bell.caf
```

Trim to ≤30 s if needed (`afconvert` / Audacity). Mono preferred.

- [ ] **Step 3: Write `SOUNDS.md`**

```markdown
# AlarmApp sound pack

License bar: CC0 / public domain only.

| id | file | source URL | license | duration |
|---|---|---|---|---|
| classic_bell | classic_bell.caf | https://... | CC0 | 0:xx |
...
```

- [ ] **Step 4: Xcode / XcodeGen**

If using `project.yml`, add under iOS target resources:

```yaml
sources:
  - path: AlarmApp-iOS/Sounds
    buildPhase: resources
```

Regenerate project if that is the project workflow (`xcodegen generate`). Confirm files appear in Copy Bundle Resources for **AlarmApp-iOS** only (not Watch).

- [ ] **Step 5: Commit**

Message: `özellik: CC0 alarm ses paketini iOS bundle'a ekle`

Binary + `SOUNDS.md` + project file in one commit.

---

### Task 5: S2 UI — ses listesi, slider, önizleme

**Files:**
- Create: `AlarmApp-iOS/Sound/AlarmSoundPreview.swift`
- Modify: `AlarmApp-iOS/Views/CreateAlarmView.swift`
- Modify: `AlarmApp-iOS/Localizable.xcstrings` (TR/EN keys for sound names + footer)

**Interfaces:**
- Consumes: `AlarmSoundCatalog.all`, preview helper
- Produces: create flow writes `soundId` + `soundVolume` into `CreateAlarmRequest`

- [ ] **Step 1: Preview helper**

```swift
import AVFoundation
import Foundation
import AlarmAppCore

@MainActor
final class AlarmSoundPreview {
    private var player: AVAudioPlayer?

    func play(soundId: String, volume: Double) {
        player?.stop()
        let sound = AlarmSoundCatalog.resolve(soundId)
        guard let fileName = sound.fileName,
              let url = Bundle.main.url(forResource: fileName, withExtension: "caf")
        else { return } // default = no file preview; optional: skip silently
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.volume = Float(AlarmSoundCatalog.clampVolume(volume))
            player?.play()
        } catch {
            player = nil
        }
    }

    func stop() {
        player?.stop()
        player = nil
    }
}
```

Note: `default` has no bundle file — selecting it stops preview (or no-op). That is OK.

- [ ] **Step 2: CreateAlarmView state + section**

```swift
@State private var soundId = "default"
@State private var soundVolumePercent: Double = 100
@State private var soundPreview = AlarmSoundPreview()

// Section after group or before save:
Section {
    ForEach(AlarmSoundCatalog.all) { sound in
        Button {
            soundId = sound.id
            soundPreview.play(
                soundId: sound.id,
                volume: soundVolumePercent / 100
            )
        } label: {
            HStack {
                Text(LocalizedStringKey(sound.displayNameKey))
                Spacer()
                if sound.id == soundId {
                    Image(systemName: "checkmark")
                }
            }
        }
    }
    VStack(alignment: .leading) {
        Text("create.sound_volume")
        Slider(value: $soundVolumePercent, in: 0...100, step: 1)
    }
} header: {
    Text("create.sound_section")
} footer: {
    Text("create.sound_volume_footer")
}
```

Pass into request:

```swift
soundId: soundId,
soundVolume: soundVolumePercent / 100.0,
```

On disappear: `soundPreview.stop()`.

- [ ] **Step 3: Localization keys**

Add to `Localizable.xcstrings` (tr + en at minimum):

- `create.sound_section` — Ses / Sound  
- `create.sound_volume` — Ses düzeyi / Volume  
- `create.sound_volume_footer` — dürüst K4 notu (sistem sesi / Critical yok)  
- `sound.default`, `sound.classic_bell`, … matching `displayNameKey`

- [ ] **Step 4: Human smoke (not agent xcodebuild)**

Human: open Create → select sounds → hear preview → save → verify pending notification sound if possible.

- [ ] **Step 5: Commit**

Message: `özellik: Alarm oluşturmada ses seçimi ve düzey kaydırıcısını ekle`

---

### Task 6: Detay özeti + doküman + memory + changelog

**Files:**
- Modify: `AlarmApp-iOS/Views/AlarmDetailView.swift`
- Modify: `docs/03-veri-modeli-ve-arayuzler.md`
- Modify: `docs/07-detayli-ekran-ve-fonksiyon-spesifikasyonu.md` (S2 map)
- Modify: `docs/01-ux-tasarim-ve-akislar.md` (alarm bildirimi ses cümlesi)
- Modify: `memory.md`
- Modify: `CHANGELOG.md` (+ bump `VERSION` if shipping user-visible note; e.g. patch `0.0.x`)

- [ ] **Step 1: Detail UI**

Show localized sound name + `"\(Int((alarm.soundVolume * 100).rounded()))%"`.

- [ ] **Step 2: docs/03**

Add `soundVolume` on `Alarm`; note catalog; update `NotificationScheduling.schedule` signature in §3 if present.

- [ ] **Step 3: docs/07 S2**

```
├── Ses (katalog listesi + önizleme)
├── Ses düzeyi (Slider 0–100)
```

- [ ] **Step 4: docs/01**

Replace “sistem dosyası” implication with uygulama CC0 paketi + düzey.

- [ ] **Step 5: memory.md**

```
- [x] Alarm ses kataloğu + soundVolume + S2 önizleme
```

- [ ] **Step 6: CHANGELOG (Turkish end-user)**

Example: “Alarm oluştururken ses seçebilir ve ses düzeyini ayarlayabilirsiniz.”

- [ ] **Step 7: `cd AlarmAppCore && swift test` — PASS**

- [ ] **Step 8: Commit**

Message: `belgeler: Ses ve düzey özelliğini dokümanlara ve changelog'a işle`

---

## Spec coverage checklist

| Spec § | Task |
|---|---|
| §3 Veri modeli | 1, 2 |
| §4 Bildirim | 3 |
| §5 UI | 5, 6 |
| §6 Ses paketi | 4 |
| §7 Test | 1–3 |
| §8 Docs/memory | 6 |
| §9 Out of scope | not implemented |

## Self-review notes

- No TBD placeholders in tasks
- `AlarmSchedule` carries sound so extend/snooze/create share one path
- Catalog ids ↔ `.caf` names must stay identical
- Critical path gated by `criticalAlertsEnabled` default `false`
