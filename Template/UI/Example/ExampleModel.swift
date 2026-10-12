import Observation
import TemplateCore

/// State of the Example screen. Depends on the `ExampleSource` protocol only, never on a concrete
/// client, so tests and previews swap the source (`docs/adr/0001-templatecore-package-with-mainactor-default-isolation.md`).
@Observable
@MainActor
final class ExampleModel {
    enum Phase: Equatable {
        case loading
        case empty
        case loaded([ExampleItem])
        case failed
    }

    private(set) var phase: Phase = .loading
    @ObservationIgnored private let source: any ExampleSource

    init(source: any ExampleSource) {
        self.source = source
    }

    #if DEBUG
        /// A model frozen in one phase, for previews of every state.
        init(source: any ExampleSource, phase: Phase) {
            self.source = source
            self.phase = phase
        }
    #endif

    /// Loads the items. A cancelled load leaves the screen as it was.
    func load() async {
        phase = .loading
        do {
            let items = try await source.items()
            phase = items.isEmpty ? .empty : .loaded(items)
        } catch is CancellationError {
            return
        } catch {
            phase = .failed
        }
    }
}
