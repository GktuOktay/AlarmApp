import Foundation
import SwiftUI
import HealthKit

enum AppLanguageCode: String, CaseIterable, Identifiable {
    case system
    case tr
    case en
    case fr
    case es
    case ru
    case zhHans = "zh-Hans"
    case ar

    var id: String { rawValue }

    var localeIdentifier: String? {
        switch self {
        case .system: return nil
        case .zhHans: return "zh-Hans"
        default: return rawValue
        }
    }

    var localizationKey: String {
        switch self {
        case .system: return "settings.language.system"
        case .tr: return "settings.language.tr"
        case .en: return "settings.language.en"
        case .fr: return "settings.language.fr"
        case .es: return "settings.language.es"
        case .ru: return "settings.language.ru"
        case .zhHans: return "settings.language.zh"
        case .ar: return "settings.language.ar"
        }
    }
}

enum AppAppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .system: return "settings.appearance.system"
        case .light: return "settings.appearance.light"
        case .dark: return "settings.appearance.dark"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@Observable
final class AppPreferences {
    private static let languageKey = "app.language"
    private static let appearanceKey = "app.colorScheme"
    /// Shared with Watch via App Group would be ideal; for MVP both read the same key name from defaults.
    static let autoWakePromptEnabledKey = "app.autoWakePromptEnabled"

    var languageRaw: String {
        didSet { UserDefaults.standard.set(languageRaw, forKey: Self.languageKey) }
    }

    var appearanceRaw: String {
        didSet { UserDefaults.standard.set(appearanceRaw, forKey: Self.appearanceKey) }
    }

    /// S7 “Otomatik uyanma sorusu” — default on; HealthKit denial disables effective detection.
    var autoWakePromptEnabled: Bool {
        didSet { UserDefaults.standard.set(autoWakePromptEnabled, forKey: Self.autoWakePromptEnabledKey) }
    }

    /// `true` when HealthKit sleep read is explicitly denied (or unavailable).
    var healthKitSleepDenied: Bool = false

    init() {
        languageRaw = UserDefaults.standard.string(forKey: Self.languageKey) ?? AppLanguageCode.system.rawValue
        appearanceRaw = UserDefaults.standard.string(forKey: Self.appearanceKey) ?? AppAppearanceMode.system.rawValue
        if UserDefaults.standard.object(forKey: Self.autoWakePromptEnabledKey) == nil {
            autoWakePromptEnabled = true
        } else {
            autoWakePromptEnabled = UserDefaults.standard.bool(forKey: Self.autoWakePromptEnabledKey)
        }
        refreshHealthKitStatus()
    }

    var language: AppLanguageCode {
        get { AppLanguageCode(rawValue: languageRaw) ?? .system }
        set { languageRaw = newValue.rawValue }
    }

    var appearance: AppAppearanceMode {
        get { AppAppearanceMode(rawValue: appearanceRaw) ?? .system }
        set { appearanceRaw = newValue.rawValue }
    }

    var locale: Locale {
        if let id = language.localeIdentifier {
            return Locale(identifier: id)
        }
        return .autoupdatingCurrent
    }

    /// Effective toggle: user preference AND HealthKit not denied.
    var isAutoWakePromptEffectivelyEnabled: Bool {
        autoWakePromptEnabled && !healthKitSleepDenied
    }

    func refreshHealthKitStatus() {
        guard HKHealthStore.isHealthDataAvailable(),
              let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            healthKitSleepDenied = true
            return
        }
        let status = HKHealthStore().authorizationStatus(for: sleepType)
        // `.sharingDenied` means user denied; `.notDetermined` is OK until request.
        healthKitSleepDenied = (status == .sharingDenied)
    }

    @MainActor
    func requestHealthKitSleepAccessIfNeeded() async {
        guard HKHealthStore.isHealthDataAvailable(),
              let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            healthKitSleepDenied = true
            return
        }
        let store = HKHealthStore()
        do {
            try await store.requestAuthorization(toShare: [], read: [sleepType])
        } catch {
            healthKitSleepDenied = true
            return
        }
        refreshHealthKitStatus()
    }
}
