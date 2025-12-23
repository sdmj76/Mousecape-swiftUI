//
//  LocalizationManager.swift
//  Mousecape
//
//  Manages app localization with runtime language switching
//

import SwiftUI

// MARK: - Supported Languages

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case chinese = "zh-Hans"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:
            // 根据当前有效语言显示
            let preferredLanguage = Locale.preferredLanguages.first ?? "en"
            if preferredLanguage.hasPrefix("zh") {
                return "跟随系统"
            }
            return "System"
        case .english: return "English"
        case .chinese: return "中文"
        }
    }

    /// 获取本地化的显示名称
    func localizedDisplayName(for effectiveLanguage: AppLanguage) -> String {
        switch self {
        case .system:
            return effectiveLanguage == .chinese ? "跟随系统" : "System"
        case .english: return "English"
        case .chinese: return "中文"
        }
    }
}

// MARK: - Localization Strings (Global to avoid @MainActor static initialization issues)

private let localizationStrings: [AppLanguage: [String: String]] = [
    .english: [
        // Navigation
        "Home": "Home",
        "Settings": "Settings",

        // Settings Categories
        "General": "General",
        "Appearance": "Appearance",
        "Shortcuts": "Shortcuts",
        "Advanced": "Advanced",

        // General Settings
        "Startup": "Startup",
        "Launch at Login": "Launch at Login",
        "Apply Last Cape on Launch": "Apply Last Cape on Launch",
        "Double-click Action": "Double-click Action",
        "When double-clicking a Cape": "When double-clicking a Cape",
        "Apply Cape": "Apply Cape",
        "Edit Cape": "Edit Cape",
        "Do Nothing": "Do Nothing",
        "Cursor Scale": "Cursor Scale",
        "Global Scale:": "Global Scale:",

        // Appearance Settings
        "Theme": "Theme",
        "System": "System",
        "Light": "Light",
        "Dark": "Dark",
        "Language": "Language",
        "List Display": "List Display",
        "Show Cursor Preview Animations": "Show Cursor Preview Animations",
        "Show Cape Author Info": "Show Cape Author Info",
        "Preview Panel": "Preview Panel",
        "Preview Grid Columns": "Preview Grid Columns",
        "Auto (based on window size)": "Auto (based on window size)",
        "columns": "columns",

        // Shortcuts Settings
        "Global Shortcuts": "Global Shortcuts",
        "Quick Apply Last Cape": "Quick Apply Last Cape",
        "Reset to Default Cursor": "Reset to Default Cursor",
        "These shortcuts work in any application.": "These shortcuts work in any application.",

        // Advanced Settings
        "Helper Tool": "Helper Tool",
        "Mousecape Helper": "Mousecape Helper",
        "Installed and running": "Installed and running",
        "Not installed": "Not installed",
        "Install": "Install",
        "Uninstall": "Uninstall",
        "The helper tool ensures cursors persist after logout/login and system updates.": "The helper tool ensures cursors persist after logout/login and system updates.",
        "Storage": "Storage",
        "Cape Folder": "Cape Folder",
        "Show in Finder": "Show in Finder",
        "Change Location...": "Change Location...",
        "Debug": "Debug",
        "Enable Debug Logging": "Enable Debug Logging",
        "Export Diagnostics...": "Export Diagnostics...",
        "Reset": "Reset",
        "Restore Default Settings": "Restore Default Settings",
        "Cancel": "Cancel",
        "This will reset all settings to their default values. This action cannot be undone.": "This will reset all settings to their default values. This action cannot be undone.",
        "About": "About",
        "Version": "Version",
        "System Requirements": "System Requirements",
        "Author": "Author",
        "Check for Updates": "Check for Updates",
        "Report Issue": "Report Issue",

        // Home View
        "No Capes": "No Capes",
        "Create a new cape or import an existing one to get started.": "Create a new cape or import an existing one to get started.",
        "New Cape": "New Cape",
        "Import Cape": "Import Cape",
        "Select a Cape": "Select a Cape",
        "Choose a cape from the list to preview": "Choose a cape from the list to preview",

        // Toolbar
        "Export Cape": "Export Cape",
        "Delete Cape": "Delete Cape",

        // Context Menu
        "Apply": "Apply",
        "Edit": "Edit",
        "Export...": "Export...",
        "Delete": "Delete",

        // Edit View
        "Back": "Back",
        "Save": "Save",
        "Cape Info": "Cape Info",
        "Cape Information": "Cape Information",
        "Name": "Name",
        "Identifier": "Identifier",
        "Cursors": "Cursors",
        "HiDPI": "HiDPI",
        "File": "File",
        "Select a Cursor": "Select a Cursor",
        "Choose a cursor from the list to edit": "Choose a cursor from the list to edit",
        "Add Cursor": "Add Cursor",
        "All Cursor Types Added": "All Cursor Types Added",
        "This cape already contains all standard cursor types.": "This cape already contains all standard cursor types.",
        "Add": "Add",
        "Properties": "Properties",
        "Type": "Type",
        "Hotspot": "Hotspot",
        "Show": "Show",
        "Animation": "Animation",
        "Frames:": "Frames:",
        "Duration:": "Duration:",
        "Resolutions": "Resolutions",
        "Drag images to add": "Drag images to add",

        // Dialogs
        "Are you sure you want to delete": "Are you sure you want to delete",
        "This action cannot be undone.": "This action cannot be undone.",
        "Success": "Success",
        "Error": "Error",
        "OK": "OK",
        "The Mousecape helper was successfully installed.": "The Mousecape helper was successfully installed.",
        "The Mousecape helper was successfully uninstalled.": "The Mousecape helper was successfully uninstalled."
    ],

    .chinese: [
        // Navigation
        "Home": "主页",
        "Settings": "设置",

        // Settings Categories
        "General": "通用",
        "Appearance": "外观",
        "Shortcuts": "快捷键",
        "Advanced": "高级",

        // General Settings
        "Startup": "启动",
        "Launch at Login": "登录时启动",
        "Apply Last Cape on Launch": "启动时应用上次的Cape",
        "Double-click Action": "双击操作",
        "When double-clicking a Cape": "双击Cape时",
        "Apply Cape": "应用Cape",
        "Edit Cape": "编辑Cape",
        "Do Nothing": "无操作",
        "Cursor Scale": "光标缩放",
        "Global Scale:": "全局缩放：",

        // Appearance Settings
        "Theme": "主题",
        "System": "跟随系统",
        "Light": "浅色",
        "Dark": "深色",
        "Language": "语言",
        "List Display": "列表显示",
        "Show Cursor Preview Animations": "显示光标预览动画",
        "Show Cape Author Info": "显示Cape作者信息",
        "Preview Panel": "预览面板",
        "Preview Grid Columns": "预览网格列数",
        "Auto (based on window size)": "自动（根据窗口大小）",
        "columns": "列",

        // Shortcuts Settings
        "Global Shortcuts": "全局快捷键",
        "Quick Apply Last Cape": "快速应用上次Cape",
        "Reset to Default Cursor": "重置为默认光标",
        "These shortcuts work in any application.": "这些快捷键在任何应用中都可用。",

        // Advanced Settings
        "Helper Tool": "辅助工具",
        "Mousecape Helper": "Mousecape 辅助程序",
        "Installed and running": "已安装并运行",
        "Not installed": "未安装",
        "Install": "安装",
        "Uninstall": "卸载",
        "The helper tool ensures cursors persist after logout/login and system updates.": "辅助工具确保光标在注销/登录和系统更新后保持不变。",
        "Storage": "存储",
        "Cape Folder": "Cape文件夹",
        "Show in Finder": "在Finder中显示",
        "Change Location...": "更改位置...",
        "Debug": "调试",
        "Enable Debug Logging": "启用调试日志",
        "Export Diagnostics...": "导出诊断信息...",
        "Reset": "重置",
        "Restore Default Settings": "恢复默认设置",
        "Cancel": "取消",
        "This will reset all settings to their default values. This action cannot be undone.": "这将把所有设置重置为默认值。此操作无法撤销。",
        "About": "关于",
        "Version": "版本",
        "System Requirements": "系统要求",
        "Author": "作者",
        "Check for Updates": "检查更新",
        "Report Issue": "报告问题",

        // Home View
        "No Capes": "没有Cape",
        "Create a new cape or import an existing one to get started.": "创建新的Cape或导入现有Cape以开始使用。",
        "New Cape": "新建Cape",
        "Import Cape": "导入Cape",
        "Select a Cape": "选择一个Cape",
        "Choose a cape from the list to preview": "从列表中选择一个Cape进行预览",

        // Toolbar
        "Export Cape": "导出Cape",
        "Delete Cape": "删除Cape",

        // Context Menu
        "Apply": "应用",
        "Edit": "编辑",
        "Export...": "导出...",
        "Delete": "删除",

        // Edit View
        "Back": "返回",
        "Save": "保存",
        "Cape Info": "Cape信息",
        "Cape Information": "Cape信息",
        "Name": "名称",
        "Identifier": "标识符",
        "Cursors": "光标",
        "HiDPI": "高分辨率",
        "File": "文件",
        "Select a Cursor": "选择光标",
        "Choose a cursor from the list to edit": "从列表中选择一个光标进行编辑",
        "Add Cursor": "添加光标",
        "All Cursor Types Added": "已添加所有光标类型",
        "This cape already contains all standard cursor types.": "此Cape已包含所有标准光标类型。",
        "Add": "添加",
        "Properties": "属性",
        "Type": "类型",
        "Hotspot": "热点",
        "Show": "显示",
        "Animation": "动画",
        "Frames:": "帧数：",
        "Duration:": "时长：",
        "Resolutions": "分辨率",
        "Drag images to add": "拖放图片以添加",

        // Dialogs
        "Are you sure you want to delete": "确定要删除",
        "This action cannot be undone.": "此操作无法撤销。",
        "Success": "成功",
        "Error": "错误",
        "OK": "确定",
        "The Mousecape helper was successfully installed.": "Mousecape辅助程序已成功安装。",
        "The Mousecape helper was successfully uninstalled.": "Mousecape辅助程序已成功卸载。"
    ]
]

// MARK: - Localization Manager

@Observable @MainActor
final class LocalizationManager {
    static let shared = LocalizationManager()

    var currentLanguage: AppLanguage = .system {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "appLanguage")
        }
    }

    private init() {
        // Load saved language preference
        if let saved = UserDefaults.standard.string(forKey: "appLanguage"),
           let language = AppLanguage(rawValue: saved) {
            currentLanguage = language
        }
    }

    // Get localized string based on current language
    nonisolated func localized(_ key: String) -> String {
        let effectiveLanguage = resolveLanguage()
        return localizationStrings[effectiveLanguage]?[key] ?? key
    }

    /// 获取当前有效语言（解析 system 选项后的实际语言）
    nonisolated func effectiveLanguage() -> AppLanguage {
        return resolveLanguage()
    }

    nonisolated private func resolveLanguage() -> AppLanguage {
        // Read currentLanguage in a thread-safe way
        let language = MainActor.assumeIsolated { self.currentLanguage }

        if language == .system {
            // Check system language
            let preferredLanguage = Locale.preferredLanguages.first ?? "en"
            if preferredLanguage.hasPrefix("zh") {
                return .chinese
            }
            return .english
        }
        return language
    }
}
