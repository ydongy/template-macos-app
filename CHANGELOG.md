# Changelog

All notable changes to this template are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Changed
- The template is organised as an open-source repository: MIT license, self-contained CI, contributor guide.
- `scripts/init.sh` takes `--license mit|proprietary` (default `mit`). `mit` produces an open-source project;
  `proprietary` produces everything `mit` does plus the closed-source layer (proprietary terms, specification,
  legal, website, releasing, roadmap and security-review documents, Chinese changelog, a CI that runs macOS only
  for release candidates, a self-contained release workflow).
- The closed-source skeleton moved to `.template/product/`, the open-source one to `.template/oss/`.
- `ci.yml` selects the Xcode by major version (27) instead of a fixed point release.
- The skeletons no longer depend on shared workflows or an external documents check.
- Every generated `AGENTS.md` spells out the issue forms and the pull request body for agents that use `gh`, and
  states the red lines in full; `CONTRIBUTING.md` states that issues and pull requests may be in English or
  Simplified Chinese.
- The proprietary `LICENSE` opens with the copyright line and carries no template comment; the product README
  points security reports to private vulnerability reporting instead of a mailbox.
- `design/screenshots/` is ignored: screenshots of the running app go into pull request descriptions.
- `--license proprietary` generates a pre-release product: both READMEs carry a pre-release status badge and a
  status sentence linking the new `docs/launch.md` launch checklist, and name no website, download link or support
  mailbox. The release workflow is no longer installed; it is kept in `.template/launch/` and copied in at launch.
