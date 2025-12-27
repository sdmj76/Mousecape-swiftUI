**[English](#english) | [中文](#中文)**

<a id="english"></a>

## English

> **Important:** This version requires **macOS Tahoe (26)** or later. Earlier versions of macOS are not supported.

### UI

- Completely rebuilt the interface using **SwiftUI**, fully embracing the new Liquid Glass design language
- Added **enlarged cursor preview** on the home screen for better visibility
- Replaced TabView with **page-based navigation** and improved toolbar layout
- Full **Dark Mode** support with automatic system appearance switching
- Added **localization support** with Chinese language option

### Features

- **Windows cursor import** (Premium version only): One-click import from Windows cursor files
  - Supports `.cur` (static) and `.ani` (animated) formats
  - Automatically detects frame count and imports hotspot information

>*Premium version is free, but has a larger file size due to bundled Python libraries*

- Unified cursor size to **64px × 64px** for consistency
- Updated CoreGraphics API for **macOS Tahoe** compatibility
- Improved helper daemon with better session change handling

### Other

- Removed Sparkle update framework (updates now via GitHub Releases)
- Cleaned up legacy Objective-C code and unused assets
- Fixed multiple UI display and preview issues
- Fixed edit function stability
- Security vulnerability fixes

<a id="中文"></a>

## 中文

> **重要提示：** 此版本需要 **macOS Tahoe (26)** 或更高版本。不支持更早的 macOS 版本。

### 界面

- 使用 **SwiftUI** 完全重写界面，全面适配全新的液态玻璃设计语言
- 主页新增**放大光标预览**功能，预览更清晰
- 使用**分页式导航**替代 TabView，优化工具栏布局
- 完整支持**深色模式**，自动跟随系统外观切换
- 新增**本地化支持**，支持中文界面

### 功能

- **Windows 光标导入**（仅限 Premium 版本）：一键从 Windows 光标文件导入
  - 支持 `.cur`（静态）和 `.ani`（动态）格式
  - 自动识别帧数并导入热点信息

> *Premium 版本免费，但因内置 Python 库导致文件体积较大*

- 光标尺寸统一为 **64px × 64px**，保持一致性
- 更新 CoreGraphics API 以支持 **macOS Tahoe**
- 改进守护进程，优化会话变化处理

### 其他

- 移除 Sparkle 更新框架（现通过 GitHub Releases 更新）
- 清理遗留的 Objective-C 代码和未使用的资源
- 修复多个界面显示和预览问题
- 修复编辑功能稳定性问题
- 安全漏洞修复

---

## Credits | 致谢

- **Original Author | 原作者:** Alex Zielenski (2013-2025)
- **SwiftUI Redesign | SwiftUI 重构:** sdmj76 (2025)
- **Coding Assistant | 编程协助:** Claude Code (Opus)
