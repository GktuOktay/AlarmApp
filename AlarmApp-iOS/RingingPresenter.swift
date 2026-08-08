import Foundation
import SwiftData
import SwiftUI
import AlarmAppCore

enum RingingPrimaryAction {
    case dismiss
    case snooze
    case more
}

enum RingingBulkAction {
    case groupToday
    case nextThreeHours
    case allToday
}

struct RingingSession: Identifiable, Equatable, Sendable {
    var id: UUID { instanceId }
    let alarmId: UUID
    let instanceId: UUID
    let groupId: UUID?
    let title: String
    let timeText: String
    let snoozeEnabled: Bool
    let soundId: String
    let soundVolume: Double
}

@MainActor
final class RingingPresenter: ObservableObject {
    static let shared = RingingPresenter()

    @Published var session: RingingSession?

    func present(_ session: RingingSession) {
        self.session = session
    }

    func dismiss() {
        session = nil
    }

    static func makeSession(
        container: ModelContainer,
        alarmId: UUID,
        instanceId: UUID,
        fallbackTitle: String
    ) -> RingingSession {
        let context = ModelContext(container)
        let targetAlarmId = alarmId
        let descriptor = FetchDescriptor<Alarm>(
            predicate: #Predicate { $0.id == targetAlarmId }
        )
        let alarm = try? context.fetch(descriptor).first
        let time = alarm?.time ?? ClockTime(hour: 0, minute: 0)
        let timeText = String(format: "%02d:%02d", time.hour, time.minute)
        return RingingSession(
            alarmId: alarmId,
            instanceId: instanceId,
            groupId: alarm?.group?.id,
            title: alarm?.title ?? fallbackTitle,
            timeText: timeText,
            snoozeEnabled: alarm?.snoozeEnabled ?? true,
            soundId: alarm?.soundId ?? "default",
            soundVolume: alarm?.soundVolume ?? 1.0
        )
    }
}
