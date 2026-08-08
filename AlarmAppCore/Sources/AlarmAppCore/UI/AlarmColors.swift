import SwiftUI

// NOTE: Colors are defined in code (not an Xcode asset catalog) so a single
// SwiftPM library target can serve both the iOS and Watch app targets without
// needing to duplicate a Colors.xcassets folder in each app's own catalog.
// Dark-mode variants are provided via `Color(light:dark:)`; the package stays
// free of any UIKit/WatchKit import.
public enum AlarmColors {
    /// Warning / attention accent. Replaces ad-hoc `.orange` usage.
    public static let warn = Color(
        light: Color(.sRGB, red: 1.0, green: 0.584, blue: 0.0, opacity: 1),
        dark: Color(.sRGB, red: 1.0, green: 0.62, blue: 0.04, opacity: 1)
    )

    /// Success / confirmation accent. Replaces ad-hoc `.green` usage.
    public static let success = Color(
        light: Color(.sRGB, red: 0.204, green: 0.780, blue: 0.349, opacity: 1),
        dark: Color(.sRGB, red: 0.188, green: 0.82, blue: 0.345, opacity: 1)
    )

    /// Danger / destructive accent. Replaces ad-hoc `.red` usage.
    public static let danger = Color(
        light: Color(.sRGB, red: 0.937, green: 0.204, blue: 0.204, opacity: 1),
        dark: Color(.sRGB, red: 1.0, green: 0.29, blue: 0.29, opacity: 1)
    )

    /// Full-screen background used on the alarm ringing screen.
    public static let ringingBackground = Color(
        light: Color(.sRGB, red: 0.02, green: 0.02, blue: 0.02, opacity: 1),
        dark: Color(.sRGB, red: 0.02, green: 0.02, blue: 0.02, opacity: 1)
    )

    /// Foreground text/icon color on the ringing screen (near-white).
    public static let ringingForeground = Color(
        light: Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 1),
        dark: Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 1)
    )

    /// Secondary fill used behind non-primary pill buttons on the ringing
    /// screen. Replaces ad-hoc `.white.opacity(0.16-0.18)` usage.
    public static let ringingSecondaryFill = Color(
        light: Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.18),
        dark: Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.18)
    )
}

private extension Color {
    /// Resolves to `light` or `dark` depending on the current color scheme
    /// trait, without importing UIKit/WatchKit. Falls back to `light` on
    /// platforms where dynamic trait resolution isn't available.
    init(light: Color, dark: Color) {
        #if canImport(UIKit) && !os(watchOS)
        self = Color(uiColor: .init(dynamicProvider: { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        }))
        #else
        self = light
        #endif
    }
}
