<div align="center">

# template-macos-app

macOS 菜单栏应用的 GitHub 模板：SwiftUI、Swift 6、Sparkle 更新，从第一次提交起就能构建、测试和发布。

[![CI](https://github.com/ydongy/template-macos-app/actions/workflows/ci.yml/badge.svg)](https://github.com/ydongy/template-macos-app/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2026%2B-lightgrey.svg)](#环境要求)

[English](README.md) · **简体中文**

</div>

本仓库是一个 **GitHub template**。在 `scripts/init.sh` 给它起真正的名字之前，产品名为 `Template`，域名为 `example.com`。

## 功能特性

- SwiftUI + Swift 6 的菜单栏应用骨架，附带 Example 示例界面，覆盖加载中、已加载、空和失败四种状态。
- 业务逻辑放在本地 Swift package（`TemplateCore`），工程由 XcodeGen 生成，测试使用 Swift Testing。
- 基于 Sparkle 2 的应用内更新、九种语言的本地化，以及设计 token、token 页面和界面原型。
- 发布工具链：版本号管理、签名与公证脚本、密钥扫描，并都有测试。
- 初始化时二选一：开源（MIT）项目，或闭源产品骨架。

## 环境要求

- macOS 26.0 或更高版本。
- Xcode 27（首选；CI 优先选用它，runner 上没有时使用已安装的最新 Xcode）。
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)（`brew install xcodegen`）和 Python 3。

## 快速开始

1. 在 GitHub 上点击 **Use this template**，创建你自己的仓库。
2. clone 后运行 `scripts/init.sh <Name> <domain>`：

   ```bash
   scripts/init.sh Acme acme.com                       # 开源项目（MIT），默认
   scripts/init.sh Acme acme.com --license proprietary # 闭源产品骨架
   ```

3. 验证结果：

   ```bash
   xcodebuild test -project Acme.xcodeproj -scheme Acme -destination 'platform=macOS' \
     -testLanguage en -testRegion US CODE_SIGNING_ALLOWED=NO
   xcrun swift-format lint --strict --recursive Acme AcmeCore AcmeTests
   ```

4. 生成 Sparkle 密钥（`generate_keys --account <name>`），把公钥写入 `project.yml` 的 `SPARKLE_PUBLIC_KEY`，
   运行 `xcodegen generate`，然后把 Example 界面换成你的第一个真实界面。

脚本不会替你提交：请检查 `git status`，只提交你确认过的文件。

## 使用方法

### `scripts/init.sh` 选项

```text
scripts/init.sh <Name> <domain> [--license mit|proprietary] [--owner <github-user>] [--repo <name>] [--no-generate]
```

| 选项 | 说明 |
|---|---|
| `<Name>` | PascalCase 产品名（字母和数字，首字母大写），成为模块、target、scheme 和显示名称 |
| `<domain>` | 小写产品域名；bundle id 为 `<反转域名>.app`（`acme.com` 得到 `com.acme.app`），下载地址 `https://dl.<domain>`，支持邮箱 `support@<domain>` |
| `--license mit`（默认） | 开源项目，见下表 |
| `--license proprietary` | 闭源产品骨架，见下表 |
| `--owner <user>` | 用于 `CODEOWNERS` 和各处 URL 的 GitHub 用户或组织；省略时从 `git remote origin` 推断，推断不出则 `CODEOWNERS` 写入占位符 `* @<owner>`，需要你补上 |
| `--repo <name>` | 仓库名（默认为小写的产品名） |
| `--no-generate` | 结束时不运行 `xcodegen` |

### `mit` 与 `proprietary` 的区别

| | `--license mit` | `--license proprietary` |
|---|---|---|
| `LICENSE` | MIT | 服务条款，保留所有权利 |
| `README.md` 与 `README.zh-CN.md` | 开源 README，带 MIT 徽章和 CI 徽章 | 产品 README，带 proprietary 徽章和预发布状态徽章及状态说明，无 CI 徽章、Website 徽章、下载链接或邮箱，并附文档索引 |
| 共有文件 | `CONTRIBUTING.md`、`AGENTS.md`、`CLAUDE.md`、`CHANGELOG.md`、`CODEOWNERS`、`pr-title.yml`、Dependabot | 同样这些，措辞改为闭源版本 |
| `ci.yml` | 每个 Pull Request 都构建并测试 | Linux 轻量检查始终运行；macOS job 只在发布候选和手动触发时运行 |
| 发布 workflow | 无 | 上线前没有；按 `docs/launch.md` 从 `.template/launch/` 复制自包含的 `release.yml`（签名、公证、上传） |
| 额外文档 | 无 | `docs/spec.md`、`legal.md`、`website.md`、`releasing.md`、`launch.md`、`roadmap.md`、`docs/security/`、`CHANGELOG.zh.md` 及官网 changelog 工具 |
| AI 协作配置 | `AGENTS.md` | 另有 `.claude/` 和 `.codex/` |

骨架文件位于 `.template/oss/` 与 `.template/product/`。`init.sh` 把其中一份复制到工程上，把 `Template*` 重命名为 `<Name>*`，
改写名称、bundle id、URL 和 Sparkle 设置（两份 README 同样会被改写），重新生成 Xcode 工程，最后删除 `.template/`、
自身和 `scripts/test-init.sh`。生成项目的 `README.md` 与 `README.zh-CN.md` 会取代你正在读的这两份。详见 [.template/README.md](.template/README.md)。

### 生成后的目录

| 路径 | 作用 |
|---|---|
| `project.yml`、`Config/` | XcodeGen 定义、`Version.xcconfig`、Info.plist 键、`release.conf`（所有与产品相关的发布配置） |
| `<Name>/` | App target：`App/`（入口、语言、链接、更新器）、`UI/Example/`（示例界面）、`Resources/` |
| `<Name>Core/` | 本地 Swift package：`Domain/`、`Services/`、`Design/`（`DesignTokens`） |
| `<Name>Tests/` | Swift Testing：模型、链接、语言、bundle 和本地化测试 |
| `docs/`、`design/` | 设计语言、架构决策记录、token 页面和 Example 界面原型 |
| `scripts/` | `release.sh`、`release-credentials.sh`、`bump.sh`、`scan_secrets.py` 及其测试 |

## 开发

```bash
xcodegen generate
xcrun swift-format lint --strict --recursive Template TemplateCore TemplateTests
xcodebuild test -project Template.xcodeproj -scheme Template -destination 'platform=macOS' \
  -testLanguage en -testRegion US CODE_SIGNING_ALLOWED=NO
scripts/test-release.sh
scripts/test-init.sh    # 在临时副本上对两种 license 各跑一遍 init.sh（--full 会连闭源副本一起构建）
```

`Template` 和 `example.com` 是 `init.sh` 会替换的占位符，请勿在本仓库任何位置写入真实产品名。

## 参与贡献

请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。提交信息和 Pull Request 标题遵循
[Conventional Commits](https://www.conventionalcommits.org/)。

## 安全

请通过 GitHub 私下报告漏洞：**Security → Report a vulnerability**，或访问
<https://github.com/ydongy/template-macos-app/security/advisories/new>。

## 致谢

基于 [Sparkle](https://sparkle-project.org/) 与 [XcodeGen](https://github.com/yonaskolb/XcodeGen)，
详见 [THIRD_PARTY.md](THIRD_PARTY.md)。

## 许可证

[MIT](LICENSE)。
