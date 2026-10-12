import AppKit
import SwiftUI

/// Single source of truth for design tokens. Views must not hard-code values: extend this file,
/// `docs/design.md` and `design/tokens.html` together.
nonisolated public enum DesignTokens {
    nonisolated public enum Space {
        public static let xxs: CGFloat = 2
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 24
    }

    nonisolated public enum Radius {
        public static let row: CGFloat = 8
        public static let card: CGFloat = 10
        public static let pill: CGFloat = 999
    }

    nonisolated public enum Motion {
        public static let standard: Animation = .easeInOut(duration: 0.2)
    }

    /// Semantic system fonts, so Dynamic Type and the user's settings keep working.
    nonisolated public enum Typography {
        public static let title: Font = .title3.bold()
        public static let rowTitle: Font = .body.weight(.semibold)
        public static let body: Font = .body
        public static let meta: Font = .subheadline
        public static let caption: Font = .caption
    }

    nonisolated public enum Metrics {
        public static let rowHeight: CGFloat = 44
        public static let statusDot: CGFloat = 8
        public static let emptyIcon: CGFloat = 36
        public static let hairline: CGFloat = 1
    }

    /// The menu bar panel that hosts the sample screen.
    nonisolated public enum PanelMetrics {
        public static let width: CGFloat = 320
        public static let minHeight: CGFloat = 200
        public static let maxHeight: CGFloat = 420
    }

    /// Light and dark come from the system appearance; there are no per-mode overrides.
    nonisolated public enum Palette {
        public static let ink: Color = .primary
        public static let inkSecondary: Color = .secondary
        public static let surface: Color = Color(nsColor: .controlBackgroundColor)
        public static let hairline: Color = Color(nsColor: .separatorColor)
        public static let accent: Color = .accentColor
        public static let ok: Color = .green
        public static let attention: Color = .orange
        public static let failure: Color = .red
    }
}
