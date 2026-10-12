# Template

Template is a macOS menu bar utility that shows one list of items with a status each, so that you can see at a glance what is fine and what needs a look, and keeps itself up to date.

## Status

Version 1.0.0 is in preparation: the app, the tests and the release scripts exist; the first real screen, signing, notarization and the website are the remaining work. Requires macOS 26.0 or later. See [docs/roadmap.md](docs/roadmap.md).

## Product

- **At a glance**: lives in the menu bar; the panel lists the items, each with a status symbol, a detail line and a date.
- **Four states**: loading, loaded, empty and failed, each with a clear message and a way to try again.
- **Always current**: updates arrive inside the app and are installed only after you confirm.
- **Nine languages**: English, Chinese (simplified and traditional), Japanese, Korean, French, German, Spanish and Portuguese (Brazil).
- **Private**: no account, no telemetry; the only network request is the update check.

## Install

Download the `.dmg` from [example.com](https://example.com), drag Template to Applications and open it; the website shows the SHA-256 hash of each download, which `shasum -a 256 <file>` must reproduce. Updates are installed inside the app after you confirm them.

## Development

Requirements: macOS 26.0 or later, Xcode 27. The project is described by [XcodeGen](https://github.com/yonaskolb/XcodeGen): after changing `project.yml`, run `xcodegen generate` and commit `Template.xcodeproj`; CI fails if it is stale. The version lives in `Config/Version.xcconfig` only and is changed with `scripts/bump.sh <X.Y.Z>`.

```bash
xcodegen generate

xcodebuild build -project Template.xcodeproj -scheme Template \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO

xcodebuild test -project Template.xcodeproj -scheme Template \
  -destination 'platform=macOS' -testLanguage en -testRegion US CODE_SIGNING_ALLOWED=NO

xcrun swift-format lint --strict --recursive Template TemplateCore TemplateTests
```

Contribution rules (commit scopes, branches, changelog, releasing) are in [CONTRIBUTING.md](CONTRIBUTING.md).

## Documentation

| Document | Contents |
|---|---|
| [docs/spec.md](docs/spec.md) | What to build |
| [docs/design.md](docs/design.md) | Design language |
| [docs/roadmap.md](docs/roadmap.md) | What comes next |
| [docs/legal.md](docs/legal.md) | Legal facts and the code they must match |
| [docs/website.md](docs/website.md) | What the app depends on from the website |
| [docs/releasing.md](docs/releasing.md) | How a release is made |
| [docs/security/](docs/security/README.md) | One security review per version |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Commits, branches, changelog |
| [docs/adr/](docs/adr/README.md) | Decisions |
| [design/README.md](design/README.md) | Design mockups |
| [CHANGELOG.md](CHANGELOG.md) | Changes |
| [THIRD_PARTY.md](THIRD_PARTY.md) | Third-party software |
| [AGENTS.md](AGENTS.md) | Brief for AI collaborators |

## License

Closed source, all rights reserved. [LICENSE](LICENSE) is the terms of service and the license agreement, with the same text as [example.com/terms](https://example.com/terms); third-party software is listed in [THIRD_PARTY.md](THIRD_PARTY.md).
