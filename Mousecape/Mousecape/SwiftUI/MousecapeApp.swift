//
//  MousecapeApp.swift
//  Mousecape
//
//  SwiftUI App entry point for macOS 15+
//  Single window architecture with modern design
//

import SwiftUI
import ServiceManagement

@main
struct MousecapeApp: App {
    @State private var appState = AppState.shared
    @State private var localization = LocalizationManager.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            AppearanceWrapper {
                ContentView()
                    .environment(appState)
                    .environment(localization)
            }
            .onAppear {
                configureWindowAppearance()
            }
        }
        .defaultSize(width: 900, height: 600)
        .commands {
            MousecapeCommands()
        }
    }

    private func configureWindowAppearance() {
        DispatchQueue.main.async {
            guard let window = NSApp.windows.first else { return }

            // Make titlebar transparent for cleaner look
            window.titlebarAppearsTransparent = true

            // Configure window background based on user's transparentWindow setting
            let transparentWindow = UserDefaults.standard.bool(forKey: "transparentWindow")
            if transparentWindow {
                window.isOpaque = false
                // 检测当前是否为深色模式
                let isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
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

            // Disable fullscreen (green) button
            window.collectionBehavior.remove(.fullScreenPrimary)
            if let zoomButton = window.standardWindowButton(.zoomButton) {
                zoomButton.isEnabled = false
            }

            // Set up window delegate for close confirmation
            appDelegate.setupWindowDelegate(for: window, appState: appState)

// ToolbarHider disabled - testing separate ToolbarItems
            // ToolbarHider.startMonitoring()
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowDelegate: WindowDelegate?

    @MainActor
    func setupWindowDelegate(for window: NSWindow, appState: AppState) {
        windowDelegate = WindowDelegate(appState: appState)
        window.delegate = windowDelegate
        windowDelegate?.startObservingDirtyState()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check and repair Helper if needed (fixes error 78 after app update)
        checkAndRepairHelper()

        // Apply last cape on launch if enabled
        let applyLastCapeOnLaunch = UserDefaults.standard.bool(forKey: "applyLastCapeOnLaunch")
        // Default to true if never set
        if UserDefaults.standard.object(forKey: "applyLastCapeOnLaunch") == nil {
            UserDefaults.standard.set(true, forKey: "applyLastCapeOnLaunch")
        }

        if applyLastCapeOnLaunch || UserDefaults.standard.object(forKey: "applyLastCapeOnLaunch") == nil {
            // Get last applied cape identifier from preferences
            if let lastCapeIdentifier = UserDefaults.standard.string(forKey: "lastAppliedCapeIdentifier") {
                Task { @MainActor in
                    let appState = AppState.shared
                    if let cape = appState.capes.first(where: { $0.identifier == lastCapeIdentifier }) {
                        appState.applyCape(cape)
                    }
                }
            }
        }
    }

    /// Check if Helper is in a bad state (error 78) and repair it
    /// This fixes the issue when app is updated while Helper is still running
    private func checkAndRepairHelper() {
        let helperIdentifier = "com.sdmj76.mousecloakhelper"
        let service = SMAppService.loginItem(identifier: helperIdentifier)

        // Only check if Helper was previously enabled
        guard service.status == .enabled else {
            helperLog("Helper not enabled, skipping health check")
            return
        }

        helperLog("=== Helper Health Check ===")

        // Check launchd status
        let launchdStatus = checkHelperLaunchdStatus(helperIdentifier)
        helperLog("launchd status: \(launchdStatus)")

        // If Helper is running with exit code 78, it needs repair
        if launchdStatus.contains("exit code: 78") || launchdStatus.contains("Not running") {
            helperLog("Helper in bad state, attempting repair...")

            // Force cleanup and re-register
            forceCleanupHelper(helperIdentifier)

            do {
                // Unregister first
                try? service.unregister()
                helperLog("Unregistered old Helper")

                // Small delay to let launchd settle
                Thread.sleep(forTimeInterval: 0.5)

                // Re-register
                try service.register()
                helperLog("Re-registered Helper")

                // Verify
                let newStatus = checkHelperLaunchdStatus(helperIdentifier)
                helperLog("After repair - launchd status: \(newStatus)")

                if newStatus.contains("Running") {
                    helperLog("Helper repair successful!")
                } else {
                    helperLog("Helper repair may have failed, status: \(newStatus)")
                }
            } catch {
                helperLog("Helper repair failed: \(error.localizedDescription)")
            }
        } else if launchdStatus.contains("Running") {
            helperLog("Helper is healthy")
        } else {
            helperLog("Helper status unknown: \(launchdStatus)")
        }

        helperLog("=== End Health Check ===")
    }

    private func forceCleanupHelper(_ identifier: String) {
        let uid = getuid()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["bootout", "gui/\(uid)/\(identifier)"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try? process.run()
        process.waitUntilExit()
        helperLog("launchctl bootout exit code: \(process.terminationStatus)")
    }

    private func checkHelperLaunchdStatus(_ identifier: String) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["list"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            for line in output.components(separatedBy: "\n") {
                if line.contains(identifier) {
                    let parts = line.split(separator: "\t").map(String.init)
                    if parts.count >= 3 {
                        let pid = parts[0]
                        let exitCode = parts[1]
                        if pid == "-" {
                            return "Not running (exit code: \(exitCode))"
                        } else {
                            return "Running (PID: \(pid), exit code: \(exitCode))"
                        }
                    }
                    return line
                }
            }
            return "Not found in launchctl list"
        } catch {
            return "Check failed: \(error.localizedDescription)"
        }
    }

    private func helperLog(_ message: String) {
        #if DEBUG
        DebugLogger.shared.log(message, file: "HelperHealthCheck", line: 0)
        #endif
    }

    // Quit app when last window is closed
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    // Close ObjC logging system on exit
    func applicationWillTerminate(_ notification: Notification) {
        #if DEBUG
        MCLoggerClose()
        #endif
    }
}

// MARK: - Window Delegate (handles close confirmation)

@MainActor
class WindowDelegate: NSObject, NSWindowDelegate {
    private let appState: AppState
    private var timer: Timer?

    init(appState: AppState) {
        self.appState = appState
        super.init()
    }

    func startObservingDirtyState() {
        // Use a timer to periodically check dirty state
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateDocumentEdited()
        }
    }

    private func updateDocumentEdited() {
        guard let window = NSApp.windows.first else { return }
        // Use manual hasUnsavedChanges instead of ObjC isDirty
        let isDirty = appState.isEditing && appState.hasUnsavedChanges
        if window.isDocumentEdited != isDirty {
            window.isDocumentEdited = isDirty
        }
    }

    nonisolated func windowShouldClose(_ sender: NSWindow) -> Bool {
        let shouldBlock = MainActor.assumeIsolated {
            appState.isEditing && appState.hasUnsavedChanges
        }

        if shouldBlock {
            Task { @MainActor in
                appState.showDiscardConfirmation = true
            }
            return false
        }
        return true
    }
}

// MARK: - Toolbar Platter Hider

/// Hides NSToolbarPlatterView (toolbar background) in macOS 15+
enum ToolbarHider {
    @MainActor private static var timer: Timer?

    @MainActor
    static func startMonitoring() {
        // Initial hide
        hideToolbarPlatter()

        // Monitor for view changes - check frequently at first, then less often
        var checkCount = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            DispatchQueue.main.async {
                hideToolbarPlatter()
                checkCount += 1

                // After 20 checks (2 seconds), slow down to every 0.5s
                if checkCount >= 20 {
                    timer?.invalidate()
                    timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                        DispatchQueue.main.async {
                            hideToolbarPlatter()
                        }
                    }
                }
            }
        }
    }

    @MainActor
    static func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    @MainActor
    private static func hideToolbarPlatter() {
        guard let window = NSApp.windows.first else { return }
        hideToolbarPlatterInView(window.contentView?.superview)
    }

    @MainActor
    private static func hideToolbarPlatterInView(_ view: NSView?) {
        guard let view = view else { return }

        let className = String(describing: type(of: view))

        // Resize NSToolbarPlatterView to fit toolbar items
        if className == "NSToolbarPlatterView" {
            // Option 1: Hide it completely
            // view.isHidden = true

            // Option 2: Resize to fit toolbar items
            if let superview = view.superview {
                // Find the toolbar item viewers to calculate proper width
                var minX: CGFloat = .greatestFiniteMagnitude
                var maxX: CGFloat = 0
                findToolbarItemBounds(in: superview, minX: &minX, maxX: &maxX)
                if minX < maxX {
                    let padding: CGFloat = 8
                    view.frame = NSRect(
                        x: minX - padding,
                        y: view.frame.origin.y,
                        width: (maxX - minX) + padding * 2,
                        height: view.frame.height
                    )
                }
            }
        }

        for subview in view.subviews {
            hideToolbarPlatterInView(subview)
        }
    }

    @MainActor
    private static func findToolbarItemBounds(in view: NSView, minX: inout CGFloat, maxX: inout CGFloat) {
        let className = String(describing: type(of: view))
        if className == "NSToolbarItemViewer" {
            let frame = view.convert(view.bounds, to: nil)
            minX = min(minX, frame.minX)
            maxX = max(maxX, frame.maxX)
        }
        for subview in view.subviews {
            findToolbarItemBounds(in: subview, minX: &minX, maxX: &maxX)
        }
    }
}

