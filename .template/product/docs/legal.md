<!-- template: legal.md v1 -->
# Legal pages: one source per fact

## Where each thing lives

| Thing | Where |
|---|---|
| Terms of service | `LICENSE` (English), published at `https://example.com/terms` |
| Privacy policy | `https://example.com/privacy` |
| Refund policy | `https://example.com/refund` |
| Support address | `support@example.com`, the same in `LICENSE`, `SECURITY.md` and the website footer |

The app only links to the website pages (`ProductLinks`); it does not embed or duplicate them. The legal pages of the other eight languages open with a notice that the English text is the reference. The wording rules are in the ydongy handbook (`handbook/guides/legal.md`).

## Facts that must match the code

| Fact | Code | Website key | Check |
|---|---|---|---|
| The app checks for updates once a day and when asked; the request carries the app name and version, no system profile | `SUScheduledCheckInterval` (86400), `SUEnableSystemProfiling` (false) in `Config/Template-Info.plist`; `AppBundleTests` | `terms.sections[6]`, `privacy.sections[2]` | `AppBundleTests`, review |
| The updater is disabled in a build without a public key, so such a build never checks | `AppUpdater.isConfigured(publicKey:)`, `SPARKLE_PUBLIC_KEY` in `project.yml` | `privacy.sections[2]` | `AppBundleTests` |
| A new version is installed only after the user confirms, and only if its signature is valid | Sparkle standard user driver, `SUPublicEDKey` | `terms.sections[6]` | review |
| The update feed is `https://dl.example.com/appcast.xml` | `SPARKLE_FEED_URL` in `project.yml`, `DOWNLOADS_URL` in `Config/release.conf` | `terms.sections[6]` | `AppBundleTests`, `scripts/release.sh --check` |
| The app reads one file in its own Application Support folder and sends nothing from it | `LiveExampleSource.defaultFileURL` | `privacy.sections[0]`, `terms.sections[4]` | `LiveExampleSourceTests` |
| The app holds no credential and no license key | No Keychain code in the baseline | `privacy.sections[3]`, `terms.sections[4]` | review |
| The app contacts no licensing service | No licensing code in the baseline | `terms.sections[3]` | review |
| Dodo Payments is the merchant of record | Not in code; the payment is on the website | `terms.sections[7]` | review |
| Refunds are available within 14 days of buying | The Dodo process; not in code | `refund.sections[0]` | `check_facts.py` |

## Refund policy

A buyer can ask for a full refund within 14 days of buying, without giving a reason, by email to `support@example.com` from the address used for the purchase, with the payment ID if available. Dodo Payments issues the refund to the original payment method; banks usually take 3 to 5 business days to show it. Once refunded, a license key stops working and the app goes back to the free plan. The baseline has no paid plan, so the policy applies from the release that adds one. The policy does not affect consumer rights under the law. The website text (`refund.sections`) derives from this paragraph.
