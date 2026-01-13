//
//  SettingsView.swift
//  Mousecape
//
//  Settings view with left sidebar navigation
//  Integrated into main window via page switcher
//

import SwiftUI

struct SettingsView: View {
    @State private var selectedCategory: SettingsCategory = .general
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @Environment(LocalizationManager.self) private var localization
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Left sidebar: Category list
            List(SettingsCategory.allCases, selection: $selectedCategory) { category in
                Label(localization.localized(category.title), systemImage: category.icon)
                    .tag(category)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .navigationSplitViewColumnWidth(min: 150, ideal: 180, max: 220)
        } detail: {
            // Right: Settings content based on selected category
            settingsContent
                .scrollContentBackground(.hidden)
                .transition(.opacity.animation(.easeInOut(duration: 0.2)))
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: {
                    appState.currentPage = .home
                }) {
                    Image(systemName: "checkmark")
                }
                .help("Done")
            }
        }
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
    }

    @ViewBuilder
    private var settingsContent: some View {
        switch selectedCategory {
        case .general:
            GeneralSettingsView()
        case .appearance:
            AppearanceSettingsView()
        case .advanced:
            AdvancedSettingsView()
        }
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @AppStorage("applyLastCapeOnLaunch") private var applyLastCapeOnLaunch = true
    @AppStorage("doubleClickAction") private var doubleClickAction = 0
    @State private var cursorScale: Double = 1.0
    @Environment(LocalizationManager.self) private var localization
    @Environment(AppState.self) private var appState

    /// The key used by ObjC code for cursor scale
    private static let cursorScaleKey = "MCCursorScale"
    private static let preferenceDomain = "com.alexzielenski.Mousecape"

    var body: some View {
        Form {
            // Helper Tool Section (moved from Advanced)
            HelperToolSettingsView()

            Section(localization.localized("Startup")) {
                Toggle(localization.localized("Apply Last Cape on Launch"), isOn: $applyLastCapeOnLaunch)
            }

            Section(localization.localized("Double-click Action")) {
                Picker(localization.localized("When double-clicking a Cape"), selection: $doubleClickAction) {
                    Text(localization.localized("Apply Cape")).tag(0)
                    Text(localization.localized("Edit Cape")).tag(1)
                    Text(localization.localized("Do Nothing")).tag(2)
                }
            }

            Section(localization.localized("Cursor Scale")) {
                VStack(alignment: .leading) {
                    Text("\(localization.localized("Global Scale:")) \(cursorScale, specifier: "%.1f")x")
                    Slider(value: $cursorScale, in: 0.5...2.0, step: 0.1) {
                        Text("Scale")
                    } minimumValueLabel: {
                        Text("0.5x")
                    } maximumValueLabel: {
                        Text("2.0x")
                    }
                    .onChange(of: cursorScale) { _, newValue in
                        saveCursorScale(newValue)
                        // Apply the cursor scale immediately using the ObjC function
                        _ = setCursorScale(Float(newValue))
                    }

                    Text(localization.localized("Scale changes are applied immediately."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .navigationTitle(localization.localized("General"))
        .onAppear {
            loadCursorScale()
        }
    }

    /// Load cursor scale from CFPreferences (same as ObjC code)
    private func loadCursorScale() {
        if let value = CFPreferencesCopyAppValue(Self.cursorScaleKey as CFString, Self.preferenceDomain as CFString) as? Double {
            cursorScale = value
        } else {
            cursorScale = 1.0
        }
    }

    /// Save cursor scale to CFPreferences (same as ObjC code)
    private func saveCursorScale(_ value: Double) {
        CFPreferencesSetAppValue(
            Self.cursorScaleKey as CFString,
            value as CFNumber,
            Self.preferenceDomain as CFString
        )
        CFPreferencesAppSynchronize(Self.preferenceDomain as CFString)
    }
}

// MARK: - Appearance Settings

struct AppearanceSettingsView: View {
    /// appearanceMode: 1 = Light, 2 = Dark (默认 1 = Light)
    @AppStorage("appearanceMode") private var appearanceMode = 1
    @AppStorage("showPreviewAnimations") private var showPreviewAnimations = true
    @AppStorage("showAuthorInfo") private var showAuthorInfo = true
    @AppStorage("previewGridColumns") private var previewGridColumns = 0
    @AppStorage("transparentWindow") private var transparentWindow = false
    @Environment(LocalizationManager.self) private var localization

    private var isDarkMode: Bool {
        appearanceMode == 2
    }

    var body: some View {
        @Bindable var localization = localization

        Form {
            Section(localization.localized("Theme")) {
                Picker(localization.localized("Appearance"), selection: $appearanceMode) {
                    Text(localization.localized("Light")).tag(1)
                    Text(localization.localized("Dark")).tag(2)
                }
                .pickerStyle(.radioGroup)

                Toggle(localization.localized("Transparent Window"), isOn: $transparentWindow)
                    .onChange(of: transparentWindow) { _, newValue in
                        updateWindowTransparency(newValue)
                    }
                Text(localization.localized("Enable semi-transparent window background"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(localization.localized("Language")) {
                Picker(localization.localized("Language"), selection: $localization.currentLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.localizedDisplayName(for: localization.effectiveLanguage())).tag(language)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section(localization.localized("List Display")) {
                Toggle(localization.localized("Show Cursor Preview Animations"), isOn: $showPreviewAnimations)
                Toggle(localization.localized("Show Cape Author Info"), isOn: $showAuthorInfo)
            }

            Section(localization.localized("Preview Panel")) {
                Picker(localization.localized("Preview Grid Columns"), selection: $previewGridColumns) {
                    Text(localization.localized("Auto (based on window size)")).tag(0)
                    Text("4 \(localization.localized("columns"))").tag(4)
                    Text("6 \(localization.localized("columns"))").tag(6)
                    Text("8 \(localization.localized("columns"))").tag(8)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .navigationTitle(localization.localized("Appearance"))
    }

    /// Update window transparency in real-time
    private func updateWindowTransparency(_ transparent: Bool) {
        guard let window = NSApp.windows.first else { return }
        if transparent {
            window.isOpaque = false
            if isDarkMode {
                // 深色模式：使用深灰色背景，避免与桌面混合时泛白
                window.backgroundColor = NSColor(calibratedWhite: 0.15, alpha: 0.95)
            } else {
                // 浅色模式：使用系统窗口背景色
                window.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.9)
            }
        } else {
            window.isOpaque = true
            window.backgroundColor = NSColor.windowBackgroundColor
        }
    }
}

// MARK: - Advanced Settings

struct AdvancedSettingsView: View {
    @State private var showResetConfirmation = false
    @State private var isExportingLogs = false
    @Environment(AppState.self) private var appState
    @Environment(LocalizationManager.self) private var localization

    var body: some View {
        Form {
            Section(localization.localized("Storage")) {
                LabeledContent(localization.localized("Cape Folder")) {
                    Text("~/Library/Application Support/Mousecape/capes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button(localization.localized("Show in Finder")) {
                    appState.openCapeFolder()
                }
            }

            Section(localization.localized("Reset")) {
                Button(localization.localized("Restore Default Settings"), role: .destructive) {
                    showResetConfirmation = true
                }
                .confirmationDialog(
                    localization.localized("Restore Default Settings"),
                    isPresented: $showResetConfirmation,
                    titleVisibility: .visible
                ) {
                    Button(localization.localized("Restore Default Settings"), role: .destructive) {
                        resetToDefaults()
                    }
                    Button(localization.localized("Cancel"), role: .cancel) { }
                } message: {
                    Text(localization.localized("This will reset all settings to their default values. This action cannot be undone."))
                }
            }

            #if DEBUG
            Section(localization.localized("Debug")) {
                LabeledContent(localization.localized("Log Folder")) {
                    Text("~/Library/Logs/Mousecape")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                LabeledContent(localization.localized("Log Files")) {
                    let files = DebugLogger.getAllLogFiles()
                    let size = DebugLogger.getTotalLogSize()
                    Text("\(files.count) files, \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button(localization.localized("Open Log Folder")) {
                        NSWorkspace.shared.open(DebugLogger.logsDirectory)
                    }

                    Button(localization.localized("Export All Logs")) {
                        exportLogs()
                    }
                    .disabled(isExportingLogs)

                    Button(localization.localized("Clear All Logs"), role: .destructive) {
                        DebugLogger.clearAllLogs()
                    }
                }

                Text(localization.localized("Logs are automatically deleted after 24 hours. Logs contain debug information for troubleshooting cursor issues."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            #endif

            Section(localization.localized("About")) {
                LabeledContent(localization.localized("Version")) {
                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                       let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                        Text("Mousecape v\(version) (\(build))")
                    } else {
                        Text("Mousecape v1.0.1")
                    }
                }
                LabeledContent(localization.localized("System Requirements")) {
                    Text("macOS 15+")
                }
                LabeledContent(localization.localized("Original Author")) {
                    Text("\u{00A9} 2014-2025 Alex Zielenski")
                }
                LabeledContent(localization.localized("SwiftUI Redesign")) {
                    Text("\u{00A9} 2025 sdmj76")
                }

                HStack {
                    Button(localization.localized("Check for Updates")) {
                        checkForUpdates()
                    }
                    Button("GitHub") {
                        if let url = URL(string: "https://github.com/sdmj76/Mousecape") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    Button(localization.localized("Report Issue")) {
                        if let url = URL(string: "https://github.com/sdmj76/Mousecape/issues") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .navigationTitle(localization.localized("Advanced"))
    }

    private func resetToDefaults() {
        // Reset all settings to defaults
        let defaults = UserDefaults.standard
        let domain = Bundle.main.bundleIdentifier!
        defaults.removePersistentDomain(forName: domain)

        // Reset language to system default
        LocalizationManager.shared.currentLanguage = .system
    }

    #if DEBUG
    private func exportLogs() {
        isExportingLogs = true

        DispatchQueue.global(qos: .userInitiated).async {
            guard let zipURL = DebugLogger.exportLogsAsZip() else {
                DispatchQueue.main.async {
                    isExportingLogs = false
                }
                return
            }

            DispatchQueue.main.async {
                isExportingLogs = false

                // Use NSSavePanel to let user choose save location
                let savePanel = NSSavePanel()
                savePanel.allowedContentTypes = [.zip]
                savePanel.nameFieldStringValue = zipURL.lastPathComponent
                savePanel.canCreateDirectories = true
                savePanel.title = "Export Debug Logs"

                if savePanel.runModal() == .OK, let destURL = savePanel.url {
                    do {
                        // Remove existing file if any
                        try? FileManager.default.removeItem(at: destURL)
                        try FileManager.default.copyItem(at: zipURL, to: destURL)

                        // Clean up temp file
                        try? FileManager.default.removeItem(at: zipURL)

                        // Show in Finder
                        NSWorkspace.shared.selectFile(destURL.path, inFileViewerRootedAtPath: "")
                    } catch {
                        debugLog("Failed to save logs: \(error.localizedDescription)")
                    }
                } else {
                    // Clean up temp file if user cancelled
                    try? FileManager.default.removeItem(at: zipURL)
                }
            }
        }
    }
    #endif

    private func checkForUpdates() {
        // Open GitHub releases page for manual update checking
        if let url = URL(string: "https://github.com/sdmj76/Mousecape/releases") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environment(AppState.shared)
        .environment(LocalizationManager.shared)
        .frame(width: 600, height: 500)
}
