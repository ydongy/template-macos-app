import Foundation
import Observation
import Sparkle

/// In-app updates (Sparkle). The updater runs only when the build carries a public EdDSA key
/// (`SPARKLE_PUBLIC_KEY` in `project.yml`); development and unconfigured builds never check.
@Observable
@MainActor
final class AppUpdater {
    @ObservationIgnored private let controller: SPUStandardUpdaterController?

    init(bundle: Bundle = .main) {
        let key = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        if Self.isConfigured(publicKey: key) {
            controller = SPUStandardUpdaterController(
                startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        } else {
            controller = nil
        }
    }

    var isEnabled: Bool { controller != nil }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }

    nonisolated static func isConfigured(publicKey: String?) -> Bool {
        guard let publicKey else { return false }
        return !publicKey.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
