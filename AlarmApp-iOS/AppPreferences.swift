import Foundation
import SwiftUI

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

    var languageRaw: String {
        didSet { UserDefaults.standard.set(languageRaw, forKey: Self.languageKey) }
    }

    var appearanceRaw: String {
        didSet { UserDefaults.standard.set(appearanceRaw, forKey: Self.appearanceKey) }
    }

    init() {
        languageRaw = UserDefaults.standard.string(forKey: Self.languageKey) ?? AppLanguageCode.system.rawValue
        appearanceRaw = UserDefaults.standard.string(forKey: Self.appearanceKey) ?? AppAppearanceMode.system.rawValue
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
}
