import Foundation
import Observation
import TemplateCore

/// UI language (Settings). Language names are shown in their own script and are not translated;
/// `system` follows the system.
enum LanguageChoice: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"
    case korean = "ko"
    case french = "fr"
    case german = "de"
    case spanish = "es"
    case brazilianPortuguese = "pt-BR"

    var id: String { rawValue }

    /// The language's own name; nil for `system` (the UI shows "Follow System", in the UI language).
    var nativeName: String? {
        switch self {
        case .system: nil
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .french: "Français"
        case .german: "Deutsch"
        case .spanish: "Español"
        case .brazilianPortuguese: "Português (Brasil)"
        }
    }
}

/// The current UI language; a change takes effect immediately, no restart.
///
/// All UI text built in code goes through `String.loc`, which asks the installed `UICopyProviding`
/// (this class). Reading `choice` is recorded by Observation, so a view that calls `String.loc` in
/// its `body` redraws when the language changes.
@Observable
@MainActor
final class AppLanguage: UICopyProviding {
    static let shared = AppLanguage()
    static let defaultsKey = "settings.language"

    var choice: LanguageChoice {
        didSet { defaults.set(choice.rawValue, forKey: Self.defaultsKey) }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let bundle: Bundle
    @ObservationIgnored private var bundles: [LanguageChoice: Bundle?] = [:]

    init(defaults: UserDefaults = .standard, bundle: Bundle = .main) {
        self.defaults = defaults
        self.bundle = bundle
        choice = defaults.string(forKey: Self.defaultsKey).flatMap(LanguageChoice.init) ?? .system
    }

    /// Locale for dates, numbers and relative times: the system's when following the system,
    /// otherwise the selected language.
    var locale: Locale {
        choice == .system ? .autoupdatingCurrent : Locale(identifier: choice.rawValue)
    }

    /// Looks a string up in the selected language; falls back to the system localization and
    /// finally to the key (the English source string).
    func string(_ key: String) -> String {
        if choice == .system { return String(localized: String.LocalizationValue(key)) }
        guard let table = localizedBundle(for: choice) else { return key }
        return table.localizedString(forKey: key, value: key, table: nil)
    }

    private func localizedBundle(for choice: LanguageChoice) -> Bundle? {
        if let cached = bundles[choice] { return cached }
        let found = bundle.path(forResource: choice.rawValue, ofType: "lproj").flatMap(Bundle.init)
        bundles[choice] = .some(found)
        return found
    }
}
