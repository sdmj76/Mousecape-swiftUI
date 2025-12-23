# Mousecape SwiftUI 重构

本目录包含 Mousecape GUI 的 SwiftUI 重构代码，采用 macOS 26 Liquid Glass 设计语言。

## 目录结构

```
SwiftUI/
├── MousecapeApp.swift          # SwiftUI App 入口点
├── Models/
│   ├── AppEnums.swift          # 应用枚举定义
│   ├── AppState.swift          # 全局状态管理
│   ├── Cursor.swift            # MCCursor Swift 包装器
│   └── CursorLibrary.swift     # MCCursorLibrary Swift 包装器
├── Views/
│   ├── MainView.swift          # 主视图（页面切换器）
│   ├── HomeView.swift          # 主页视图（Cape 列表）
│   ├── CapePreviewPanel.swift  # 预览面板
│   ├── EditOverlayView.swift   # 编辑叠层视图
│   ├── SettingsView.swift      # 设置视图
│   ├── CapeContextMenu.swift   # 右键菜单
│   └── MousecapeCommands.swift # 系统菜单栏
├── Helpers/
│   ├── AnimatingCursorView.swift    # NSViewRepresentable 封装
│   └── GlassEffectContainer.swift   # Liquid Glass 容器
└── README.md
```

## Xcode 配置步骤

### 1. 添加 Swift 文件到项目

1. 在 Xcode 中打开 `Mousecape.xcodeproj`
2. 右键点击 `Mousecape` 目标 → Add Files to "Mousecape"
3. 选择整个 `SwiftUI` 文件夹，确保勾选：
   - ☑️ Copy items if needed (如果文件在项目外)
   - ☑️ Create groups
   - ☑️ Add to targets: Mousecape

### 2. 配置桥接头文件

1. 选择项目 → Mousecape target → Build Settings
2. 搜索 "Bridging Header"
3. 设置 `Objective-C Bridging Header` 为：
   ```
   Mousecape/Mousecape-Bridging-Header.h
   ```

### 3. 配置 Swift 版本

1. 在 Build Settings 中搜索 "Swift Language Version"
2. 设置为 `Swift 6` 或更高版本

### 4. 移除旧的 main.m 入口点

由于 SwiftUI 使用 `@main` 属性，需要：

1. 从 Compile Sources 中移除 `main.m`
2. 或者将 `main.m` 重命名为 `main.m.bak`

**注意**: 如果想保留 AppKit 入口点作为备选，可以：
- 保留 `main.m` 但注释掉内容
- 在 `MousecapeApp.swift` 中移除 `@main` 属性
- 使用条件编译切换

### 5. 更新 Info.plist

确保以下键值正确：

```xml
<key>LSApplicationCategoryType</key>
<string>public.app-category.utilities</string>

<key>NSPrincipalClass</key>
<string>NSApplication</string>
```

## 架构说明

### 单窗口架构

重构采用单窗口设计，所有界面通过叠层方式切换：

```
ContentView (根视图)
├── MainView (主页/设置切换)
│   ├── HomeView (Cape 列表 + 预览面板)
│   └── SettingsView (左侧边栏导航)
└── EditOverlayView (编辑界面，叠层覆盖)
```

### Liquid Glass 设计

所有工具栏按钮和控件采用 macOS 26 Liquid Glass 样式：

- **页面切换器**: `.glassEffect(.regular, in: .capsule)`
- **工具栏按钮**: `.glassEffect(.regular.interactive(), in: .circle)`
- **视图模式切换**: `.glassEffect(.regular, in: .capsule)`

### 数据流

```
AppState (Observable)
    ↓
SwiftUI Views
    ↓
Swift Wrapper (Cursor, CursorLibrary)
    ↓
ObjC Models (MCCursor, MCCursorLibrary)
    ↓
MCLibraryController
    ↓
Private API (mousecloak)
```

## 功能对照

| 原 AppKit | 新 SwiftUI | 状态 |
|-----------|------------|------|
| Library.xib | HomeView.swift | ✅ |
| Edit.xib | EditOverlayView.swift | ✅ |
| MCLibraryWindowController | MainView.swift | ✅ |
| MCEditWindowController | EditOverlayView.swift | ✅ |
| MCGeneralPreferencesController | SettingsView.swift | ✅ |
| MCCapeCellView | CapeRowView / CapeIconCell | ✅ |
| MMAnimatingImageView | AnimatingCursorView (wrapper) | ✅ |
| MainMenu.xib | MousecapeCommands.swift | ✅ |

## 待完成功能

- [ ] 拖放导入 Cape 文件
- [ ] 快捷键录入控件
- [ ] 登录时启动集成 (SMAppService)
- [ ] Sparkle 自动更新集成
- [ ] 光标添加/复制功能
- [ ] 热点编辑器

## 回滚说明

如需回滚到 AppKit 版本：

1. 从 Build Phases → Compile Sources 中移除所有 Swift 文件
2. 恢复 `main.m` 作为入口点
3. 移除桥接头文件设置

## 测试

在 Xcode 中使用 Preview 功能测试各视图：

```swift
#Preview {
    HomeView()
        .environment(AppState.shared)
}
```

## 许可证

与主项目相同
