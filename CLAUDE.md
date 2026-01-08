# CLAUDE.md

本文件为 Claude Code (claude.ai/code) 在此代码库中工作时提供指导。

@README.md - 项目介绍、功能说明、使用指南
@RELEASE_NOTES.md - 版本更新日志

## 项目概述

Mousecape 是一款免费的 macOS 光标管理器，使用私有 CoreGraphics API 来自定义系统光标。它由三个构建目标组成，协同工作以应用和持久化自定义光标主题（"cape"）。

**系统要求：** macOS Sequoia (15.0) 或更高版本

## 构建命令

在 Xcode 中打开 `Mousecape/Mousecape.xcodeproj`：

```bash
# 构建应用
xcodebuild -project Mousecape/Mousecape.xcodeproj -scheme Mousecape build

# 构建特定目标
xcodebuild -project Mousecape/Mousecape.xcodeproj -target mousecloak build
```

## 架构

### 三个构建目标

1. **Mousecape**（GUI 应用）- 使用 SwiftUI 界面的主 macOS 应用程序
   - 入口：`Mousecape/SwiftUI/MousecapeApp.swift`
   - 自适应设计：macOS 26+ 使用液态玻璃（Liquid Glass），macOS 15 使用 Material 背景

2. **mousecloak**（CLI 工具）- 用于应用 cape 的命令行工具
   - 入口：`Mousecape/mousecloak/main.m`
   - 命令：`--apply`、`--reset`、`--create`、`--dump`、`--scale`、`--convert`、`--export`、`--listen`
   - 使用 GBCli 进行参数解析

3. **com.sdmj76.mousecloakhelper**（LaunchAgent）- 后台守护进程
   - 入口：`Mousecape/mousecloakHelper/main.m`
   - 监听用户会话变化，在登录时重新应用光标

### 数据流

```
SwiftUI Views (AppState @Observable)
    ↓
Swift 包装器 (Cursor.swift, CursorLibrary.swift)
    ↓
ObjC 模型 (MCCursor, MCCursorLibrary)
    ↓
MCLibraryController
    ↓
私有 API (mousecloak/apply.m)
```

### 核心数据模型（Mousecape/Mousecape/src/models/）

- **MCCursor** - 单个光标，包含多个缩放比例表示（1x、2x、5x、10x）、动画帧、热点和持续时间
- **MCCursorLibrary** - Cape（光标主题），包含元数据和光标集合

### 私有 API 层（Mousecape/mousecloak/）

