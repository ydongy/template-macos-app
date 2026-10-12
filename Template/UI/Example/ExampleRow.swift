import SwiftUI
import TemplateCore

/// One line of the list: status symbol, title and detail, date.
struct ExampleRow: View {
    let item: ExampleItem

    var body: some View {
        HStack(spacing: DesignTokens.Space.md) {
            statusSymbol
            VStack(alignment: .leading, spacing: DesignTokens.Space.xxs) {
                Text(verbatim: item.title)
                    .font(DesignTokens.Typography.rowTitle)
                    .foregroundStyle(DesignTokens.Palette.ink)
                Text(verbatim: item.detail)
                    .font(DesignTokens.Typography.meta)
                    .foregroundStyle(DesignTokens.Palette.inkSecondary)
            }
            Spacer(minLength: DesignTokens.Space.sm)
            Text(item.modified, format: .dateTime.month(.abbreviated).day())
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Palette.inkSecondary)
        }
        .frame(minHeight: DesignTokens.Metrics.rowHeight)
        .padding(.horizontal, DesignTokens.Space.md)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("example.row.\(item.id)")
    }

    @ViewBuilder
    private var statusSymbol: some View {
        switch item.status {
        case .ok:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(DesignTokens.Palette.ok)
                .accessibilityLabel("OK")
        case .attention:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DesignTokens.Palette.attention)
                .accessibilityLabel("Needs attention")
        }
    }
}

#if DEBUG
    #Preview("Row · ok") {
        ExampleRow(item: ExamplePreviewData.items[0])
            .frame(width: DesignTokens.PanelMetrics.width)
    }

    #Preview("Row · needs attention") {
        ExampleRow(item: ExamplePreviewData.items[1])
            .frame(width: DesignTokens.PanelMetrics.width)
    }
#endif
