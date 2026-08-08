import SwiftUI

/// Renders an already-formatted alarm time string with the standard
/// monospaced, light-weight styling used across list rows, the ringing
/// screen, and Watch surfaces. Callers are responsible for formatting the
/// `ClockTime` (or session) into a string using their existing formatting
/// helper — this view only owns typography.
public struct AlarmTimeText: View {
    public enum Style {
        case listRow
        case listRowSecondary
        case ringing
        case watch

        var baseSize: CGFloat {
            switch self {
            case .listRow: 44
            case .listRowSecondary: 40
            case .ringing: 72
            case .watch: 34
            }
        }

        var weight: Font.Weight {
            switch self {
            case .listRow, .listRowSecondary: .light
            case .ringing, .watch: .ultraLight
            }
        }
    }

    @ScaledMetric private var scaledSize: CGFloat
    private let weight: Font.Weight
    private let text: String

    public init(_ text: String, style: Style) {
        self.text = text
        self.weight = style.weight
        self._scaledSize = ScaledMetric(wrappedValue: style.baseSize)
    }

    public var body: some View {
        Text(text)
            .font(.system(size: scaledSize, weight: weight))
            .monospacedDigit()
    }
}