// MARK: - Appearance Wrapper

struct AppearanceWrapper<Content: View>: View {
    /// appearanceMode: 1 = Light, 2 = Dark (默认 1 = Light)
    @AppStorage("appearanceMode") private var appearanceMode = 1
    @AppStorage("transparentWindow") private var transparentWindow = false
    @ViewBuilder let content: Content

    private var isDarkMode: Bool {
        appearanceMode == 2
    }

    var body: some View {
        content
            .preferredColorScheme(isDarkMode ? .dark : .light)
            .onChange(of: appearanceMode, initial: true) { _, newValue in
                updateAppAppearance(newValue)
            }
    }

    private func updateAppAppearance(_ mode: Int) {
        // 直接设置 NSApplication 的外观以确保实时生效
        if mode == 2 {
            NSApp.appearance = NSAppearance(named: .darkAqua)
        } else {
            NSApp.appearance = NSAppearance(named: .aqua)
        }

        // 更新窗口背景色
        DispatchQueue.main.async {
            updateWindowOpacity(isDark: mode == 2)
        }
    }

    private func updateWindowOpacity(isDark: Bool) {
        guard let window = NSApp.windows.first else { return }

        if transparentWindow {
            window.isOpaque = false
            if isDark {
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

// MARK: - Content View (Root)

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        MainView()
            // Error alert
            .alert("Error", isPresented: $appState.showError) {
                Button("OK") {
                    appState.showError = false
                }
            } message: {
                if let error = appState.lastError {
                    Text(error.localizedDescription)
                }
            }
    }
}

// MARK: - FocusedValues for Menu Commands

extension FocusedValues {
    struct SelectedCapeKey: FocusedValueKey {
        typealias Value = Binding<CursorLibrary?>
    }

    var selectedCape: Binding<CursorLibrary?>? {
        get { self[SelectedCapeKey.self] }
        set { self[SelectedCapeKey.self] = newValue }
    }
}
