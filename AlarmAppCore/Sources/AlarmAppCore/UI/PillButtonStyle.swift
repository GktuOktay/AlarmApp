import SwiftUI

/// Pill-shaped button style matching the hand-rolled `ringingButton`
/// (iOS `AlarmRingingView`) and `watchButton` (Watch `AlarmRingingView`,
/// `WakePromptView`) helpers, so later phases can swap those in without a
/// visual regression.
public struct PillButtonStyle: ButtonStyle {
    let tint: Color
    let foreground: Color

    public init(tint: Color, foreground: Color = .white) {
        self.tint = tint
        self.foreground = foreground
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .padding(.horizontal, 12)
            .background(
                tint.opacity(configuration.isPressed ? 0.85 : 1),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == PillButtonStyle {
    static func pill(tint: Color, foreground: Color = .white) -> PillButtonStyle {
        PillButtonStyle(tint: tint, foreground: foreground)
    }
}
