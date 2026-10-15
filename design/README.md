# Design mockups

## Viewing

The files in `design/` are self-contained HTML pages with no external resources; open them in a browser, no server needed. `screens/example.html` with no query shows every state side by side in light and dark. Add `?state=loading|loaded|empty|failed` to see one state at the real panel size, and `?scheme=light|dark` to force the color scheme; without `scheme` the page follows the system appearance. `tokens.html` shows the design tokens: spacing, radii, type, colors in both appearances, metrics and motion.

The colors in the mockups are approximations of the macOS system colors; the app itself uses the system colors. The footer shows "Check for Updates…" as it appears while the updater is enabled.

## Screens

| Screen | File | States | Light and dark |
|---|---|---|---|
| Example | `screens/example.html` | loading, loaded, empty, failed | yes |
| Design tokens | `tokens.html` | not a screen: the tokens as swatches and samples | yes |

## Maintenance

Edit the mockup first, get the visual direction confirmed by the maintainer, then change the UI code that matches it. A screen file is named like the code directory `Template/UI/<Screen>/`, shows every state through `?state=` and appears in the table above. The CSS custom properties carry the names and numbers of `TemplateCore/Sources/TemplateCore/Design/DesignTokens.swift`: a token changes in the Swift file, in `docs/design.md`, in `tokens.html` and in each screen's `:root` block together. Screenshots of the running app are not tracked: capture them into `design/screenshots/` (ignored) and show light and dark in the pull request description.
