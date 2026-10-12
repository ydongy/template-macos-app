import SwiftUI
import TemplateCore

/// App entry point: a menu bar item whose panel shows the sample screen.
@main
struct TemplateApp: App {
    @State private var model = ExampleModel(source: LiveExampleSource())
    @State private var updater = AppUpdater()

    init() {
        UICopy.provider = AppLanguage.shared
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(model: model, updater: updater)
        } label: {
            Image(systemName: "square.stack")
                .accessibilityLabel(String.loc("Template"))
        }
        .menuBarExtraStyle(.window)
    }
}
