<!-- template: spec.md v2 -->
# Template specification

In one sentence: **a menu bar utility that shows one list of items with a status each, and keeps itself up to date.** The list is the sample screen `Example`; a product replaces its contents and keeps the structure.

UI strings are quoted in English (the String Catalog keys); the other eight languages are translations of them.

## Decisions

| Decision | Reason | Record |
|---|---|---|
| **Menu bar only** (`LSUIElement`, `MenuBarExtra` in window style), no Dock icon and no main window | The product is glanced at and dismissed; a window would add a surface to maintain | This document |
| Everything that is not UI lives in the TemplateCore package, with MainActor default isolation and `nonisolated` domain values | Core builds and tests without the UI; services are main-actor, values are readable anywhere | [0001](adr/0001-templatecore-package-with-mainactor-default-isolation.md) |
| **No App Sandbox**, Hardened Runtime on, Developer ID signing and notarization, distributed from the website | The sandbox forbids the file and process access a utility of this kind grows into; Hardened Runtime and notarization keep the app trustworthy | This document |
| macOS 26.0 and later, Swift 6 language mode | One system version to test; strict concurrency from the first line | [handbook/types/app/code.md](https://github.com/ydongy/.github/blob/6b48552c969c28a954498123bb502a556f8eed79/handbook/types/app/code.md), [handbook/stacks/swift.md](https://github.com/ydongy/.github/blob/6b48552c969c28a954498123bb502a556f8eed79/handbook/stacks/swift.md) |
| Sparkle 2 for updates, in the app target only | Core stays free of third-party code | [0001](adr/0001-templatecore-package-with-mainactor-default-isolation.md) |
| Nine UI languages, English as the only reference; the app follows the system language and `AppLanguage` is ready for a chooser | Every user reads the product in their own language | [handbook/guides/localization.md](https://github.com/ydongy/.github/blob/6b48552c969c28a954498123bb502a556f8eed79/handbook/guides/localization.md) |
| Mock and preview types exist in DEBUG builds only | Release builds contain none of them; `FORBID_SYMBOLS` in `Config/release.conf` makes the release script check it | [0001](adr/0001-templatecore-package-with-mainactor-default-isolation.md) |

**Not in the baseline**: a Settings window, an About screen, a main window, notifications, login item, paid plans, any network access besides the update check.

## Information architecture

One surface: the **menu bar panel**, 320 pt wide, opened from the menu bar icon. Mockup: [design/screens/example.html](../design/screens/example.html); how to read it: [design/README.md](../design/README.md#screens).

```
┌──────────────────────────────────────┐
│ Example   3 items            Refresh │  header
├──────────────────────────────────────┤
│ (ok)  Alpha                   Sep 21 │
│       Everything is in order         │  list (loaded) or one message
│ (!)   Beta                    Sep 22 │  (loading, empty, failed)
│       Needs a look                   │
├──────────────────────────────────────┤
│ Check for Updates…              Quit │  footer
└──────────────────────────────────────┘
```

- **Header**: the title "Example", the item count ("3 items") when loaded, and "Refresh", which loads again.
- **Content** has four states. Loading: a progress indicator with "Loading…". Loaded: the rows. Empty: "Nothing here yet" with "Items you add appear in this list." Failed: "Could not load the items" with "Check that the data file is valid, then try again." and the button "Try Again".
- **Footer**: "Check for Updates…" (shown only while the updater is enabled, see [Updates](#updates)) and "Quit" (command-Q).
- The panel loads the items every time it opens. The content area is between 200 and 420 pt high and scrolls beyond that.
- The menu bar icon is the symbol `square.stack`; its accessibility label is the product name.

## Data model

```swift
struct ExampleItem: Identifiable, Hashable, Sendable, Codable {
    enum Status: String { case ok, attention }
    let id: String
    let title: String
    let detail: String
    let status: Status
    let modified: Date
}
```

- Storage: `~/Library/Application Support/<bundle identifier>/example-items.json`, a JSON array with ISO 8601 dates. The app only reads it. A missing file is an empty list (the empty state); a file that cannot be decoded is the failed state.
- Preferences: the chosen UI language is the `UserDefaults` key `settings.language` (`system` or a language code). The baseline has no screen that writes it, so the app follows the system language.
- Nothing is stored in the Keychain; the baseline holds no credential.

## Modules

| Module | Owns |
|---|---|
| `Template/App` | `TemplateApp` (entry point and menu bar scene), `MenuBarContent` (panel and footer), `AppUpdater` (Sparkle), `AppLanguage` (language choice and lookup), `ProductLinks` (website addresses) |
| `Template/UI/Example` | `ExampleView`, `ExampleRow`, `ExampleModel` (phase: loading, empty, loaded, failed), `ExamplePreviewData` (DEBUG) |
| `TemplateCore/Domain` | `ExampleItem`, `nonisolated` |
| `TemplateCore/Services` | `ExampleSource` protocol, `LiveExampleSource`, `MockExampleSource` (DEBUG), `UICopy` and `String.loc` |
| `TemplateCore/Design` | `DesignTokens`: spacing, radii, motion, typography, metrics, panel metrics, palette ([docs/design.md](design.md#color)) |
| `TemplateTests` | Swift Testing: model phases, the live source, language and copy lookup, website links, design tokens, Info.plist keys, the String Catalog |

Dependencies point one way: views depend on `ExampleModel`; the model depends on the `ExampleSource` protocol; Core never imports the app target.

## Key flows

### Licensing

The baseline has no plans, license keys or purchases, and the app contacts no licensing service. The terms in `LICENSE` say so, and [docs/legal.md](legal.md#facts-that-must-match-the-code) records the facts. A product that adds paid plans writes here: what the free plan includes, what the paid plan adds, how many Macs a key covers, the offline grace period and the activation flow, and rewrites the matching sections of `LICENSE` and the facts table in the same change.

### Updates

- Sparkle 2 reads `appcast.xml` from `https://dl.example.com` (`SUFeedURL`, set from `SPARKLE_FEED_URL` in `project.yml`). Updates are signed with an EdDSA key; the public half is `SPARKLE_PUBLIC_KEY`.
- The updater runs only when the build carries that public key. Without it `AppUpdater.isEnabled` is false, no check happens and the footer hides "Check for Updates…".
- The app checks about once a day (`SUScheduledCheckInterval` is 86400) and on request from the footer. No system profile is sent (`SUEnableSystemProfiling` is false). A new version is installed only after the user confirms.
- `CURRENT_PROJECT_VERSION` (`Config/Version.xcconfig`) is what Sparkle compares; it rises with every release (`scripts/bump.sh`).
- The minimum OS in the feed is the app's `LSMinimumSystemVersion`, 26.0. The feeds are described in [docs/website.md](website.md#downloads-and-feeds).

## Technical baseline

- Platform: macOS 26.0 or later. Swift 6 language mode, warnings are errors, the app target is MainActor-isolated by default.
- Dependencies: Sparkle 2.10.0 (SwiftPM, app target only); TemplateCore has none. See `THIRD_PARTY.md`.
- Signing: Hardened Runtime on, App Sandbox off, Developer ID and notarization for releases.
- Localization: English source plus zh-Hans, zh-Hant, ja, ko, fr, de, es, pt-BR; every key carries every language (`LocalizationCatalogTests`).
- Budgets: the panel opens without a visible delay and the app idles at no measurable CPU; the budget numbers are set when the first real screen exists.
- Release builds contain no Mock or Preview symbols.

## Acceptance checklist

- [ ] The app shows only a menu bar icon; the panel is 320 pt wide and opens the Example screen
- [ ] Loading, loaded, empty and failed states each appear as in `design/screens/example.html`, light and dark
- [ ] "Refresh" and "Try Again" load again; a missing data file shows the empty state, an invalid one the failed state
- [ ] "Quit" quits; command-Q works while the panel is open
- [ ] With no update key the footer has no "Check for Updates…" and no check happens
- [ ] With a key, "Check for Updates…" finds a higher build and installs it after confirmation
- [ ] All nine languages show translated text; none is truncated
- [ ] VoiceOver reads every control and each row as one element
- [ ] The Release build contains no Mock or Preview symbols
