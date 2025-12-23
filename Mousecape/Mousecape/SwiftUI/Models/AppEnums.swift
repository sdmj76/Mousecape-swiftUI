//
//  AppEnums.swift
//  Mousecape
//
//  SwiftUI enumerations for the app
//

import Foundation

// MARK: - Page Navigation

/// Main app page selection (Home / Settings)
enum AppPage: String, CaseIterable, Identifiable {
    case home
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .settings: return "Settings"
        }
    }
}

// MARK: - Settings Categories

/// Settings page categories
enum SettingsCategory: String, CaseIterable, Identifiable {
    case general
    case appearance
    case shortcuts
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .appearance: return "Appearance"
        case .shortcuts: return "Shortcuts"
        case .advanced: return "Advanced"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gear"
        case .appearance: return "paintbrush"
        case .shortcuts: return "keyboard"
        case .advanced: return "wrench.and.screwdriver"
        }
    }
}

// MARK: - Double Click Action

/// Action to perform when double-clicking a cape
enum DoubleClickAction: Int, CaseIterable, Identifiable {
    case applyCape = 0
    case editCape = 1
    case doNothing = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .applyCape: return "Apply Cape"
        case .editCape: return "Edit Cape"
        case .doNothing: return "Do Nothing"
        }
    }
}

// MARK: - Cursor Scale

/// Cursor resolution scales
enum CursorScale: Int, CaseIterable, Identifiable {
    case scale100 = 100
    case scale200 = 200
    case scale500 = 500
    case scale1000 = 1000

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .scale100: return "1x"
        case .scale200: return "2x"
        case .scale500: return "5x"
        case .scale1000: return "10x"
        }
    }

    var multiplier: CGFloat {
        CGFloat(rawValue) / 100.0
    }
}

// MARK: - Cursor Type

/// Standard macOS cursor types
enum CursorType: String, CaseIterable, Identifiable {
    case arrow = "com.apple.coregraphics.Arrow"
    case iBeam = "com.apple.coregraphics.IBeam"
    case iBeamH = "com.apple.coregraphics.IBeamH"
    case alias = "com.apple.coregraphics.Alias"
    case copy = "com.apple.coregraphics.Copy"
    case move = "com.apple.coregraphics.Move"
    case arrowCtx = "com.apple.coregraphics.ArrowCtx"
    case wait = "com.apple.coregraphics.Wait"
    case empty = "com.apple.coregraphics.Empty"

    // Resize cursors
    case resizeN = "com.apple.coregraphics.ResizeN"
    case resizeS = "com.apple.coregraphics.ResizeS"
    case resizeE = "com.apple.coregraphics.ResizeE"
    case resizeW = "com.apple.coregraphics.ResizeW"
    case resizeNE = "com.apple.coregraphics.ResizeNE"
    case resizeNW = "com.apple.coregraphics.ResizeNW"
    case resizeSE = "com.apple.coregraphics.ResizeSE"
    case resizeSW = "com.apple.coregraphics.ResizeSW"
    case resizeNS = "com.apple.coregraphics.ResizeNS"
    case resizeEW = "com.apple.coregraphics.ResizeEW"
    case resizeNESW = "com.apple.coregraphics.ResizeNESW"
    case resizeNWSE = "com.apple.coregraphics.ResizeNWSE"

    // Hand cursors
    case openHand = "com.apple.coregraphics.OpenHand"
    case closedHand = "com.apple.coregraphics.ClosedHand"
    case pointingHand = "com.apple.coregraphics.PointingHand"

    // Other
    case crosshair = "com.apple.coregraphics.Crosshair"
    case zoomIn = "com.apple.coregraphics.ZoomIn"
    case zoomOut = "com.apple.coregraphics.ZoomOut"
    case help = "com.apple.coregraphics.Help"
    case notAllowed = "com.apple.coregraphics.NotAllowed"
    case busyButClickable = "com.apple.coregraphics.BusyButClickable"

    var id: String { rawValue }

    var displayName: String {
        // Extract the name from the identifier
        let components = rawValue.components(separatedBy: ".")
        return components.last ?? rawValue
    }

    /// Returns a SF Symbol name for the cursor type (for preview)
    var previewSymbol: String {
        switch self {
        case .arrow, .arrowCtx: return "cursorarrow"
        case .iBeam, .iBeamH: return "character.cursor.ibeam"
        case .wait, .busyButClickable: return "clock"
        case .pointingHand: return "hand.point.up"
        case .openHand, .closedHand: return "hand.raised"
        case .crosshair: return "plus"
        case .zoomIn: return "plus.magnifyingglass"
        case .zoomOut: return "minus.magnifyingglass"
        case .help: return "questionmark.circle"
        case .notAllowed: return "nosign"
        default: return "cursorarrow"
        }
    }
}
