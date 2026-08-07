---
name: watch-connectivity-safe
description: Safe WatchConnectivity and wake-sync for AlarmApp. Use when editing WCSession, WatchMessage, wakeConfirmed, TodayContext sync, or offline wake cancel.
---

# WatchConnectivity safe

## Contract source of truth

Read and follow `docs/03-veri-modeli-ve-arayuzler.md` §4:

```swift
struct TodayContext: Codable {
    var date: Date
    var activeGroups: [ActiveGroupSummary]
    var autoWakeDetectionEnabled: Bool  // S7; legacy decode → true
    var wakeAlarmId: UUID?              // legacy → nil
    var wakeGroupId: UUID?              // legacy → nil
    var nextWakeFireDate: Date?         // Watch wake detection; legacy → nil
}

struct InstanceSummary: Codable, Identifiable {
    var id: UUID
    var alarmId: UUID                   // legacy → zero UUID
    var time: ClockTime
    var status: AlarmStatus
}

enum WatchMessage: Codable {
    case todayContextUpdate(TodayContext)                                    // iPhone → Watch
    case wakeConfirmed(groupId: UUID, timestamp: Date)                       // Watch → iPhone
    case snoozeApplied(alarmId: UUID, instanceId: UUID, fireDate: Date)
    case dismissApplied(alarmId: UUID, instanceId: UUID)
    case bulkCancelApplied(scope: BulkCancelScope, timestamp: Date)
}
```

**Do not add cases** (e.g. undo) without updating `docs/03` in the same change.

## Delivery strategy

1. If session not yet `activated` → **enqueue**; flush on `activationDidComplete` (do not drop action messages).
2. If `WCSession.isReachable` → `sendMessage` with JSON `payload`.
3. Else / on failure → `transferUserInfo` (queued, guaranteed delivery).
4. iPhone → Watch today summary: prefer `updateApplicationContext`.

## Offline-first wake

1. Watch runs `HandleWakeEvent` locally (cancel local notifications).
2. Show W2 undo (10s).
3. Enqueue `wakeConfirmed` to iPhone.
4. iPhone applies the same use case on the phone repository when the message arrives.

User must never experience “Watch stopped but phone still ringing” because Watch skipped local cancel.

## Testing

- Codable round-trip of `WatchMessage` in unit tests (no device).
- Reachability / fallback: **real iPhone + Watch pair**; note verification in the PR (`docs/06`).
- Simulator WCSession is unreliable — don’t claim E2E pass from simulator alone.

## Related

- End-to-end flow: `docs/02-teknik-mimari.md` §3
- Screens: `docs/07` W1/W2
- UI feel: skill `apple-feel-swiftui`
