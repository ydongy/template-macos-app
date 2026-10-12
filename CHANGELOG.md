# Changelog

All notable changes to this template are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Changed
- The template is organised as an open-source repository: MIT license, self-contained CI, contributor guide.
- `scripts/init.sh` takes `--license mit|proprietary` (default `mit`). `mit` produces an open-source project;
  `proprietary` produces the closed-source product skeleton (specification, legal, roadmap, website and process
  documents, proprietary terms, shared-workflow callers).
- The closed-source skeleton moved to `.template/product/`, the open-source one to `.template/oss/`.
