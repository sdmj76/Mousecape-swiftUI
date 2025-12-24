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

---

## Views 文件结构详解

### 1. MainView.swift (128行)

主视图，包含页面切换器和工具栏。

```
MainView
├── @Environment: AppState, LocalizationManager
└── body: Group + .toolbar
    ├── Group (页面内容)
    │   ├── case .home → HomeView()
    │   └── case .settings → SettingsView()
    │
    └── .toolbar
        ├── ToolbarItem(.navigation) - 左侧
        │   └── Picker (segmented style)
        │       └── ForEach(AppPage.allCases)
        │           └── Text + .tag(page)
        │
        ├── ToolbarItem(.principal) - 中间
        │   └── Spacer() (推动右侧按钮靠右)
        │
        └── if currentPage == .home
            └── ToolbarItemGroup(.primaryAction) - 右侧
                ├── Button "plus" (New Cape)
                ├── Button "square.and.arrow.down" (Import)
                ├── Button "checkmark.circle" (Apply)
                ├── Button "pencil" (Edit)
                ├── Button "square.and.arrow.up" (Export)
                └── Button "trash" (Delete)

    └── .confirmationDialog (删除确认)
```

---

### 2. HomeView.swift (192行)

主页视图，包含 Cape 图标网格和预览面板。

```
HomeView
├── @Environment: AppState
└── body: NavigationSplitView
    ├── sidebar (左侧边栏, 200-280-400)
    │   ├── EmptyStateView (无 Cape 时)
    │   └── CapeIconGridView (有 Cape 时)
    │
    └── detail (右侧详情)
        ├── CapePreviewPanel (有选中 Cape)
        └── ContentUnavailableView (无选中)

EmptyStateView (44-66行)
├── @Environment: AppState
└── ContentUnavailableView
    ├── Label: "No Capes" + cursorarrow.slash
    ├── description: 提示文字
    └── actions: HStack
        ├── Button "New Cape" (.borderedProminent)
        └── Button "Import Cape" (.bordered)

CapeIconGridView (70-105行)
├── @Environment: AppState
├── columns: GridItem(.adaptive 80-100)
├── ScrollView > LazyVGrid
│   └── ForEach: CapeIconCell
└── handleDoubleClick():
    ├── .applyCape → 应用
    ├── .editCape → 编辑
    └── .doNothing → 无操作

CapeIconCell (109-184行)
├── 属性
│   ├── cape: CursorLibrary
│   ├── onSelect / onDoubleClick 回调
│   ├── @State: isHovered, lastClickTime
│   └── computed: isSelected, isApplied
│
└── body: VStack
    ├── ZStack (光标预览)
    │   ├── AnimatingCursorView (有光标)
    │   └── SF Symbol (无光标)
    │
    ├── HStack (名称+状态)
    │   ├── 绿点 "●" (已应用)
    │   └── Text(cape.name)
    │
    └── 修饰符
        ├── .glassEffect() (毛玻璃效果)
        ├── .overlay() (选中边框)
        ├── .scaleEffect() (悬停放大)
        ├── .onHover
        ├── .onTapGesture (单击/双击检测)
        └── .contextMenu → CapeContextMenu
```

---

### 3. SettingsView.swift (334行)

设置视图，左侧边栏导航 + 右侧内容。

