import SwiftUI

/// Bottom-anchored transient toast, matching the overlay pattern currently
/// duplicated across AlarmListView/AlarmDetailView/CalendarView/GroupListView.
public struct ToastModifier: ViewModifier {
    @Binding var message: String?
    let duration: TimeInterval
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var task: Task<Void, Never>?

    public init(message: Binding<String?>, duration: TimeInterval) {
        self._message = message
        self.duration = duration
    }

    public func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let message {
                    Text(message)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 24)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 1), value: message)
            .onChange(of: message) { _, newValue in
                task?.cancel()
                guard newValue != nil else { return }
                task = Task {
                    try? await Task.sleep(for: .seconds(duration))
                    guard !Task.isCancelled else { return }
                    message = nil
                }
            }
    }
}

public extension View {
    /// Shows `message.wrappedValue` as a bottom toast that auto-clears after
    /// `duration` seconds, unless replaced or cleared sooner.
    func toast(_ message: Binding<String?>, duration: TimeInterval = 3) -> some View {
        modifier(ToastModifier(message: message, duration: duration))
    }
}
