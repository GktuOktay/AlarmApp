import Foundation

#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

public enum WatchConnectivityError: Error, Sendable, Equatable {
    case unsupported
    case notActivated
}

#if canImport(WatchConnectivity)

/// WCSession-backed `WatchConnectivityService` shared by iOS and watchOS.
///
/// Delivery: reachable → `sendMessage` (fallback `transferUserInfo`);
/// `todayContextUpdate` → `updateApplicationContext`.
/// When the session is not yet activated, outbound messages are queued and flushed on activation.
public final class WCSessionWatchConnectivityService: NSObject, WatchConnectivityService, @unchecked Sendable {
    public static let shared = WCSessionWatchConnectivityService()

    public let incomingMessages: AsyncStream<WatchMessage>

    private let session: WCSession?
    private var continuation: AsyncStream<WatchMessage>.Continuation?
    private let lock = NSLock()
    private var lastApplicationContextPayload: String?
    private var pendingOutbound: [WatchMessage] = []

    private override init() {
        var continuation: AsyncStream<WatchMessage>.Continuation!
        self.incomingMessages = AsyncStream { continuation = $0 }
        self.continuation = continuation
        if WCSession.isSupported() {
            self.session = WCSession.default
        } else {
            self.session = nil
        }
        super.init()
    }

    /// Activates the default session. Safe to call multiple times.
    public func activate() {
        guard let session else { return }
        session.delegate = self
        if session.activationState != .activated {
            session.activate()
        } else {
            Task { await self.flushPendingOutbound() }
        }
        if !session.receivedApplicationContext.isEmpty {
            ingest(dictionary: session.receivedApplicationContext)
        }
    }

    public func send(_ message: WatchMessage) async throws {
        guard let session else { throw WatchConnectivityError.unsupported }
        if session.activationState != .activated {
            session.delegate = self
            session.activate()
            enqueue(message)
            return
        }
        try await deliver(message, session: session)
    }

    private func enqueue(_ message: WatchMessage) {
        lock.lock()
        pendingOutbound.append(message)
        lock.unlock()
    }

    private func takePending() -> [WatchMessage] {
        lock.lock()
        let batch = pendingOutbound
        pendingOutbound = []
        lock.unlock()
        return batch
    }

    fileprivate func flushPendingOutbound() async {
        guard let session, session.activationState == .activated else { return }
        let batch = takePending()
        for message in batch {
            do {
                try await deliver(message, session: session)
            } catch {
                AppLog.error(.wcsession, "flushPendingOutbound deliver failed", error: error)
            }
        }
    }

    private func deliver(_ message: WatchMessage, session: WCSession) async throws {
        let payload = try WatchMessageCodec.dictionary(encoding: message)
        let delivery = WatchMessageDelivery.choose(for: message, isReachable: session.isReachable)

        switch delivery {
        case .applicationContext:
            try session.updateApplicationContext(payload)
        case .transferUserInfo:
            session.transferUserInfo(payload)
        case .sendMessage:
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                session.sendMessage(
                    payload,
                    replyHandler: { _ in cont.resume() },
                    errorHandler: { error in
                        AppLog.error(.wcsession, "sendMessage failed; falling back to transferUserInfo", error: error)
                        session.transferUserInfo(payload)
                        cont.resume()
                    }
                )
            }
        }
    }

    fileprivate func yield(_ message: WatchMessage) {
        lock.lock()
        let cont = continuation
        lock.unlock()
        cont?.yield(message)
    }

    fileprivate func ingest(dictionary: [String: Any]) {
        guard let message = try? WatchMessageCodec.message(from: dictionary) else {
            AppLog.error(.wcsession, "ingest dropped undecodable payload")
            return
        }
        if case .todayContextUpdate = message,
           let base64 = dictionary[WatchMessageCodec.payloadKey] as? String {
            lock.lock()
            let previous = lastApplicationContextPayload
            lastApplicationContextPayload = base64
            lock.unlock()
            if previous == base64 { return }
        }
        yield(message)
    }
}

extension WCSessionWatchConnectivityService: WCSessionDelegate {
    public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        #if os(iOS)
        _ = session.isWatchAppInstalled
        #endif
        if let error {
            AppLog.error(.wcsession, "activationDidComplete with error", error: error)
        }
        if !session.receivedApplicationContext.isEmpty {
            ingest(dictionary: session.receivedApplicationContext)
        }
        if activationState == .activated {
            Task { await self.flushPendingOutbound() }
        }
    }

    public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        ingest(dictionary: message)
    }

    public func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        ingest(dictionary: message)
        replyHandler([:])
    }

    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        ingest(dictionary: userInfo)
    }

    public func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        ingest(dictionary: applicationContext)
    }

    #if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {}
    public func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}

#else

/// macOS / non-WatchConnectivity hosts used by `swift test` — no session hardware.
public final class WCSessionWatchConnectivityService: WatchConnectivityService, @unchecked Sendable {
    public static let shared = WCSessionWatchConnectivityService()

    public let incomingMessages: AsyncStream<WatchMessage>
    private var continuation: AsyncStream<WatchMessage>.Continuation?
    /// Test-only queue mirroring device enqueue-until-activated behavior.
    public private(set) var pendingOutboundForTests: [WatchMessage] = []
    public var isActivatedForTests = true

    private init() {
        var continuation: AsyncStream<WatchMessage>.Continuation!
        self.incomingMessages = AsyncStream { continuation = $0 }
        self.continuation = continuation
    }

    public func activate() {
        isActivatedForTests = true
        let batch = pendingOutboundForTests
        pendingOutboundForTests = []
        for message in batch {
            continuation?.yield(message)
        }
    }

    public func send(_ message: WatchMessage) async throws {
        if !isActivatedForTests {
            pendingOutboundForTests.append(message)
            return
        }
        // Host without WCSession still cannot deliver to a peer.
        throw WatchConnectivityError.unsupported
    }
}

#endif

/// In-memory fake for unit tests and simulator-safe previews.
public final class FakeWatchConnectivityService: WatchConnectivityService, @unchecked Sendable {
    public private(set) var sent: [WatchMessage] = []
    public private(set) var deliveries: [WatchMessageDelivery] = []
    public var isReachable: Bool = true
    /// When false, `send` enqueues until `flushPending()` (mirrors WCSession notActivated).
    public var isActivated: Bool = true
    public private(set) var pending: [WatchMessage] = []

    public let incomingMessages: AsyncStream<WatchMessage>
    private var continuation: AsyncStream<WatchMessage>.Continuation?

    public init() {
        var continuation: AsyncStream<WatchMessage>.Continuation!
        self.incomingMessages = AsyncStream { continuation = $0 }
        self.continuation = continuation
    }

    public func send(_ message: WatchMessage) async throws {
        guard isActivated else {
            pending.append(message)
            return
        }
        let delivery = WatchMessageDelivery.choose(for: message, isReachable: isReachable)
        deliveries.append(delivery)
        sent.append(message)
    }

    public func flushPending() async throws {
        isActivated = true
        let batch = pending
        pending = []
        for message in batch {
            try await send(message)
        }
    }

    public func emit(_ message: WatchMessage) {
        continuation?.yield(message)
    }
}
