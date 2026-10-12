import Foundation
import Testing

/// Completeness of the string catalog (`Localizable.xcstrings`): every UI language has every
/// string, placeholders match, nothing is left untranslated. Keys are the English source text.
/// Reads the source file, not the compiled resources.
struct LocalizationCatalogTests {
    private struct Catalog: Decodable {
        let strings: [String: Entry]
    }

    private struct Entry: Decodable {
        let localizations: [String: Localization]?
    }

    private struct Localization: Decodable {
        let stringUnit: Unit?
        let variations: Variations?
    }

    private struct Unit: Decodable {
        let state: String
        let value: String
    }

    private struct Variations: Decodable {
        let plural: [String: PluralCase]?
    }

    private struct PluralCase: Decodable {
        let stringUnit: Unit
    }

    /// English is the source language (the string is its own key); every language must have all of
    /// them, English included. Keep in sync with `LanguageChoice`.
    private nonisolated static let languages = [
        "en", "zh-Hans", "zh-Hant", "ja", "ko", "fr", "de", "es", "pt-BR",
    ]
    private static let pluralCategories: [String: Set<String>] = [
        "en": ["one", "other"], "zh-Hans": ["other"], "zh-Hant": ["other"], "ja": ["other"],
        "ko": ["other"],
        "fr": ["one", "other"], "de": ["one", "other"], "es": ["one", "other"],
        "pt-BR": ["one", "other"],
    ]

    /// Keys that may read the same as the English source in the CJK languages (names, symbols).
    private static let sameAsEnglish: Set<String> = [
        "Template", "OK",
    ]

    private static func load() throws -> Catalog {
        let url = URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Template/Resources/Localizable.xcstrings")
        return try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url))
    }

    /// `%@`, `%lld` (including positional ones like `%1$@`), compared after sorting by type.
    private static func placeholders(_ text: String) -> [String] {
        text.matches(of: /%(?:\d+\$)?(lld|@)/).map { String($0.output.1) }.sorted()
    }

    private static func values(_ localization: Localization) -> [(String, Unit)] {
        if let unit = localization.stringUnit { return [("", unit)] }
        return (localization.variations?.plural ?? [:]).map { ($0.key, $0.value.stringUnit) }
    }

    private static func hasChinese(_ text: String) -> Bool {
        text.unicodeScalars.contains { $0.value >= 0x4E00 && $0.value <= 0x9FFF }
    }

    @Test(arguments: languages)
    func everyStringIsTranslated(language: String) throws {
        let catalog = try Self.load()
        var problems: [String] = []
        for (key, entry) in catalog.strings {
            guard let localization = entry.localizations?[language] else {
                problems.append("missing: \(key)")
                continue
            }
            let values = Self.values(localization)
            if values.isEmpty { problems.append("empty: \(key)") }
            for (category, unit) in values {
                if unit.value.trimmingCharacters(in: .whitespaces).isEmpty {
                    problems.append("blank \(category): \(key)")
                }
                if unit.state != "translated" { problems.append("state \(unit.state): \(key)") }
                if Self.placeholders(unit.value) != Self.placeholders(key) {
                    problems.append("placeholders \(category): \(key) -> \(unit.value)")
                }
                let cjk = ["zh-Hans", "zh-Hant", "ja", "ko"].contains(language)
                if cjk {
                    // A verbatim copy of the English text is untranslated (names and symbols excepted).
                    let letters = key.replacing(/%(?:\d+\$)?(lld|@)/, with: "")
                        .contains(/[A-Za-z]/)
                    if letters, unit.value == key, !Self.sameAsEnglish.contains(key) {
                        problems.append("untranslated: \(key)")
                    }
                }
                if !["en", "zh-Hans", "zh-Hant", "ja"].contains(language),
                    Self.hasChinese(unit.value)
                {
                    problems.append("left Chinese: \(key) -> \(unit.value)")
                }
            }
            if localization.variations != nil {
                let have = Set((localization.variations?.plural ?? [:]).keys)
                let need = Self.pluralCategories[language] ?? ["other"]
                if !need.isSubset(of: have) { problems.append("plural categories \(have): \(key)") }
            }
        }
        #expect(problems.isEmpty, "\(language): \(problems.sorted().prefix(15))")
    }

    /// A string that is plural in English stays plural in every language.
    @Test func pluralEntriesArePluralEverywhere() throws {
        let catalog = try Self.load()
        let plural = catalog.strings.filter { $0.value.localizations?["en"]?.variations != nil }
        for language in Self.languages {
            for (key, entry) in plural {
                #expect(
                    entry.localizations?[language]?.variations != nil,
                    "\(language) should keep the plural form of \(key)")
            }
        }
    }

    @Test func nativeLanguageNamesAreNotInTheCatalog() throws {
        let catalog = try Self.load()
        for name in ["简体中文", "繁體中文", "日本語", "한국어", "Français", "Deutsch", "Español"] {
            #expect(catalog.strings[name] == nil, "\(name) is shown verbatim, not translated")
        }
    }
}
