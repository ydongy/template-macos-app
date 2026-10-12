import Foundation
import TemplateCore
import Testing

struct LiveExampleSourceTests {
    private func temporaryFile() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "example-\(UUID().uuidString).json")
    }

    @Test func aMissingFileIsAnEmptyList() async throws {
        let source = LiveExampleSource(fileURL: temporaryFile())
        #expect(try await source.items().isEmpty)
    }

    @Test func itemsAreDecodedFromJSON() async throws {
        let url = temporaryFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let json = """
            [{"id": "a", "title": "A", "detail": "first", "status": "ok",
              "modified": "2026-10-03T08:00:00Z"}]
            """
        try Data(json.utf8).write(to: url)
        let items = try await LiveExampleSource(fileURL: url).items()
        #expect(items.map(\.id) == ["a"])
        #expect(items.first?.status == .ok)
        #expect(items.first?.modified == Date(timeIntervalSince1970: 1_791_014_400))
    }

    @Test func aMalformedFileIsAnError() async throws {
        let url = temporaryFile()
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("not json".utf8).write(to: url)
        await #expect(throws: ExampleSourceError.self) {
            _ = try await LiveExampleSource(fileURL: url).items()
        }
    }
}
