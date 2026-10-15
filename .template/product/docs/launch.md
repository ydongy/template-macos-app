# Launch checklist

Template is pre-release: the app builds and its tests pass, but there is no domain, mailbox, download host or
release credentials yet, and the repository has no release workflow. This file is the single source of truth for
what remains. Check an item off only after its verification passes; the launch pull request links this file.

## Domain and site

- [ ] Register `example.com` and point it at the product website. Verify: `https://example.com/` loads over HTTPS.
- [ ] Publish the pages listed in [website.md](website.md#pages) (`/`, `/terms`, `/privacy`, `/refund`,
      `/changelog`) in every language. Verify: each URL returns 200 and matches its source of truth.

## Mail

- [ ] Create `support@example.com` ([legal.md](legal.md)). Verify: a test message arrives and a reply is delivered.

## Downloads and updates

- [ ] Create the downloads bucket behind `https://dl.example.com`, with CORS from `https://example.com`
      ([website.md](website.md#downloads-and-feeds)). Verify: a test file uploaded to the bucket is served over HTTPS.
- [ ] Generate the Sparkle key pair (`generate_keys --account <account in Config/release.conf>`), put the public key
      in `SPARKLE_PUBLIC_KEY` in `project.yml`, run `xcodegen generate`, keep the private key in the keychain with an
      offline backup. Verify: `AppBundleTests` pass and a development build reports the updater as configured.

## Signing

- [ ] Developer ID Application certificate and an App Store Connect API key for notarization; store them locally
      with `scripts/release-credentials.sh set`. Verify: `scripts/release.sh --check` passes and `scripts/release.sh`
      (without `--publish`) produces a signed, notarized dmg that `spctl -a -vv -t install` accepts.

## Legal and content

- [ ] Rewrite `LICENSE` (terms), [legal.md](legal.md) (privacy, refund, support) and the facts that must match the
      code for the real product. Verify: every row of the facts table in `legal.md` is checked against the code.
- [ ] Write the security review `docs/security/<version>-review.md` for the first version
      ([security/README.md](security/README.md)). Verify: its findings are closed or accepted.

## Places that depend on the domain

Each of these already names `example.com`; confirm it is the real address before launch.

- [ ] `project.yml`: `SPARKLE_FEED_URL` (`https://dl.example.com/appcast.xml`), read by `SUFeedURL` in
      `Config/Template-Info.plist`.
- [ ] `Config/release.conf`: `PRODUCT_DOMAIN`, `SITE_URL`, `DOWNLOADS_URL`.
- [ ] `Template/App/ProductLinks.swift` (website and legal page links) and `TemplateTests/ProductLinksTests.swift`.
- [ ] `LICENSE`: the terms and refund URLs, the downloads host, the support address.
- [ ] [legal.md](legal.md): terms, privacy and refund URLs, support address, update feed.
- [ ] [website.md](website.md): pages, downloads host and CORS origin.
- [ ] [spec.md](spec.md#updates): the update feed.

## Launch

- [ ] Release workflow: copy `.template/launch/.github/workflows/release.yml` from the macOS app template this
      repository was created from to `.github/workflows/release.yml`, unchanged (it reads every product value from
      `Config/release.conf`). Verify: `actionlint` passes and the workflow appears under Actions.
- [ ] Create the `release` environment (Settings > Environments) with a deployment branch policy that allows only
      `main`. Verify: the environment page lists `main` as the only allowed branch.
- [ ] Set the secrets of the `release` environment listed in [releasing.md](releasing.md#release-workflow-setup).
      Verify: every name in that table is present in the environment, and no value appears in a log.
- [ ] Rehearsal: Actions > Release > Run workflow on `main`, without publishing. Verify: the run builds, signs and
      notarizes, and nothing is uploaded to the downloads bucket.
- [ ] One pull request titled `chore(release): launch <version>` removes the pre-release state: the status badge and
      status sentence in `README.md` and `README.zh-CN.md`; it adds the Website badge, the download instructions
      (link to `https://example.com` and the SHA-256 check) and the terms link back to both READMEs, and states in
      `AGENTS.md` and `CONTRIBUTING.md` that merging a version bump publishes a release. It links this file.
- [ ] The version bump pull request (`scripts/bump.sh <version>`) publishes the release
      ([releasing.md](releasing.md#releasing)). Verify: the `release` and `finish` jobs pass, the tag `v<version>` and
      the GitHub Release exist.
- [ ] Add the version to the website's changelog page with `scripts/website-changelog.py`. Verify: `/changelog`
      shows it.

## After launch

- [ ] Download the dmg from `https://example.com`, check its SHA-256 with `shasum -a 256`, drag it to Applications
      and open it on a clean Mac. Verify: Gatekeeper opens it without a warning.
- [ ] Update path: install a signed build with a lower build number and check for updates. Verify: Sparkle offers
      the new version and installs it after confirmation.
- [ ] `https://dl.example.com/appcast.xml` and `latest.json` name the new version; the download section of the site
      shows it.
- [ ] Archive this file: keep it, add the launch date at the top and mark it as done.
