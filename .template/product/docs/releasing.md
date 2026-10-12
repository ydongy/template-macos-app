# Releasing Template

How a Template release is made, what it needs and what to do when one goes wrong. Contribution rules (scopes,
branches, changelog bullets) are in [CONTRIBUTING.md](../CONTRIBUTING.md).

## Version

`Config/Version.xcconfig` holds `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`; only `scripts/bump.sh <X.Y.Z>`
edits them. It also turns `## [Unreleased]` of `CHANGELOG.md` and `CHANGELOG.zh.md` into the new version's section.

## Releasing

1. Everything for the version is on `main`, the security review `docs/security/<version>-review.md` is written and
   its findings are closed or accepted (see [security/README.md](security/README.md)).
2. `scripts/bump.sh <X.Y.Z>` on a branch; open the pull request. A pull request that changes
   `Config/Version.xcconfig` runs the macOS job of `ci.yml` (format, build, tests).
3. Merging that pull request IS the decision to publish. `.github/workflows/release.yml` starts on the push to
   `main` that changed `Config/Version.xcconfig`:
   - `verify` (Linux): script syntax, `scripts/test_website_changelog.py`, and the check that both changelogs have
     a section for the version.
   - `release` (macOS, `release` environment): `scripts/test-release.sh`, then signs, notarizes and publishes the
     dmg, `appcast.xml` and `latest.json` to the downloads bucket with `scripts/release.sh --publish`.
   - `finish` (Linux): the annotated tag `vX.Y.Z` on the built commit and the GitHub Release with the changelog
     section as notes.
4. Add the version to the website's changelog page:
   `scripts/website-changelog.py --version <X.Y.Z> --website-dir <clone of the website repository> --open-pr`
   (dry run without `--open-pr`). The website pull request is reviewed and merged by a person.

By hand (Actions > Release > Run workflow) the workflow is a rehearsal: it builds, signs and notarizes the chosen
ref and uploads nothing. `publish` works only on `main`. A release can also be made on a Mac with
`scripts/release.sh --publish`; credentials come from the login keychain (`scripts/release-credentials.sh set`).

## Release workflow setup

`release.yml` calls no shared workflow; everything is in the repository.

- **Environment `release`** (Settings > Environments): add a deployment branch policy that allows only `main`, so
  a workflow of another branch never sees the secrets. (Required reviewers on a private repository need a paid
  plan; here the merge of the version bump is the decision.)
- **Secrets of the `release` environment** (values are never printed; the signing certificate lives in a temporary
  keychain that is deleted when the job ends):

| Secret | Content |
|---|---|
| `DEVELOPER_ID_P12_BASE64`, `DEVELOPER_ID_P12_PASSWORD` | Developer ID Application certificate, base64 of the `.p12`, and its password |
| `NOTARY_KEY_P8_BASE64`, `NOTARY_KEY_ID`, `NOTARY_ISSUER_ID` | App Store Connect API key for `notarytool` |
| `SPARKLE_PRIVATE_KEY` | EdDSA key exported with `generate_keys -x` (account in `Config/release.conf`) |
| `R2_ENDPOINT`, `R2_BUCKET`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY` | The downloads bucket; a token with write access to that bucket only |

- Xcode: the app is built with Xcode 27. `release.yml` and the macOS job of `ci.yml` select the newest hosted
  Xcode 27 and stop with a clear message when the runner image has none; then release with `scripts/release.sh` on
  a Mac until the image has it.

## When a release is wrong

- If `release` failed before the upload, fix and run the workflow again (nothing was published, no tag exists).
- If it was published and is wrong, do not announce it. Publish a fixed version: bump, merge, release. To pull a
  broken build from users at once, restore the previous `appcast.xml` and `latest.json` in the downloads bucket
  (the installer files stay); Sparkle then offers nothing newer than the previous version.
- A tag or GitHub Release made by mistake is deleted by the maintainer; the workflow never moves a tag.
- A leaked credential is rotated first (certificate, API key, Sparkle key, R2 token), then the secret is replaced.
