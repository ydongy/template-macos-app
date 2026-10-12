import TemplateCore

#if DEBUG
    /// Preview-only data. DEBUG only; `FORBID_SYMBOLS` in `Config/release.conf` keeps it out of Release.
    @MainActor
    enum ExamplePreviewData {
        static let items = MockExampleSource.sampleItems

        /// A model frozen in `phase`; its source is never asked.
        static func model(_ phase: ExampleModel.Phase) -> ExampleModel {
            ExampleModel(source: MockExampleSource(.pending), phase: phase)
        }
    }
#endif
