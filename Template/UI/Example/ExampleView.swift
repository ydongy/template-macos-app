import SwiftUI
import TemplateCore

/// The sample screen. View, model and row are separate files: the view only renders the model's
/// phase and forwards actions; the row is a pure function of one item.
struct ExampleView: View {
    let model: ExampleModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
                .frame(
                    maxWidth: .infinity, minHeight: DesignTokens.PanelMetrics.minHeight,
                    maxHeight: DesignTokens.PanelMetrics.maxHeight)
        }
        .animation(DesignTokens.Motion.standard, value: model.phase)
    }

    private var header: some View {
        HStack {
            Text("Example")
                .font(DesignTokens.Typography.title)
                .foregroundStyle(DesignTokens.Palette.ink)
                .accessibilityIdentifier("example.title")
            if case .loaded(let items) = model.phase {
                Text("\(items.count) items")
                    .font(DesignTokens.Typography.meta)
                    .foregroundStyle(DesignTokens.Palette.inkSecondary)
                    .accessibilityIdentifier("example.count")
            }
            Spacer()
            Button("Refresh") { Task { await model.load() } }
                .accessibilityIdentifier("example.refresh")
        }
        .padding(DesignTokens.Space.md)
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            ProgressView("Loading…")
                .accessibilityIdentifier("example.progress")
        case .empty:
            message(
                symbol: "tray", title: "Nothing here yet",
                detail: "Items you add appear in this list.", identifier: "example.empty")
        case .failed:
            VStack(spacing: DesignTokens.Space.md) {
                message(
                    symbol: "exclamationmark.triangle", title: "Could not load the items",
                    detail: "Check that the data file is valid, then try again.",
                    identifier: "example.failed")
                Button("Try Again") { Task { await model.load() } }
                    .accessibilityIdentifier("example.retry")
            }
        case .loaded(let items):
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(items) { item in
                        ExampleRow(item: item)
                        Divider().padding(.leading, DesignTokens.Space.md)
                    }
                }
            }
            .accessibilityIdentifier("example.list")
        }
    }

    private func message(
        symbol: String, title: LocalizedStringKey, detail: LocalizedStringKey, identifier: String
    )
        -> some View
    {
        VStack(spacing: DesignTokens.Space.sm) {
            Image(systemName: symbol)
                .font(.system(size: DesignTokens.Metrics.emptyIcon))
                .foregroundStyle(DesignTokens.Palette.inkSecondary)
                .accessibilityHidden(true)
            Text(title)
                .font(DesignTokens.Typography.rowTitle)
                .foregroundStyle(DesignTokens.Palette.ink)
            Text(detail)
                .font(DesignTokens.Typography.meta)
                .foregroundStyle(DesignTokens.Palette.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(DesignTokens.Space.xl)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }
}

#if DEBUG
    #Preview("Example · loading") {
        ExampleView(model: ExamplePreviewData.model(.loading))
            .frame(width: DesignTokens.PanelMetrics.width)
    }

    #Preview("Example · loaded") {
        ExampleView(model: ExamplePreviewData.model(.loaded(ExamplePreviewData.items)))
            .frame(width: DesignTokens.PanelMetrics.width)
    }

    #Preview("Example · empty") {
        ExampleView(model: ExamplePreviewData.model(.empty))
            .frame(width: DesignTokens.PanelMetrics.width)
    }

    #Preview("Example · failed") {
        ExampleView(model: ExamplePreviewData.model(.failed))
            .frame(width: DesignTokens.PanelMetrics.width)
    }

    #Preview("Example · loaded, dark") {
        ExampleView(model: ExamplePreviewData.model(.loaded(ExamplePreviewData.items)))
            .frame(width: DesignTokens.PanelMetrics.width)
            .preferredColorScheme(.dark)
    }
#endif
