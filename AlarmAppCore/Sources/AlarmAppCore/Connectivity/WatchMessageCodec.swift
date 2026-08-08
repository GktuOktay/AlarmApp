import Foundation

/// Encodes `WatchMessage` into WCSession property-list dictionaries and back.
public enum WatchMessageCodec: Sendable {
    public static let payloadKey = "payload"

    public static func encode(_ message: WatchMessage) throws -> Data {
        try JSONEncoder().encode(message)
    }

    public static func decode(_ data: Data) throws -> WatchMessage {
        try JSONDecoder().decode(WatchMessage.self, from: data)
    }

    public static func dictionary(encoding message: WatchMessage) throws -> [String: Any] {
        let data = try encode(message)
        return [payloadKey: data.base64EncodedString()]
    }

    public static func message(from dictionary: [String: Any]) throws -> WatchMessage? {
        guard let base64 = dictionary[payloadKey] as? String,
              let data = Data(base64Encoded: base64)
        else { return nil }
        return try decode(data)
    }
}
