# .template

Skeletons that `scripts/init.sh` installs over the tree, chosen by `--license`. Nothing here is part of the
template itself; `init.sh` deletes this directory.

| Directory | Installed by | Contents |
|---|---|---|
| `oss/` | `--license mit` (default) | Open-source `README.md`, `AGENTS.md`, `CHANGELOG.md` for the new product. `LICENSE` (MIT), `CONTRIBUTING.md`, `CLAUDE.md`, `.editorconfig`, `ci.yml`, `pr-title.yml` and Dependabot config are the files already at the template root; `CODEOWNERS` is generated from `--owner` or the git remote. |
| `product/` | `--license proprietary` | Closed-source product skeleton: proprietary `LICENSE` (terms of service), `README.md`, `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `CHANGELOG.md`/`CHANGELOG.zh.md`, `SECURITY.md`, `THIRD_PARTY.md`, `docs/` (specification, legal, roadmap, website, process, milestones, ADRs, design language), `design/README.md`, `.docs-check.json`, `.repo-type`, `.claude/`, `.codex/`, `.github/` (shared-workflow callers for CI, docs check and release, Copilot instructions). |

How it is applied: the chosen directory is copied over the working tree first, then every file is renamed and
rewritten (`Template` to the product name, `example.com` to the domain, and so on). In `proprietary` mode the
open-source-only files (`CONTRIBUTING.md`, `pr-title.yml`, `CODEOWNERS`) are removed.

Placeholders are the same as in the rest of the template: `Template`, `templatecore`, `example.com`,
`com.example.template`, `https://github.com/ydongy/template`. Do not write a real product name here.
