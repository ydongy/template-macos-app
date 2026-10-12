import Foundation
import Testing

@testable import Template

/// The Info.plist keys the release script and Sparkle depend on.
struct AppBundleTests {
    private let info = Bundle.main.infoDictionary ?? [:]

    @Test func theUpdateFeedIsAnHTTPSAppcast() throws {
        let feed = try #require(info["SUFeedURL"] as? String)
        #expect(feed.hasPrefix("https://"))
        #expect(feed.hasSuffix("/appcast.xml"))
    }

    @Test func theUpdaterKeyIsDeclared() {
        #expect(info["SUPublicEDKey"] is String)
    }

    @Test func updatesAreCheckedDailyWithoutASystemProfile() {
        #expect(info["SUEnableAutomaticChecks"] as? Bool == true)
        #expect(info["SUScheduledCheckInterval"] as? Int == 86_400)
        #expect(info["SUEnableSystemProfiling"] as? Bool == false)
    }

    @Test func theAppLivesInTheMenuBarOnly() {
        #expect(info["LSUIElement"] as? Bool == true)
    }

    @Test func theVersionComesFromTheXcconfig() {
        #expect((info["CFBundleShortVersionString"] as? String)?.isEmpty == false)
        #expect(Int(info["CFBundleVersion"] as? String ?? "") != nil)
    }

    @Test func theUpdaterIsOffWithoutAPublicKey() {
        #expect(!AppUpdater.isConfigured(publicKey: nil))
        #expect(!AppUpdater.isConfigured(publicKey: "  "))
        #expect(AppUpdater.isConfigured(publicKey: "key"))
    }
}
