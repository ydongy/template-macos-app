import Foundation

/// Website URLs, in one place (to change domains, edit only here and `Config/release.conf`).
///
/// Website pages open in the app's language: English has no prefix, the others use the website's
/// language path (`/zh`, `/zh-hant`, `/ja`, `/ko`, `/fr`, `/de`, `/es`, `/pt`). Every page has one
/// address; the download and pricing sections are on the home page.
enum ProductLinks {
    static let site = URL(string: "https://example.com")!

    static var changelog: URL { page("changelog") }
    static var privacy: URL { page("privacy") }
    /// Terms of Service, which are also the license agreement.
    static var terms: URL { page("terms") }
    static var refund: URL { page("refund") }

    @MainActor
    static func page(
        _ name: String, language: LanguageChoice = AppLanguage.shared.choice,
        preferred: [String] = Locale.preferredLanguages
    ) -> URL {
        URL(
            string: site.absoluteString + languagePath(language, preferred: preferred) + "/" + name)!
    }

    @MainActor
    static func home(
        anchor: String, language: LanguageChoice = AppLanguage.shared.choice,
        preferred: [String] = Locale.preferredLanguages
    ) -> URL {
        URL(
            string: site.absoluteString + languagePath(language, preferred: preferred) + "/#"
                + anchor)!
    }

    /// The website's path for a language: "" for English. "Follow system" uses the first preferred
    /// language the website has, otherwise English.
    static func languagePath(_ choice: LanguageChoice, preferred: [String]) -> String {
        switch choice {
        case .english: return ""
        case .simplifiedChinese: return "/zh"
        case .traditionalChinese: return "/zh-hant"
        case .japanese: return "/ja"
        case .korean: return "/ko"
        case .french: return "/fr"
        case .german: return "/de"
        case .spanish: return "/es"
        case .brazilianPortuguese: return "/pt"
        case .system:
            for identifier in preferred {
                let id = identifier.lowercased()
                if id.hasPrefix("zh") {
                    let traditional = ["hant", "-tw", "-hk", "-mo"].contains { id.contains($0) }
                    return traditional ? "/zh-hant" : "/zh"
                }
                switch id.prefix(2) {
                case "en": return ""
                case "ja": return "/ja"
                case "ko": return "/ko"
                case "fr": return "/fr"
                case "de": return "/de"
                case "es": return "/es"
                case "pt": return "/pt"
                default: continue
                }
            }
            return ""
        }
    }
}
