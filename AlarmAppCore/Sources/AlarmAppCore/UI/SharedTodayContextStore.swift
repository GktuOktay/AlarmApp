import Foundation

/// App Group identifier reserved for sharing data with a future widget/complication
/// extension. No App Group entitlement is provisioned yet (see Phase 6 plan) — until
/// it is, `UserDefaults(suiteName:)` simply returns `nil` and reads/writes below
/// no-op safely.
public enum AppGroup {
    public static let identifier = "group.com.gktuoktay.AlarmApp"
}

/// Reads/writes a `TodayContext` snapshot to a shared `UserDefaults` suite so a
/// future widget/complication extension can render without opening the full
/// SwiftData store. Uses the same plain `JSONEncoder`/`JSONDecoder` convention as
/// `WatchMessageCodec` (no custom date strategy) to stay in sync with the
/// WatchConnectivity payload shape.
public enum SharedTodayContextStore {
    private static let key = "today_context"

    public static func write(_ context: TodayContext, appGroupId: String) {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return }
        guard let data = try? JSONEncoder().encode(context) else { return }
        defaults.set(data, forKey: key)
    }

    public static func read(appGroupId: String) -> TodayContext? {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return nil }
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(TodayContext.self, from: data)
    }
}
