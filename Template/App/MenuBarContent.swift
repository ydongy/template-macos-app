import AppKit
import SwiftUI
import TemplateCore

/// The menu bar panel: the sample screen above a footer with the app-level actions.
struct MenuBarContent: View {
    let model: ExampleModel
    let updater: AppUpdater

    var body: some View {
        VStack(spacing: 0) {
            ExampleView(model: model)
            Divider()
            HStack {
                if updater.isEnabled {
                    Button("Check for Updates…", action: updater.checkForUpdates)
                        .accessibilityIdentifier("menubar.check-updates")
                }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
                    .accessibilityIdentifier("menubar.quit")
            }
            .buttonStyle(.link)
            .padding(DesignTokens.Space.md)
        }
        .frame(width: DesignTokens.PanelMetrics.width)
        .task { await model.load() }
        .uiLocale()
    }
}
