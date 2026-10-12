import Foundation
import Testing

@testable import Template

struct ProductLinksTests {
    @Test func englishPagesHaveNoLanguagePrefix() {
        #expect(
            ProductLinks.page("terms", language: .english, preferred: []).absoluteString
                == "https://example.com/terms")
    }

    @Test func otherLanguagesUseTheWebsiteLanguagePath() {
        let expected: [LanguageChoice: String] = [
            .simplifiedChinese: "/zh", .traditionalChinese: "/zh-hant", .japanese: "/ja",
            .korean: "/ko", .french: "/fr", .german: "/de", .spanish: "/es",
            .brazilianPortuguese: "/pt",
        ]
        for (choice, path) in expected {
            #expect(ProductLinks.languagePath(choice, preferred: []) == path)
        }
    }

    @Test func followSystemUsesTheFirstLanguageTheWebsiteHas() {
        #expect(ProductLinks.languagePath(.system, preferred: ["sv-SE", "de-DE"]) == "/de")
        #expect(ProductLinks.languagePath(.system, preferred: ["zh-Hant-TW"]) == "/zh-hant")
        #expect(ProductLinks.languagePath(.system, preferred: ["zh-Hans-CN"]) == "/zh")
        #expect(ProductLinks.languagePath(.system, preferred: ["pt-BR"]) == "/pt")
        #expect(ProductLinks.languagePath(.system, preferred: ["sv-SE"]) == "")
        #expect(ProductLinks.languagePath(.system, preferred: []) == "")
    }

    @Test func homeAnchorsKeepTheLanguagePath() {
        #expect(
            ProductLinks.home(anchor: "download", language: .french, preferred: []).absoluteString
                == "https://example.com/fr/#download")
    }
}
