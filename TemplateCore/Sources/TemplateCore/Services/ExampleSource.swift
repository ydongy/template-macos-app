import Foundation

/// Where the sample screen gets its items. Models depend on this protocol only; `LiveExampleSource`
/// ships, `MockExampleSource` exists in DEBUG builds for previews and tests.
public protocol ExampleSource {
    func items() async throws -> [ExampleItem]
}

/// Why loading failed. The text is developer-facing English; the screen shows its own localized copy.
public enum ExampleSourceError: Error, Equatable {
    case unreadable(String)
}

/// Reads the items from a JSON file. A missing file is an empty list, a malformed one is an error.
public struct LiveExampleSource: ExampleSource {
    public let fileURL: URL

    /// The default location is the app's folder in Application Support.
    public init(fileURL: URL = LiveExampleSource.defaultFileURL) {
        self.fileURL = fileURL
    }

    public static var defaultFileURL: URL {
        URL.applicationSupportDirectory
            .appending(path: Bundle.main.bundleIdentifier ?? "app", directoryHint: .isDirectory)
            .appending(path: "example-items.json")
    }

    public func items() async throws -> [ExampleItem] {
        let url = fileURL
        return try await Task.detached {
            guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
                return []
            }
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode([ExampleItem].self, from: Data(contentsOf: url))
            } catch {
                throw ExampleSourceError.unreadable(String(describing: error))
            }
        }.value
    }
}
