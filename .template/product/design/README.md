# Design mockups

The files in `design/` are self-contained HTML pages with no external resources.

- `screens/example.html`: the Example screen. Open it in a browser, no server needed. With no query it shows every
  state side by side in light and dark; `?state=loading|loaded|empty|failed` shows one state at the real panel size
  and `?scheme=light|dark` forces the color scheme (otherwise it follows the system appearance).
- `tokens.html`: the design tokens as swatches and samples: spacing, radii, type, colors in both appearances,
  metrics and motion.

The colors in the mockups approximate the macOS system colors; the app itself uses the system colors.

## Working rules

A UI change starts from the mockup: edit or add `screens/<screen>.html`, get the visual direction confirmed by the
maintainer, then write the UI code in `Template/UI/<Screen>/`. A screen file is named like its code directory and
shows every state through `?state=`. The CSS custom properties carry the names and numbers of
`TemplateCore/Sources/TemplateCore/Design/DesignTokens.swift`: a token changes in the Swift file, in
`docs/design.md`, in `tokens.html` and in each screen's `:root` block together. Screenshots of the running app
are not tracked: capture them into `design/screenshots/` (ignored) and show light and dark in the pull request
description.
