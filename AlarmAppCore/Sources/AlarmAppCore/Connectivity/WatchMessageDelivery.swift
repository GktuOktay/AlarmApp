import Foundation

/// Chooses how a `WatchMessage` should be delivered over WatchConnectivity.
public enum WatchMessageDelivery: String, Sendable, Equatable {
    /// iPhone → Watch today summary (replaces previous context).
    case applicationContext
    /// Immediate delivery when the counterpart is reachable.
    case sendMessage
    /// Queued, guaranteed delivery when unreachable or after send failure.
    case transferUserInfo

    /// Routing rules from `docs/03` / watch-connectivity-safe skill.
    public static func choose(for message: WatchMessage, isReachable: Bool) -> WatchMessageDelivery {
        if case .todayContextUpdate = message {
            return .applicationContext
        }
        return isReachable ? .sendMessage : .transferUserInfo
    }
}
