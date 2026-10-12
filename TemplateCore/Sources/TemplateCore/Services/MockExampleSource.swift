import Foundation

#if DEBUG
    /// Test and preview double. DEBUG only: Release builds must not contain it
    /// (`FORBID_SYMBOLS` in `Config/release.conf` makes `scripts/release.sh` check that).
    public final class MockExampleSource: ExampleSource {
        public enum Behavior {
            case items([ExampleItem])
            case failure
            /// Never returns; the screen stays in its loading state.
            case pending
        }

        public var behavior: Behavior
        public private(set) var loadCount = 0

        public init(_ behavior: Behavior = .items(MockExampleSource.sampleItems)) {
            self.behavior = behavior
        }

        public func items() async throws -> [ExampleItem] {
            loadCount += 1
            switch behavior {
            case .items(let items):
                return items
            case .failure:
                throw ExampleSourceError.unreadable("mock failure")
            case .pending:
                try await Task.sleep(for: .seconds(3600))
                return []
            }
        }

        public static let sampleItems: [ExampleItem] = [
            ExampleItem(
                id: "alpha", title: "Alpha", detail: "Everything is in order",
                status: .ok, modified: Date(timeIntervalSince1970: 1_790_000_000)),
            ExampleItem(
                id: "beta", title: "Beta", detail: "Needs a look",
                status: .attention, modified: Date(timeIntervalSince1970: 1_790_086_400)),
            ExampleItem(
                id: "gamma", title: "Gamma", detail: "Everything is in order",
                status: .ok, modified: Date(timeIntervalSince1970: 1_790_172_800)),
        ]
    }
#endif