```
SettingsView
├── @State: selectedCategory
├── @Environment: LocalizationManager
└── body: NavigationSplitView
    ├── sidebar (150-180-220)
    │   └── List(SettingsCategory.allCases)
    │       └── Label(title, systemImage: icon)
    │
    └── detail: settingsContent
        ├── case .general → GeneralSettingsView
        ├── case .appearance → AppearanceSettingsView
        ├── case .shortcuts → ShortcutsSettingsView
        └── case .advanced → AdvancedSettingsView

GeneralSettingsView (48-86行)
├── @AppStorage: launchAtLogin, applyLastCapeOnLaunch,
│                doubleClickAction, cursorScale
└── Form (.grouped)
    ├── Section "Startup"
    │   ├── Toggle "Launch at Login"
    │   └── Toggle "Apply Last Cape on Launch"
    ├── Section "Double-click Action"
    │   └── Picker (Apply/Edit/Do Nothing)
    └── Section "Cursor Scale"
        └── Slider (0.5x - 2.0x)

AppearanceSettingsView (90-136行)
├── @AppStorage: appearanceMode, showPreviewAnimations,
│                showAuthorInfo, previewGridColumns
└── Form (.grouped)
    ├── Section "Theme"
    │   └── Picker (System/Light/Dark) .radioGroup
    ├── Section "Language"
    │   └── Picker (AppLanguage.allCases) .radioGroup
    ├── Section "List Display"
    │   ├── Toggle "Show Cursor Preview Animations"
    │   └── Toggle "Show Cape Author Info"
    └── Section "Preview Panel"
        └── Picker "Preview Grid Columns"

ShortcutsSettingsView (140-170行)
├── @State: applyLastCapeShortcut, resetToDefaultShortcut
└── Form (.grouped)
    ├── Section "Global Shortcuts"
    │   ├── ShortcutRecorderView (Quick Apply)
    │   └── ShortcutRecorderView (Reset to Default)
    └── Section (说明文字)

ShortcutRecorderView (174-183行)
└── TextField (简化版快捷键录制)

AdvancedSettingsView (187-325行)
├── @AppStorage: debugLogging
├── @State: showResetConfirmation
├── @Environment: AppState, LocalizationManager
└── Form (.grouped)
    ├── HelperToolSettingsView (Helper 工具管理)
    ├── Section "Storage"
    │   ├── LabeledContent "Cape Folder"
    │   └── Buttons: Show in Finder, Change Location
    ├── Section "Debug"
    │   ├── Toggle "Enable Debug Logging"
    │   └── Button "Export Diagnostics..."
    ├── Section "Reset"
    │   └── Button "Restore Default Settings" + confirmationDialog
    └── Section "About"
        ├── LabeledContent: Version, System Requirements, Author
        └── Buttons: Check for Updates, GitHub, Report Issue
```

---

### 4. EditOverlayView.swift (711行)

编辑叠层视图，完整的光标编辑器。

```
EditOverlayView
├── 属性
│   ├── cape: CursorLibrary
│   ├── @Environment: AppState
│   └── @State: selectedCursor, showCapeInfo, showAddCursorSheet
│
└── body: NavigationSplitView
    ├── sidebar (180-220-280)
    │   └── CursorListView
    │
    └── detail
        ├── detailContent
        │   ├── CapeInfoView (showCapeInfo = true)
        │   ├── CursorDetailView (有选中光标)
        │   └── ContentUnavailableView (无选中)
        │
        └── .toolbar
            ├── ToolbarItem(.navigation)
            │   └── Button "chevron.left" (返回)
            ├── ToolbarItem(.principal)
            │   └── Text "Edit: {cape.name}"
            └── ToolbarItemGroup(.primaryAction)
                ├── Button "info.circle" (Cape Info)
                ├── Button "square.and.arrow.down" (Save)
                └── Button "checkmark.circle" (Apply)

CapeInfoView (108-212行) - Cape 元数据编辑器
├── @Bindable: cape
└── ScrollView > VStack
    ├── 元数据表单 (.glassEffect)
    │   ├── TextField: Name, Author, Version, Identifier
    │   ├── LabeledContent: Cursors count
    │   ├── Toggle: HiDPI
    │   └── LabeledContent: File path
    └── 光标预览网格 (.glassEffect)
        └── LazyVGrid > ForEach(cursors)

AddCursorSheet (216-276行) - 添加光标弹窗
├── 属性: cape, onAdd, selectedType
├── availableTypes: 过滤已存在的类型
└── VStack
    ├── List(availableTypes)
    └── HStack: Cancel / Add buttons

CursorListView (280-371行) - 光标列表
├── 属性: cape, selection, onAddCursor
├── @State: showDeleteConfirmation
└── List + .safeAreaInset(edge: .bottom)
    ├── ForEach → CursorListRow + contextMenu
    └── Bottom bar: Add/Remove/Duplicate buttons

CursorListRow (375-402行)
└── HStack
    ├── 预览缩略图 (32x32)
    └── VStack: displayName + frameCount

CursorDetailView (406-528行) - 光标详情编辑
├── @Bindable: cursor
├── @State: showHotspot, hotspotX/Y, frameCount, frameDuration
└── ScrollView > VStack
    ├── AnimatingCursorView (200高, 大预览)
    ├── Properties panel (.glassEffect)
    │   ├── Type, Identifier
    │   ├── Hotspot X/Y + Show toggle
    │   └── Animation: Frames / Duration
    └── Resolutions panel (.glassEffect)
        └── HStack: ForEach(CursorScale.allCases)
            └── ResolutionDropZone

ResolutionDropZone (532-630行) - 分辨率拖放区
├── 属性: scale, cursor, isTargeted, showFilePicker
└── VStack
    ├── Text(scale.displayName)
    └── ZStack
        ├── 有图像 → Image + 删除按钮
        └── 无图像 → plus.dashed 占位符
    └── 修饰符
        ├── .dropDestination(for: URL.self)
        └── .fileImporter

HelperToolSettingsView (636-702行) - Helper 工具设置
├── @State: isHelperInstalled, showInstallAlert, alertMessage
└── Section "Helper Tool"
    ├── HStack: 状态 + Install/Uninstall 按钮
    └── Text: 说明文字
    └── .alert (操作结果)
```

