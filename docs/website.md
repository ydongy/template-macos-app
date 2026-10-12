<!-- template: website.md v1 -->
# Website

The website is a separate repository, deployed as Cloudflare Workers static assets in nine languages. This file lists what the app depends on; the app links to the pages in the visitor's language (`ProductLinks`), and every page has exactly one address.

## Pages

| URL | Content | Source of truth |
|---|---|---|
| `/` | Home: features, `#download` (current version and checksum) | Website copy; version from `latest.json` |
| `/terms` | Terms of Service, also the license agreement | `LICENSE` in this repository, translated |
| `/privacy` | Privacy Policy | Website copy; what is sent to whom, from [docs/legal.md](legal.md#facts-that-must-match-the-code) |
| `/refund` | Refund Policy | Website copy; the rules in [docs/legal.md](legal.md#refund-policy) |
| `/changelog` | Release history | Website `changelog.json`, written by `scripts/website-changelog.py` from `CHANGELOG.md` and `CHANGELOG.zh.md` |

English has no path prefix; the other languages use `/zh`, `/zh-hant`, `/ja`, `/ko`, `/fr`, `/de`, `/es`, `/pt` (`ProductLinks.languagePath`). These addresses stay stable.

## Downloads and feeds

| File | Written by | Read by |
|---|---|---|
| `dl.example.com/Template-<version>.dmg` and `.sha256` | `scripts/release.sh --publish` | Website download button, users |
| `dl.example.com/appcast.xml` | `scripts/release.sh --publish` | The app (Sparkle), `SUFeedURL` in `Config/Template-Info.plist` |
| `dl.example.com/latest.json` (`version`, `build`, `url`, `sha256`, `publishedAt`, `minimumOS`) | `scripts/release.sh --publish` | Website `public/download.js` (the bucket allows CORS from `https://example.com`) |

The upload order is installer, then `appcast.xml`, then `latest.json`, so no feed ever names a version whose installer is missing. The app never reads `latest.json`. The release history is a website page, not part of the appcast.

## Download section copy

Headline "Download Template {version}", with the line "Version {version} · macOS {os} or later" under the button and the SHA-256 below it. Install: open the dmg, drag Template into Applications and start it; it appears in the menu bar. Verify: `shasum -a 256 Template-<version>.dmg` must match the checksum shown. If `latest.json` cannot be read, the page says the download is not available right now and to try again later. The words are website copy; the app only depends on the structure above.
