<!-- template: template/README.md v1 -->
# template-macos-app

The starting point for every macOS menu bar app by ydongy: a project that builds, tests and
releases from the first commit, with the documentation and design skeleton the handbook asks for. It is a
GitHub template repository (MIT licensed); the product is called `Template` here until `scripts/init.sh` gives it
its real name.

## What is here

| Path | Purpose |
|---|---|
| `project.yml`, `Config/` | XcodeGen definition, `Version.xcconfig`, Info.plist keys, `release.conf` (every product-specific release value) |
| `Template/` | App target: `App/` (entry point, language, links, updater), `UI/Example/` (the sample screen: View, Model, Row), `Resources/` |
| `TemplateCore/` | Local Swift package: `Domain/`, `Services/` (protocols, Live and DEBUG-only mock, `String.loc`), `Design/` (`DesignTokens`) |
| `TemplateTests/` | Swift Testing: model, links, language and bundle tests, `LocalizationCatalogTests`, `UserVisibleStringsTests` |
| `docs/`, `design/` | Spec, design language, roadmap, legal facts, website contract, process delta, first ADR, v1.0 milestone, token page and the Example screen mockup |
| `scripts/` | `release.sh`, `release-credentials.sh`, `test-release.sh`, `bump.sh`, `scan_secrets.py`, `website-changelog.py`, `init.sh` |
| `.template/` | The product `README.md` and `AGENTS.md` that `init.sh` moves into place |
| `.github/workflows/` | `ci.yml`, `docs.yml`, `release.yml`: thin callers of the shared workflows |
| `.claude/`, `.codex/` | AI tool settings (swift-format hook, narrow permission allowlist) |

## Using it

1. On GitHub choose **Use this template** and create your repository (private or public).
2. Clone it and run `scripts/init.sh <Name> <domain>`, for example `scripts/init.sh Acme acme.com`. It renames
   the directories, modules and bundle id (`com.<domain-reversed>.app`), rewrites URLs, the Sparkle feed and the
   release settings, switches the repository type to `app`, installs the product `README.md` and `AGENTS.md`,
   regenerates the Xcode project and removes itself.
3. Check the result: `xcodebuild test -project <Name>.xcodeproj -scheme <Name> -destination 'platform=macOS'
   -testLanguage en -testRegion US CODE_SIGNING_ALLOWED=NO`, then
   `xcrun swift-format lint --strict --recursive <Name> <Name>Core <Name>Tests`.
4. Run `python3 <dotgithub>/scripts/check-docs.py .`, then rewrite the skeleton documents for the real product
   (`docs/spec.md` first).
5. Generate the Sparkle key (`generate_keys --account <name>`), put the public key in `SPARKLE_PUBLIC_KEY` in
   `project.yml`, and store release settings with `scripts/release-credentials.sh set`.
6. Replace the Example screen with the first real screen, following `handbook/types/app/playbooks/add-screen.md`.

## Changing it

A change to the template is a pull request here. Keep the skeleton buildable and the checks green:
`scripts/test-release.sh`, `python3 scripts/test_website_changelog.py`, the Xcode build and tests, and
`scripts/test-init.sh`, which copies the repository, runs `init.sh` on the copy with a probe name and builds and
tests the result. The names `Template` and `example.com` are the placeholders `init.sh` replaces; do not write a
real product name anywhere. Products already created from the template do not follow it automatically: a
useful change is announced in the handbook and applied to each product by hand.

## License

This template is released under the [MIT License](LICENSE), copyright (c) 2026 ydongy. Running `scripts/init.sh` replaces `LICENSE` with a terms-of-service placeholder (from `.template/LICENSE`) for the new product; replace it with the license you choose. Third-party software is listed in [THIRD_PARTY.md](THIRD_PARTY.md).
