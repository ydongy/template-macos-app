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
