<div align="center">

# Template

macOS 菜单栏小工具：用一份带状态的列表告诉你哪些正常、哪些需要看一眼，并自动保持最新。

[![CI](https://github.com/ydongy/template/actions/workflows/ci.yml/badge.svg)](https://github.com/ydongy/template/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2026%2B-lightgrey.svg)](#环境要求)
[![Website](https://img.shields.io/badge/website-example.com-informational.svg)](https://example.com)

[English](README.md) · **简体中文**

</div>

Template 让你一眼看清哪些没问题、哪些需要留意。当前是一份示例列表，请替换成你自己的应用。

## 功能特性

- **一目了然**：常驻菜单栏；面板里每个条目都有状态图标、详情和日期。
- **四种状态**：加载中、已加载、空和失败，每种都有清晰的提示和重试方式。
- **始终最新**：更新通过应用内的 Sparkle 到达，确认后才会安装。
- **九种语言**：英语、简体中文、繁体中文、日语、韩语、法语、德语、西班牙语和巴西葡萄牙语。
- **注重隐私**：无需账号，无遥测；唯一的网络请求是检查更新。

## 环境要求

- 运行：macOS 26.0 或更高版本。
- 构建：Xcode 27 和 [XcodeGen](https://github.com/yonaskolb/XcodeGen)（`brew install xcodegen`）。

## 快速开始

从 [Releases](https://github.com/ydongy/template/releases) 或 [example.com](https://example.com) 下载最新的 `.dmg`，
把 Template 拖进“应用程序”并打开。更新会在应用内提示，确认后安装。

## 开发

修改 `project.yml` 后运行 `xcodegen generate` 并提交 `Template.xcodeproj`，否则 CI 会失败。
版本号只存放在 `Config/Version.xcconfig`，用 `scripts/bump.sh <X.Y.Z>` 修改。

```bash
xcodegen generate
xcodebuild build -project Template.xcodeproj -scheme Template CODE_SIGNING_ALLOWED=NO
xcodebuild test -project Template.xcodeproj -scheme Template -destination 'platform=macOS' \
  -testLanguage en -testRegion US CODE_SIGNING_ALLOWED=NO
xcrun swift-format lint --strict --recursive Template TemplateCore TemplateTests
scripts/test-release.sh
```

| 路径 | 作用 |
|---|---|
| `Template/` | App target：入口、更新器、Example 界面、资源 |
| `TemplateCore/` | 本地 Swift package：领域模型、服务、设计 token |
| `TemplateTests/` | Swift Testing 测试 |
| `docs/`、`design/` | 设计语言、架构决策记录、界面原型 |
| `scripts/` | 发布、版本号和密钥扫描脚本 |

## 参与贡献

请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。提交信息和 Pull Request 标题遵循
[Conventional Commits](https://www.conventionalcommits.org/)。

## 安全

请通过 GitHub 私下报告漏洞：**Security → Report a vulnerability**，或访问
<https://github.com/ydongy/template/security/advisories/new>。

## 致谢

基于 [Sparkle](https://sparkle-project.org/) 与 [XcodeGen](https://github.com/yonaskolb/XcodeGen)，
详见 [THIRD_PARTY.md](THIRD_PARTY.md)。

## 许可证

[MIT](LICENSE)。
