import Foundation
import Testing

@testable import Template

struct AppLanguageTests {
    private func defaults() -> UserDefaults {
        let suite = "AppLanguageTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func followsTheSystemByDefault() {
        let language = AppLanguage(defaults: defaults())
        #expect(language.choice == .system)
    }

    @Test func theChoiceIsStoredAndRestored() {
        let store = defaults()
        let language = AppLanguage(defaults: store)
        language.choice = .german
        #expect(AppLanguage(defaults: store).choice == .german)
    }

    @Test func aChosenLanguageResolvesTranslationsFromTheCatalog() {
        let language = AppLanguage(defaults: defaults())
        language.choice = .french
        #expect(language.string("Quit") == "Quitter")
        language.choice = .simplifiedChinese
        #expect(language.string("Quit") == "退出")
        language.choice = .english
        #expect(language.string("Quit") == "Quit")
    }

    @Test func anUnknownKeyFallsBackToTheEnglishSource() {
        let language = AppLanguage(defaults: defaults())
        language.choice = .japanese
        #expect(language.string("A key nobody translated") == "A key nobody translated")
    }

    @Test func theLocaleFollowsTheChoice() {
        let language = AppLanguage(defaults: defaults())
        language.choice = .brazilianPortuguese
        #expect(language.locale.identifier == "pt-BR")
    }

    @Test func everyChoiceExceptSystemHasANativeName() {
        for choice in LanguageChoice.allCases {
            #expect((choice.nativeName == nil) == (choice == .system))
        }
        #expect(LanguageChoice.allCases.count == 10)
    }
}
