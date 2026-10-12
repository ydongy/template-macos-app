import Foundation
import TemplateCore
import Testing

@testable import Template

struct ExampleModelTests {
    @Test func startsLoading() {
        let model = ExampleModel(source: MockExampleSource())
        #expect(model.phase == .loading)
    }

    @Test func loadedItemsAreShown() async {
        let source = MockExampleSource(.items(MockExampleSource.sampleItems))
        let model = ExampleModel(source: source)
        await model.load()
        #expect(model.phase == .loaded(MockExampleSource.sampleItems))
        #expect(source.loadCount == 1)
    }

    @Test func noItemsIsTheEmptyState() async {
        let model = ExampleModel(source: MockExampleSource(.items([])))
        await model.load()
        #expect(model.phase == .empty)
    }

    @Test func aFailureIsShownAndTheNextLoadRecovers() async {
        let source = MockExampleSource(.failure)
        let model = ExampleModel(source: source)
        await model.load()
        #expect(model.phase == .failed)

        source.behavior = .items(MockExampleSource.sampleItems)
        await model.load()
        #expect(model.phase == .loaded(MockExampleSource.sampleItems))
        #expect(source.loadCount == 2)
    }

    @Test func aCancelledLoadLeavesTheLoadingState() async {
        let model = ExampleModel(source: MockExampleSource(.pending))
        let task = Task { await model.load() }
        await Task.yield()
        task.cancel()
        await task.value
        #expect(model.phase == .loading)
    }

    @Test func previewModelsStayInTheirPhase() {
        let model = ExamplePreviewData.model(.failed)
        #expect(model.phase == .failed)
    }
}
