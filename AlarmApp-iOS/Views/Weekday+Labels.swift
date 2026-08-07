import SwiftUI
import AlarmAppCore

extension Weekday {
    /// Localized short weekday label using the device calendar/locale.
    var shortLabel: String {
        let symbols = Calendar.autoupdatingCurrent.shortWeekdaySymbols
        let index = calendarWeekday - 1
        guard symbols.indices.contains(index) else { return "" }
        return symbols[index]
    }
}
