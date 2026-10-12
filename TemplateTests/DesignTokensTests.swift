import TemplateCore
import Testing

struct DesignTokensTests {
    @Test func spacingGrowsStrictly() {
        typealias Space = DesignTokens.Space
        let scale = [Space.xxs, Space.xs, Space.sm, Space.md, Space.lg, Space.xl]
        #expect(scale == scale.sorted())
        #expect(Set(scale).count == scale.count)
    }

    @Test func thePanelHasRoomForAtLeastOneRow() {
        #expect(DesignTokens.PanelMetrics.minHeight > DesignTokens.Metrics.rowHeight)
        #expect(DesignTokens.PanelMetrics.maxHeight > DesignTokens.PanelMetrics.minHeight)
    }

    @Test func pillRadiusIsLargerThanAnyBox() {
        #expect(DesignTokens.Radius.pill > DesignTokens.PanelMetrics.width)
    }
}
