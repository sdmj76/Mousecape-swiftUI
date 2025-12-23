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
    @Environment(LocalizationManager.self) private var localization

    var body: some View {
        NavigationSplitView {
            // Left sidebar: Category list
            List(SettingsCategory.allCases, selection: $selectedCategory) { category in
                Label(localization.localized(category.title), systemImage: category.icon)
                    .tag(category)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 150, ideal: 180, max: 220)
        } detail: {
            // Right: Settings content based on selected category
            settingsContent
                .transition(.opacity.animation(.easeInOut(duration: 0.2)))
        }
    }

    @ViewBuilder
    private var settingsContent: some View {
        switch selectedCategory {
        case .general:
            GeneralSettingsView()
        case .appearance:
            AppearanceSettingsView()
        case .shortcuts:
            ShortcutsSettingsView()
        case .advanced:
            AdvancedSettingsView()
        }
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("applyLastCapeOnLaunch") private var applyLastCapeOnLaunch = true
    @AppStorage("doubleClickAction") private var doubleClickAction = 0
    @AppStorage("cursorScale") private var cursorScale = 1.0
    @Environment(LocalizationManager.self) private var localization

    var body: some View {
        Form {
            Section(localization.localized("Startup")) {
                Toggle(localization.localized("Launch at Login"), isOn: $launchAtLogin)
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
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(localization.localized("General"))
    }
}

// MARK: - Appearance Settings

struct AppearanceSettingsView: View {
    @AppStorage("appearanceMode") private var appearanceMode = 0
    @AppStorage("showPreviewAnimations") private var showPreviewAnimations = true
    @AppStorage("showAuthorInfo") private var showAuthorInfo = true
    @AppStorage("previewGridColumns") private var previewGridColumns = 0
    @Environment(LocalizationManager.self) private var localization

    var body: some View {
        @Bindable var localization = localization

        Form {
            Section(localization.localized("Theme")) {
                Picker(localization.localized("Appearance"), selection: $appearanceMode) {
                    Text(localization.localized("System")).tag(0)
                    Text(localization.localized("Light")).tag(1)
                    Text(localization.localized("Dark")).tag(2)
                }
                .pickerStyle(.radioGroup)
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
        .navigationTitle(localization.localized("Appearance"))
    }
}

// MARK: - Shortcuts Settings

struct ShortcutsSettingsView: View {
    @State private var applyLastCapeShortcut = "\u{2325}\u{21E7}C"
    @State private var resetToDefaultShortcut = "\u{2325}\u{21E7}R"
    @Environment(LocalizationManager.self) private var localization

    var body: some View {
        Form {
            Section(localization.localized("Global Shortcuts")) {
                HStack {
                    Text(localization.localized("Quick Apply Last Cape"))
                    Spacer()
                    ShortcutRecorderView(shortcut: $applyLastCapeShortcut)
                }

                HStack {
                    Text(localization.localized("Reset to Default Cursor"))
                    Spacer()
                    ShortcutRecorderView(shortcut: $resetToDefaultShortcut)
                }
            }

            Section {
                Text(localization.localized("These shortcuts work in any application."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(localization.localized("Shortcuts"))
    }
}

// MARK: - Shortcut Recorder View (Simplified)

struct ShortcutRecorderView: View {
    @Binding var shortcut: String

    var body: some View {
        TextField("", text: $shortcut)
            .frame(width: 80)
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.center)
    }
}

// MARK: - Advanced Settings

struct AdvancedSettingsView: View {
    @AppStorage("debugLogging") private var debugLogging = false
    @State private var showResetConfirmation = false
    @Environment(AppState.self) private var appState
    @Environment(LocalizationManager.self) private var localization

    var body: some View {
        Form {
            // Helper Tool Section
            HelperToolSettingsView()

            Section(localization.localized("Storage")) {
                LabeledContent(localization.localized("Cape Folder")) {
                    Text("~/Library/Application Support/Mousecape/capes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button(localization.localized("Show in Finder")) {
                        appState.openCapeFolder()
                    }
                    Button(localization.localized("Change Location...")) {
                        // TODO: Implement location change
                    }
                }
            }

            Section(localization.localized("Debug")) {
                Toggle(localization.localized("Enable Debug Logging"), isOn: $debugLogging)
                Button(localization.localized("Export Diagnostics...")) {
                    exportDiagnostics()
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

            Section(localization.localized("About")) {
                LabeledContent(localization.localized("Version")) {
                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                       let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                        Text("Mousecape v\(version) (\(build))")
                    } else {
                        Text("Mousecape v2.0")
                    }
                }
                LabeledContent(localization.localized("System Requirements")) {
                    Text("macOS 26+")
                }
                LabeledContent(localization.localized("Author")) {
                    Text("\u{00A9} 2014-2025 Alex Zielenski")
                }

                HStack {
                    Button(localization.localized("Check for Updates")) {
                        checkForUpdates()
                    }
                    Button("GitHub") {
                        if let url = URL(string: "https://github.com/alexzielenski/Mousecape") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    Button(localization.localized("Report Issue")) {
                        if let url = URL(string: "https://github.com/alexzielenski/Mousecape/issues") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(localization.localized("Advanced"))
    }

    private func resetToDefaults() {
        // Reset all settings to defaults
        let defaults = UserDefaults.standard
        let domain = Bundle.main.bundleIdentifier!
        defaults.removePersistentDomain(forName: domain)
    }

    private func exportDiagnostics() {
        let panel = NSSavePanel()
        panel.title = "Export Diagnostics"
        panel.nameFieldStringValue = "mousecape-diagnostics.txt"
        panel.allowedContentTypes = [.plainText]

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            var diagnostics = "Mousecape Diagnostics\n"
            diagnostics += "======================\n\n"
            diagnostics += "Date: \(Date())\n"
            diagnostics += "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)\n"

            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
               let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                diagnostics += "App Version: \(version) (\(build))\n"
            }

            diagnostics += "\nCape Count: \(appState.capes.count)\n"
            if let applied = appState.appliedCape {
                diagnostics += "Applied Cape: \(applied.name)\n"
            }

            diagnostics += "\nUser Defaults:\n"
            let defaults = UserDefaults.standard.dictionaryRepresentation()
            for (key, value) in defaults where key.hasPrefix("com.alexzielenski") || key.contains("cape") || key.contains("cursor") {
                diagnostics += "  \(key): \(value)\n"
            }

            try? diagnostics.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func checkForUpdates() {
        // Trigger Sparkle update check if available
        // For now, open the releases page
        if let url = URL(string: "https://github.com/alexzielenski/Mousecape/releases") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environment(AppState.shared)
        .frame(width: 600, height: 500)
}
