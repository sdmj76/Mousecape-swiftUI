# CLAUDE.md

本文件为 Claude Code (claude.ai/code) 在此代码库中工作时提供指导。

## 项目概述

Mousecape 是一款免费的 macOS（10.8+）光标管理器，使用私有 CoreGraphics API 来自定义系统光标。它由三个主要组件组成，协同工作以应用和持久化自定义光标主题（"cape"）。

## 构建命令

在 Xcode 中打开 `Mousecape/Mousecape.xcodeproj` 进行构建：

```bash
# 构建所有目标
xcodebuild -project Mousecape/Mousecape.xcodeproj -scheme Mousecape build

# 构建特定目标
xcodebuild -project Mousecape/Mousecape.xcodeproj -target Mousecape build
xcodebuild -project Mousecape/Mousecape.xcodeproj -target mousecloak build
```

## 架构

### 三个构建目标

1. **Mousecape**（GUI 应用）- 用于管理光标库的主 macOS 应用程序
   - 入口：`Mousecape/Mousecape/main.m` 和 `MCAppDelegate`
   - 使用 Cocoa/AppKit 和基于 XIB 的 UI

2. **mousecloak**（CLI 工具）- 用于应用 cape 的命令行工具
   - 入口：`Mousecape/mousecloak/main.m`
   - 命令：`--apply`、`--reset`、`--create`、`--dump`、`--scale`、`--convert`、`--export`
   - 使用 GBCli 进行参数解析

3. **com.alexzielenski.mousecloakhelper**（LaunchAgent）- 后台守护进程
   - 入口：`Mousecape/mousecloakHelper/main.m`
   - 监听用户会话变化以重新应用光标

### 核心数据模型（位于 Mousecape/Mousecape/src/）

- **MCCursor** - 单个光标，包含多个缩放比例表示（1x、2x、5x、10x）、动画帧、热点和持续时间
- **MCCursorLibrary** - 光标集合（即 "cape"），包含元数据（名称、作者、标识符、版本）
- **MCLibraryController** - 管理 cape 库，处理导入/导出/应用操作

### 私有 API 层（位于 Mousecape/mousecloak/）

- **CGSInternal/** - 私有 CoreGraphics API 的头文件（CGSCursor.h 是关键）
- **apply.m** - 通过 `CGSRegisterCursorWithImages()` 注册自定义光标
- **backup.m/restore.m** - 备份和恢复原始系统光标
- **listen.m** - 用于辅助守护进程的会话变化监听器
- **scale.m** - 光标缩放操作

### 使用的关键私有 API

```objc
CGSRegisterCursorWithImages()  // 注册自定义光标图像
CoreCursorUnregisterAll()       // 重置所有光标
CGSCopyRegisteredCursorImages() // 读取当前光标数据
```

### 外部依赖（已打包）

- **Sparkle** - 自动更新框架（位于 Mousecape/Mousecape/external/Sparkle/）
- **MASPreferences** - 偏好设置窗口控制器
- **GBCli** - 命令行参数解析器（位于 mousecloak/vendor/）

## Cape 文件格式

Cape 是 plist 文件（`.cape` 扩展名），包含：
- 元数据：名称、作者、标识符、版本
- 按标识符索引的光标字典（例如 `com.apple.coregraphics.Arrow`）
- 每个光标包含不同缩放比例的 PNG 图像数据表示

## 内存管理

部分代码使用手动 retain/release（MRR），通过 `-fno-objc-arc` 编译器标志指示。修改代码前请检查 project.pbxproj 以确定哪些文件使用 ARC 或 MRR。
