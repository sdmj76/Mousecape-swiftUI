//
//  MousecapeApp.swift
//  Mousecape
//
//  SwiftUI App entry point for macOS 26+
//  Single window architecture with Liquid Glass design
//

import SwiftUI

@main
struct MousecapeApp: App {
    @State private var appState = AppState.shared
    @State private var localization = LocalizationManager.shared

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
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 600)
        .commands {
            MousecapeCommands()
        }
    }

    private func configureWindowAppearance() {
        DispatchQueue.main.async {
            guard let window = NSApp.windows.first else { return }

            // Make titlebar transparent
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true

// ToolbarHider disabled - testing separate ToolbarItems
            // ToolbarHider.startMonitoring()
        }
    }
}

// MARK: - Toolbar Platter Hider

/// Hides NSToolbarPlatterView (Liquid Glass background) in macOS 26
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

// MARK: - Appearance Wrapper (实时跟随系统外观)

struct AppearanceWrapper<Content: View>: View {
    @AppStorage("appearanceMode") private var appearanceMode = 0
    @ViewBuilder let content: Content

    var body: some View {
        content
            .preferredColorScheme(effectiveColorScheme)
            .onChange(of: appearanceMode, initial: true) { _, newValue in
                updateAppAppearance(newValue)
            }
    }

    private var effectiveColorScheme: ColorScheme? {
        switch appearanceMode {
        case 1: return .light
        case 2: return .dark
        default: return nil  // 跟随系统 - 返回 nil 让系统决定
        }
    }

    private func updateAppAppearance(_ mode: Int) {
        // 直接设置 NSApplication 的外观以确保实时生效
        switch mode {
        case 1:
            NSApp.appearance = NSAppearance(named: .aqua)
        case 2:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        default:
            NSApp.appearance = nil  // 跟随系统
        }
    }
}

// MARK: - Content View (Root)

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        ZStack {
            // Main interface layer (Home / Settings) - 仅在非编辑模式显示
            if !appState.isEditing {
                MainView()
                    .transition(.opacity)
            }

            // Edit view - 完全覆盖主界面
            if appState.isEditing, let cape = appState.editingCape {
                EditOverlayView(cape: cape)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.4), value: appState.isEditing)
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
