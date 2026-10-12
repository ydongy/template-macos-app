import Foundation

/// One entry of the sample list. A plain value: it is read from any execution domain.
nonisolated public struct ExampleItem: Identifiable, Hashable, Sendable, Codable {
    public enum Status: String, Hashable, Sendable, Codable {
        case ok
        case attention
    }

    public let id: String
    public let title: String
    public let detail: String
    public let status: Status
    public let modified: Date

    public init(id: String, title: String, detail: String, status: Status, modified: Date) {
        self.id = id
        self.title = title
        self.detail = detail
        self.status = status
        self.modified = modified
    }
}
