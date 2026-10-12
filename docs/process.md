<!-- template: process.md v1 -->
# Template development process

The process is the ydongy handbook (`https://github.com/ydongy/.github/tree/6b48552c969c28a954498123bb502a556f8eed79/handbook`).
This file lists only what is specific to Template.

## Commit scopes and labels

Optional, pick one; each is also a GitHub label: `app` `core` `ui` `design` `docs` `release` `build` `ci` `deps`.

| Scope | For |
|---|---|
| `app` | `Template/App`: entry point, menu bar scene, updater, language, links |
| `core` | `TemplateCore`: domain, services, design tokens |
| `ui` | `Template/UI`: screens, models, rows |
| `design` | `design/` mockups and `docs/design.md` |
| `docs` | everything else in `docs/`, README, AGENTS |
| `release` | `scripts/release.sh`, `Config/release.conf`, changelog tooling |
| `build` | `project.yml`, the generated project, signing settings |
| `ci` | `.github/workflows` |
| `deps` | dependency bumps |

Examples: `feat(ui): show the item count in the header`, `fix(core): treat a missing file as an empty list`.

## Contracts

None.

## CI

The docs workflow and handbook link pin the same ydongy/.github revision. Upgrade both explicitly;
changes to the shared handbook on main do not alter this repository's checks.

`.github/workflows/ci.yml` calls the shared `macos-ci.yml` with the project `Template.xcodeproj`, the scheme `Template`, `lint-paths: Template TemplateCore TemplateTests` and the compatibility job on pushes to `main` only. The shared workflow runs `xcodegen generate` and fails if the project changed, `swift-format lint --strict` over the lint paths, a Release build and the tests; the compatibility job repeats build and tests with the previous Xcode. `lint-paths` and the source roots of `UserVisibleStringsTests` must stay in step with the directories. `.github/workflows/docs.yml` runs the documentation check.

## History

None.
