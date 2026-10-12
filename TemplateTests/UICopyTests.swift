import Foundation
import TemplateCore
import Testing

@testable import Template

struct UICopyTests {
    private struct Shout: UICopyProviding {
        func string(_ key: String) -> String { key.uppercased() }
        var locale: Locale { Locale(identifier: "fr") }
    }

    @Test func locGoesThroughTheInstalledProvider() {
        let original = UICopy.provider
        defer { UICopy.provider = original }
        UICopy.provider = Shout()
        #expect(String.loc("Quit") == "QUIT")
        #expect(UICopy.provider.locale.identifier == "fr")
    }

    @Test func theSystemProviderReturnsTheKeyWhenThereIsNoTranslation() {
        #expect(SystemUICopy().string("A key nobody translated") == "A key nobody translated")
    }
}
