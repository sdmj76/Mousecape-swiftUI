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

/// Standard macOS cursor types (matching cursorMap in MCDefs.m)
enum CursorType: String, CaseIterable, Identifiable {
    // CoreGraphics cursors
    case arrow = "com.apple.coregraphics.Arrow"
    case arrowCtx = "com.apple.coregraphics.ArrowCtx"
    case arrowS = "com.apple.coregraphics.ArrowS"  // macOS 26+
    case iBeam = "com.apple.coregraphics.IBeam"
    case iBeamXOR = "com.apple.coregraphics.IBeamXOR"
    case iBeamS = "com.apple.coregraphics.IBeamS"  // macOS 26+
    case alias = "com.apple.coregraphics.Alias"
    case copy = "com.apple.coregraphics.Copy"
    case move = "com.apple.coregraphics.Move"
    case wait = "com.apple.coregraphics.Wait"
    case empty = "com.apple.coregraphics.Empty"

    // Apple cursor IDs (com.apple.cursor.*)
    case link = "com.apple.cursor.2"
    case forbidden = "com.apple.cursor.3"
    case busy = "com.apple.cursor.4"
    case copyDrag = "com.apple.cursor.5"
    case crosshair = "com.apple.cursor.7"
    case crosshair2 = "com.apple.cursor.8"
    case camera = "com.apple.cursor.9"
    case camera2 = "com.apple.cursor.10"
    case closed = "com.apple.cursor.11"
    case open = "com.apple.cursor.12"
    case pointing = "com.apple.cursor.13"
    case countingUp = "com.apple.cursor.14"
    case countingDown = "com.apple.cursor.15"
    case countingUpDown = "com.apple.cursor.16"
    case resizeW = "com.apple.cursor.17"
    case resizeE = "com.apple.cursor.18"
    case resizeWE = "com.apple.cursor.19"
    case cellXOR = "com.apple.cursor.20"
    case resizeN = "com.apple.cursor.21"
    case resizeS = "com.apple.cursor.22"
    case resizeNS = "com.apple.cursor.23"
    case ctxMenu = "com.apple.cursor.24"
    case poof = "com.apple.cursor.25"
    case iBeamH = "com.apple.cursor.26"
    case windowE = "com.apple.cursor.27"
    case windowEW = "com.apple.cursor.28"
    case windowNE = "com.apple.cursor.29"
    case windowNESW = "com.apple.cursor.30"
    case windowN = "com.apple.cursor.31"
    case windowNS = "com.apple.cursor.32"
    case windowNW = "com.apple.cursor.33"
    case windowNWSE = "com.apple.cursor.34"
    case windowSE = "com.apple.cursor.35"
    case windowS = "com.apple.cursor.36"
    case windowSW = "com.apple.cursor.37"
    case windowW = "com.apple.cursor.38"
    case resizeSquare = "com.apple.cursor.39"
    case help = "com.apple.cursor.40"
    case cell = "com.apple.cursor.41"
    case zoomIn = "com.apple.cursor.42"
    case zoomOut = "com.apple.cursor.43"

    var id: String { rawValue }

    var displayName: String {
        // Use the same names as cursorMap in MCDefs.m
        switch self {
        case .arrow: return "Arrow"
        case .arrowCtx: return "Ctx Arrow"
        case .arrowS: return "Arrow S"
        case .iBeam: return "IBeam"
        case .iBeamXOR: return "IBeamXOR"
        case .iBeamS: return "IBeam S"
        case .alias: return "Alias"
        case .copy: return "Copy"
        case .move: return "Move"
        case .wait: return "Wait"
        case .empty: return "Empty"
        case .link: return "Link"
        case .forbidden: return "Forbidden"
        case .busy: return "Busy"
        case .copyDrag: return "Copy Drag"
        case .crosshair: return "Crosshair"
        case .crosshair2: return "Crosshair 2"
        case .camera: return "Camera"
        case .camera2: return "Camera 2"
        case .closed: return "Closed"
        case .open: return "Open"
        case .pointing: return "Pointing"
        case .countingUp: return "Counting Up"
        case .countingDown: return "Counting Down"
        case .countingUpDown: return "Counting Up/Down"
        case .resizeW: return "Resize W"
        case .resizeE: return "Resize E"
        case .resizeWE: return "Resize W-E"
        case .cellXOR: return "Cell XOR"
        case .resizeN: return "Resize N"
        case .resizeS: return "Resize S"
        case .resizeNS: return "Resize N-S"
        case .ctxMenu: return "Ctx Menu"
        case .poof: return "Poof"
        case .iBeamH: return "IBeam H."
        case .windowE: return "Window E"
        case .windowEW: return "Window E-W"
        case .windowNE: return "Window NE"
        case .windowNESW: return "Window NE-SW"
        case .windowN: return "Window N"
        case .windowNS: return "Window N-S"
        case .windowNW: return "Window NW"
        case .windowNWSE: return "Window NW-SE"
        case .windowSE: return "Window SE"
        case .windowS: return "Window S"
        case .windowSW: return "Window SW"
        case .windowW: return "Window W"
        case .resizeSquare: return "Resize Square"
        case .help: return "Help"
        case .cell: return "Cell"
        case .zoomIn: return "Zoom In"
        case .zoomOut: return "Zoom Out"
        }
    }

    /// Returns a SF Symbol name for the cursor type (for preview)
    var previewSymbol: String {
        switch self {
        case .arrow, .arrowCtx, .arrowS: return "cursorarrow"
        case .iBeam, .iBeamXOR, .iBeamH, .iBeamS: return "character.cursor.ibeam"
        case .wait, .busy: return "clock"
        case .pointing: return "hand.point.up"
        case .open, .closed: return "hand.raised"
        case .crosshair, .crosshair2: return "plus"
        case .zoomIn: return "plus.magnifyingglass"
        case .zoomOut: return "minus.magnifyingglass"
        case .help: return "questionmark.circle"
        case .forbidden: return "nosign"
        case .copy, .copyDrag: return "doc.on.doc"
        case .move: return "arrow.up.and.down.and.arrow.left.and.right"
        case .alias, .link: return "link"
        case .camera, .camera2: return "camera"
        case .poof: return "cloud"
        case .countingUp, .countingDown, .countingUpDown: return "timer"
        case .ctxMenu: return "contextualmenu.and.cursorarrow"
        case .cell, .cellXOR: return "tablecells"
        case .resizeN, .resizeS, .resizeNS, .windowN, .windowS, .windowNS:
            return "arrow.up.arrow.down"
        case .resizeE, .resizeW, .resizeWE, .windowE, .windowW, .windowEW:
            return "arrow.left.arrow.right"
        case .windowNE, .windowSW, .windowNESW:
            return "arrow.up.right.arrow.down.left"
        case .windowNW, .windowSE, .windowNWSE:
            return "arrow.up.left.arrow.down.right"
        case .resizeSquare:
            return "arrow.up.left.and.arrow.down.right"
        case .empty: return "rectangle.dashed"
        }
    }
}
