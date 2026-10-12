<!-- template: adr.md v1 -->
# 0001 TemplateCore package with MainActor default isolation

- Status: accepted
- Date: 2026-10-03
- Related: [handbook/types/app/layout.md](https://github.com/ydongy/.github/blob/f61354c75725bf3688632a9d3040e5664046f81a/handbook/types/app/layout.md), [handbook/stacks/swift.md](https://github.com/ydongy/.github/blob/f61354c75725bf3688632a9d3040e5664046f81a/handbook/stacks/swift.md)

## Context

Template is a menu bar utility. Its logic (where the items come from, how they are decoded, the design tokens, the
copy lookup) has nothing to do with views, and mixed into the app target it could only be built and tested together
with the UI. Nearly all of it is small main-actor services; there are no background engines. The only types that
background work must read are the plain values of the domain. Sparkle is the one third-party dependency and it
belongs to the macOS shell of the app, not to the logic.

## Decision

- `TemplateCore` (`TemplateCore/`) is a local SwiftPM package with `Domain/`, `Services/` and `Design/`. `Template/`
  keeps `App/` (entry point, updater, language, links) and `UI/` (one directory per screen). Core never references
  the app target.
- The package sets `.defaultIsolation(MainActor.self)` in `TemplateCore/Package.swift`. Domain value types
  (`ExampleItem`) and `DesignTokens` are `nonisolated`, so any execution domain can read them.
- Core has no third-party dependency. Sparkle stays in the app target (`AppUpdater`).
- The package API is `public`; a type the app constructs has an explicit `public init`. Tests use
  `@testable import TemplateCore`.
- Mock, in-memory and preview-only types (`MockExampleSource`) are inside `#if DEBUG`. `FORBID_SYMBOLS` in
  `Config/release.conf` makes `scripts/release.sh` fail when such a symbol is found in the built app.

## Cost

- Every declaration the app uses is `public`, and a type the app constructs needs an explicit initializer.
- A MainActor-isolated protocol cannot be implemented by an actor, so test doubles are `final class` and private to
  their test file.
- Work that must leave the main actor (the file read in `LiveExampleSource`) has to say so explicitly.
- Two places must stay in step with the layout: `lint-paths` in `.github/workflows/ci.yml` and the source roots of
  `UserVisibleStringsTests`.

## Revisit triggers

Core gains background engines or most of its types end up `nonisolated`; Core needs bundled resources (it then needs
its own `resources:` entry).
