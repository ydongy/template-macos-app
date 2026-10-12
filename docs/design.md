# Template design language

Every value below mirrors `TemplateCore/Sources/TemplateCore/Design/DesignTokens.swift`; `design/tokens.html` shows them and `design/screens/example.html` is the Example screen drawn with them. Change the three together.

## Principles

1. **Tokens only.** Colors, spacing, radii, motion and panel sizes come from `DesignTokens`; views contain no magic numbers. A new value goes into the Swift file, this document and `design/tokens.html` first, then into a view.
2. **Native first.** System fonts, system colors and standard controls, so light and dark, Dynamic Type, Increase Contrast and Reduce Motion work without extra code.
3. **Every state is designed.** Loading, loaded, empty and failed are drawn before they are coded, and each has a `#Preview`.
4. **Quiet by default.** The panel is read at a glance: one title, rows, two footer links. Color appears only where it carries a status.
5. **Copy is design.** Text goes through the String Catalog; the English text is the key.

## Core symbol

The signature element is the **status symbol** at the start of each row: a filled SF Symbol that says in one glance whether the item is fine.

| Status | Symbol | Color token |
|---|---|---|
| `ok` | `checkmark.circle.fill` | `Palette.ok` (green) |
| `attention` | `exclamationmark.triangle.fill` | `Palette.attention` (orange) |

- Shape carries the meaning as much as color: a circle with a check against a triangle with a mark, so the status reads without color.
- Red is not a row status: `Palette.failure` is reserved for errors that stop an action and is unused by the baseline screen (the failed state is drawn in secondary ink).
- The symbol is followed by `Space.md` (12), then the title and detail. It has an accessibility label ("OK", "Needs attention"); the row reads as one element.
- A new status adds a symbol and a color token here and in `design/tokens.html`, and a row in the table above.

## Color

Light and dark come from the system appearance; there are no per-mode overrides in code. The mockups approximate the system colors; see `design/tokens.html` for the values used.

| Token | Role |
|---|---|
| `Palette.ink` | Titles, primary text (`.primary`) |
| `Palette.inkSecondary` | Details, dates, the count, message symbols (`.secondary`) |
| `Palette.surface` | A raised surface such as a card (`controlBackgroundColor`) |
| `Palette.hairline` | Dividers (`separatorColor`) |
| `Palette.accent` | The accent color chosen in System Settings |
| `Palette.ok` / `attention` / `failure` | Status: green, orange, red (system colors) |

Rules: status never relies on color alone (see Core symbol); text stays at the system label colors, which meet contrast requirements in both appearances.

## Typography

System fonts through semantic styles, so the user's settings keep working.

| Token | Style | Used for |
|---|---|---|
| `Typography.title` | title3, bold | The screen title ("Example") |
| `Typography.rowTitle` | body, semibold | Row title, message title |
| `Typography.body` | body | Running text |
| `Typography.meta` | subheadline | Row detail, item count, message detail |
| `Typography.caption` | caption | Row date |

Buttons use the system button font. Numbers and dates are formatted with the app's locale.

## Layout and spacing

| Token | Value |
|---|---|
| `Space.xxs / xs / sm / md / lg / xl` | 2 / 4 / 8 / 12 / 16 / 24 |
| `Radius.row / card / pill` | 8 / 10 / 999 |
| `Metrics.rowHeight` | 44 minimum row height |
| `Metrics.statusDot` | 8 |
| `Metrics.emptyIcon` | 36 (message symbol size) |
| `Metrics.hairline` | 1 |
| `PanelMetrics.width` | 320 |
| `PanelMetrics.minHeight / maxHeight` | 200 / 420 (content area) |

The panel is 320 wide. The header and footer pad with `Space.md`; rows pad horizontally with `Space.md`; messages pad with `Space.xl`. Dividers between rows start at `Space.md`. Density is compact: one line of title, one of detail.

## Materials

The panel uses the system menu bar window material; the app draws no background of its own. Glass is for the navigation layer only and is never stacked, so this screen has none. `Palette.surface` is for a card inside the panel when a screen needs one.

## Icons

The menu bar icon is the SF Symbol `square.stack` until the product has its own mark; the app icon is exported from the design source under `design/icon/` once it exists. Status and message symbols are SF Symbols in the system rendering. Decorative symbols are hidden from VoiceOver.

## Motion

| Token | Value |
|---|---|
| `Motion.standard` | ease in and out, 0.2 s |

It animates the change between states of the panel. Nothing animates on redraw, and entrance animations play on first appearance only. With Reduce Motion on, state changes are instant.

## Signature moments

None. The product allows no decoration beyond the status symbol.

## Copy tone

Short and plain: one necessary sentence. Say what happened and what to do next; no blame, no exclamation marks, no infrastructure words the user did not choose. Example: "Could not load the items" and "Check that the data file is valid, then try again." Buttons are verbs: "Refresh", "Try Again", "Quit". Menu items that open a window or a dialog end with an ellipsis ("Check for Updates…").

## Accessibility

- Every interactive element has an `accessibilityIdentifier` named `<screen>.<element>` (`example.refresh`, `example.retry`, `menubar.quit`) and a label VoiceOver can read; decorative symbols use `accessibilityHidden(true)`.
- A row is one accessibility element: status label, title, detail, date.
- Text uses semantic styles and system colors; status is also carried by shape.
- Motion respects Reduce Motion; no information is shown by animation alone.
- `scripts/ax-audit.swift` flags unnamed controls and untranslated text in the running app.

## Design acceptance checklist

- [ ] Every state of the screen is drawn in `design/screens/` and has a `#Preview`, light and dark
- [ ] Colors, spacing, radii, motion and sizes come from `DesignTokens`; no magic numbers
- [ ] Status is readable without color
- [ ] Every interactive element has an identifier and a label; decorative elements are hidden
- [ ] Text fits in all nine languages without truncation
- [ ] Reduce Motion and Increase Contrast checked
- [ ] Screenshots of every state, light and dark, are attached to the PR