---

### 5. CapePreviewPanel.swift (129行)

Cape 预览面板，显示详情和光标网格。

```
CapePreviewPanel
├── 属性: cape
├── @Environment: AppState
├── computed: isApplied
└── body: VStack
    ├── Top: Cape info (.glassEffect)
    │   └── HStack
    │       ├── VStack: name + AppliedBadge + author
    │       └── Spacer
    │
    ├── Divider
    │
    ├── Middle: ScrollView
    │   └── CursorFlowGrid
    │
    ├── Divider
    │
    └── Bottom: cape.summary

AppliedBadge (66-74行)
└── Label "Applied" + checkmark.circle.fill
    └── .glassEffect(.regular.tint(.green), in: .capsule)

CursorFlowGrid (78-92行)
├── columns: GridItem(.adaptive 64-80)
└── LazyVGrid
    └── ForEach(cursors) → CursorPreviewCell

CursorPreviewCell (96-120行)
├── @State: isHovered
└── VStack
    ├── AnimatingCursorView (48x48)
    └── Text(displayName)
    └── 修饰符
        ├── .glassEffect (hover 效果)
        ├── .scaleEffect (hover 放大)
        └── .onHover
```

---

### 6. CapeContextMenu.swift (74行)

右键上下文菜单。

```
CapeContextMenu
├── 属性: cape
├── @Environment: AppState
├── computed: isApplied
└── body (Menu items)
    ├── Button "Apply" + checkmark.circle
    │   └── .disabled(isApplied)
    ├── Button "Edit" + square.and.pencil
    ├── Divider
    ├── Button "Export..." + square.and.arrow.up
    ├── Button "Show in Finder" + folder
    ├── Divider
    └── Button "Delete" (role: .destructive) + trash
```

---

### 7. MousecapeCommands.swift (139行)

系统菜单栏命令。

```
MousecapeCommands: Commands
├── @FocusedValue: selectedCapeBinding
├── computed: selectedCape
└── body: some Commands
    │
    ├── CommandGroup(replacing: .newItem) - File 菜单
    │   ├── Button "New Cape" ⌘N
    │   ├── Button "Import Cape..." ⌘I
    │   ├── Divider
    │   └── Button "Open Cape Folder"
    │
    ├── CommandGroup(replacing: .textEditing) { } - 移除编辑菜单
    ├── CommandGroup(replacing: .undoRedo) { }
    ├── CommandGroup(replacing: .pasteboard) { }
    │
    ├── CommandMenu("Cape") - Cape 菜单
    │   ├── Button "Apply" ⌘A
    │   ├── Button "Edit" ⌘E
    │   ├── Divider
    │   ├── Button "Export..." ⌘S
    │   ├── Button "Show in Finder"
    │   ├── Divider
    │   ├── Button "Reset to Default" ⌘R
    │   ├── Divider
    │   └── Button "Delete" ⌫
    │
    ├── CommandMenu("View") - View 菜单
    │   └── Button "Refresh" ⇧⌘R
    │
    └── CommandGroup(replacing: .help) - Help 菜单
        ├── Button "Mousecape Help"
        └── Button "Report an Issue"
```

---

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

## 测试

在 Xcode 中使用 Preview 功能测试各视图：

```swift
#Preview {
    HomeView()
        .environment(AppState.shared)
        .environment(LocalizationManager.shared)
}
```

## 许可证

与主项目相同
