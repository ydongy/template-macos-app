# .template

Skeletons that `scripts/init.sh` installs over the tree, chosen by `--license`. Nothing here is part of the
template itself; `init.sh` deletes this directory.

| Directory | Installed by | Contents |
|---|---|---|
| `oss/` | `--license mit` (default) | Open-source `README.md` and `README.zh-CN.md`, `AGENTS.md`, `CHANGELOG.md` for the new product. `LICENSE` (MIT), `CONTRIBUTING.md`, `CLAUDE.md`, `.editorconfig`, `ci.yml`, `pr-title.yml` and Dependabot config are the files already at the template root; `CODEOWNERS` is generated from `--owner` or the git remote. |
| `product/` | `--license proprietary` | The closed-source layer on top of everything `oss/` and the template root provide (MIT-only files are replaced): proprietary `LICENSE` (terms of service), `CONTRIBUTING.md`, `README.md` and `README.zh-CN.md`, `AGENTS.md`, `CHANGELOG.md`/`CHANGELOG.zh.md`, `docs/` (specification, legal, roadmap, website, releasing, security reviews), `design/README.md`, `scripts/website-changelog.py` and its test, `.claude/`, `.codex/`, `.github/workflows/ci.yml` (macOS job only for release candidates) and a self-contained `release.yml`. |

How it is applied: the chosen directory is copied over the working tree first, then every file is renamed and
rewritten (`Template` to the product name, `example.com` to the domain, and so on). Both skeletons carry `README.md` (English) and `README.zh-CN.md` (Simplified Chinese); they replace the template's own pair, and the same rewrite applies to both. `CODEOWNERS` is generated in both modes.

Placeholders are the same as in the rest of this repository: `Template`, `templatecore`, `example.com`,
`com.example.template`, `https://github.com/ydongy/template`. Do not write a real product name here.