- **CGSInternal/** - 私有 CoreGraphics API 头文件（CGSCursor.h 是关键）
- **apply.m** - 通过 `CGSRegisterCursorWithImages()` 注册光标
- **backup.m/restore.m** - 备份和恢复原始系统光标
- **listen.m** - 辅助守护进程的会话变化监听器

### 使用的关键私有 API

```objc
CGSRegisterCursorWithImages()   // 注册自定义光标图像
CoreCursorUnregisterAll()       // 将所有光标重置为系统默认
CGSCopyRegisteredCursorImages() // 读取当前光标数据
```

### SwiftUI 架构（Mousecape/Mousecape/SwiftUI/）

单窗口设计，基于叠层的导航：

```
SwiftUI/
├── MousecapeApp.swift（入口）
├── Models/
│   ├── AppState.swift（@Observable 状态管理）
│   ├── AppEnums.swift
│   ├── Cursor.swift（MCCursor 包装器）
│   └── CursorLibrary.swift（MCCursorLibrary 包装器）
├── Views/
│   ├── MainView.swift（页面切换 + 工具栏）
│   ├── HomeView.swift（cape 列表 + 预览）
│   ├── SettingsView.swift
│   ├── EditOverlayView.swift（编辑时的叠层）
│   ├── CapePreviewPanel.swift
│   └── MousecapeCommands.swift（菜单命令）
├── Utilities/
│   ├── LocalizationManager.swift（多语言支持）
│   ├── WindowsCursorParser.swift
│   ├── WindowsCursorConverter.swift
│   ├── WindowsCursorMapping.swift
│   └── WindowsINFParser.swift
└── Helpers/
    ├── AnimatingCursorView.swift
    └── GlassEffectContainer.swift
```

状态管理通过 `@Observable @MainActor AppState` 单例实现，带有手动撤销/重做栈。

## 内存管理

**全 ARC 代码库：**
- Swift 文件：ARC（自动）
- Objective-C 文件：ARC（自动）

所有 mousecloak/ 目录下的 Objective-C 文件已于 2026-01 迁移至 ARC，不再使用手动内存管理（MRR）。

## Cape 文件格式

Cape 是二进制 plist 文件（`.cape` 扩展名），包含：
- 元数据：名称、作者、标识符、版本、hiDPI 标志
- 按标识符索引的光标字典（例如 `com.apple.coregraphics.Arrow`）
- 每个光标包含 100x、200x、500x、1000x 缩放比例的 PNG 数据表示

**Cape 库位置：** `~/Library/Application Support/Mousecape/capes/`

## Windows 光标转换

使用原生 Swift 实现，无需外部依赖：
- `WindowsCursorParser.swift` - 原生 Swift 解析器，支持 .cur/.ani 格式
- `WindowsCursorConverter.swift` - 转换器，将解析结果转为 Mousecape 格式
- `WindowsINFParser.swift` - 解析 Windows install.inf 文件，基于 `[Scheme.Reg]` 位置映射
- `WindowsCursorMapping.swift` - 文件名 fallback 映射（当无有效 INF 时使用）

### INF 解析逻辑

Windows 光标主题通过 `[Scheme.Reg]` 段定义光标位置顺序（固定 0-16 位），这是 Windows 注册表的标准格式：

| 位置 | Windows 光标 | macOS CursorType |
|-----|-------------|------------------|
| 0 | Normal Select | `.arrow`, `.arrowCtx` |
| 1 | Help Select | `.help` |
| 2 | Working in Background | `.wait` |
| 3 | Busy | `.busy` |
| 4 | Precision Select | `.crosshair` |
| 5 | Text Select | `.iBeam`, `.iBeamXOR` |
| 6 | Handwriting | `.open` |
| 7 | Unavailable | `.forbidden` |
| 8 | Vertical Resize | `.resizeNS`, `.windowNS` |
| 9 | Horizontal Resize | `.resizeWE`, `.windowEW` |
| 10 | Diagonal Resize 1 | `.windowNWSE` |
| 11 | Diagonal Resize 2 | `.windowNESW` |
| 12 | Move | `.move` |
| 13 | Alternate Select | `.alias` |
| 14 | Link Select | `.pointing`, `.link` |
| 15-16 | Location/Person | 无 macOS 对应 |

路径解析支持两种格式：
- `%10%\Cursors\%pointer%` - 从 `[Strings]` 段查找变量对应的文件名
- `%10%\Cursors\Normal.ani` - 直接使用文件名

## 外部依赖

- **GBCli**（mousecloak/vendor/）- 命令行参数解析
- 无外部框架 - Sparkle 已在 v1.0.0 中移除

## 特殊光标处理

在较新的 macOS 版本上，Arrow 光标有同义词：
- `com.apple.coregraphics.Arrow`
- `com.apple.coregraphics.ArrowCtx`

IBeam（文本光标）也有替代名称。守护进程会处理这些变体。

## 调试

- `MMLog()` 宏用于彩色控制台输出（定义在 mousecloak 中）
- 构建变体：Debug、Release

## CI/CD

项目使用 GitHub Actions 进行持续集成，配置文件位于 `.github/workflows/`。

## 版本号修改

修改版本号时需要更新以下位置：

1. **Xcode 项目配置**（主要位置，其他文件引用此值）
   - `Mousecape/Mousecape.xcodeproj/project.pbxproj`
   - 搜索 `MARKETING_VERSION`，共 4 处（Debug、Debug-Dev、Release、Release-Dev）

2. **主应用 Info.plist**
   - `Mousecape/Mousecape/Mousecape-Info.plist`
   - `CFBundleShortVersionString` 已设为 `$(MARKETING_VERSION)`，自动引用 Xcode 配置

3. **守护进程 Info.plist**
   - `Mousecape/mousecloakHelper/Info.plist`
   - `CFBundleShortVersionString` 需手动修改

4. **设置页面 fallback 版本号**
   - `Mousecape/Mousecape/SwiftUI/Views/SettingsView.swift`
   - 搜索 `Mousecape v`，修改 else 分支中的备用版本号
