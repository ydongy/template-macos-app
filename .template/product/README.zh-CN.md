<div align="center">

# Template

macOS 菜单栏小工具：用一份带状态的列表告诉你哪些正常、哪些需要看一眼，并自动保持最新。

[![License](https://img.shields.io/badge/license-proprietary-lightgrey.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2026%2B-lightgrey.svg)](#环境要求)
[![Website](https://img.shields.io/badge/website-example.com-informational.svg)](https://example.com)

[English](README.md) · **简体中文**

</div>

当前状态：1.0.0 筹备中。应用、测试和发布脚本已就绪；第一个真实界面、签名、公证和官网仍待完成。
详见 [docs/roadmap.md](docs/roadmap.md)。

## 功能特性

- **一目了然**：常驻菜单栏；面板里每个条目都有状态图标、详情和日期。
- **四种状态**：加载中、已加载、空和失败，每种都有清晰的提示和重试方式。
- **始终最新**：更新通过应用内到达，确认后才会安装。
- **九种语言**：英语、简体中文、繁体中文、日语、韩语、法语、德语、西班牙语和巴西葡萄牙语。
- **注重隐私**：无需账号，无遥测；唯一的网络请求是检查更新。

## 环境要求

- 运行：macOS 26.0 或更高版本。
- 构建：Xcode 27 和 [XcodeGen](https://github.com/yonaskolb/XcodeGen)（`brew install xcodegen`）。

## 快速开始

从 [example.com](https://example.com) 下载 `.dmg`，把 Template 拖进“应用程序”并打开。官网会给出每个下载文件的 SHA-256，
`shasum -a 256 <file>` 的结果必须与之一致。更新会在应用内提示，确认后安装。

## 开发

修改 `project.yml` 后运行 `xcodegen generate` 并提交 `Template.xcodeproj`，否则 CI 会失败。
版本号只存放在 `Config/Version.xcconfig`，用 `scripts/bump.sh <X.Y.Z>` 修改。

```bash
xcodegen generate

xcodebuild build -project Template.xcodeproj -scheme Template \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO

xcodebuild test -project Template.xcodeproj -scheme Template \
  -destination 'platform=macOS' -testLanguage en -testRegion US CODE_SIGNING_ALLOWED=NO

xcrun swift-format lint --strict --recursive Template TemplateCore TemplateTests
```

### 文档索引

| 文档 | 内容 |
|---|---|
| [docs/spec.md](docs/spec.md) | 要做什么 |
| [docs/design.md](docs/design.md) | 设计语言 |
| [docs/roadmap.md](docs/roadmap.md) | 后续计划 |
| [docs/legal.md](docs/legal.md) | 法律事实及必须与之一致的代码 |
| [docs/website.md](docs/website.md) | 应用对官网的依赖 |
| [docs/releasing.md](docs/releasing.md) | 发布流程 |
| [docs/security/](docs/security/README.md) | 每个版本一份安全审查 |
| [docs/adr/](docs/adr/README.md) | 架构决策 |
| [design/README.md](design/README.md) | 设计原型 |
| [CHANGELOG.md](CHANGELOG.md) | 变更记录 |
| [THIRD_PARTY.md](THIRD_PARTY.md) | 第三方软件 |
| [AGENTS.md](AGENTS.md) | 面向 AI 协作者的说明 |

## 参与贡献

提交范围、分支、changelog 和发布规则见 [CONTRIBUTING.md](CONTRIBUTING.md)。提交信息和 Pull Request 标题遵循
[Conventional Commits](https://www.conventionalcommits.org/)。

## 安全

请私下将漏洞报告至 support@example.com，不要公开提 issue。各版本的安全审查保存在
[docs/security/](docs/security/README.md)。

## 致谢

基于 [Sparkle](https://sparkle-project.org/) 与 [XcodeGen](https://github.com/yonaskolb/XcodeGen)，
详见 [THIRD_PARTY.md](THIRD_PARTY.md)。

## 许可证

专有软件，保留所有权利。[LICENSE](LICENSE) 是服务条款与许可协议，文本与
[example.com/terms](https://example.com/terms) 一致。
