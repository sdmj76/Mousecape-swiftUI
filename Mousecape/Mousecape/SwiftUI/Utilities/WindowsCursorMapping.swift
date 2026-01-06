//
//  WindowsCursorMapping.swift
//  Mousecape
//
//  Maps Windows cursor filenames to macOS cursor types
//

import Foundation

/// Maps Windows cursor names to macOS CursorType identifiers
struct WindowsCursorMapping {

    /// Mapping from Windows cursor filename (without extension) to macOS cursor types
    /// Some Windows cursors map to multiple macOS types (e.g., Vertical → both Resize N-S and Window N-S)
    static let mapping: [String: [CursorType]] = [
        // Standard cursors
        "Normal": [.arrow],
        "Text": [.iBeam],
        "Link": [.pointing],
        "Busy": [.busy],
        "Working": [.wait],
        "Precision": [.crosshair],
        "Unavailable": [.forbidden],
        "Move": [.move],
        "Help": [.help],

        // Resize cursors - map to both Resize and Window variants
        "Vertical": [.resizeNS, .windowNS],
        "Horizontal": [.resizeWE, .windowEW],
        "Diagonal1": [.windowNWSE],
        "Diagonal2": [.windowNESW],

        // Alternative names that might be used
        "Arrow": [.arrow],
        "IBeam": [.iBeam],
        "Hand": [.pointing],
        "Wait": [.wait],
        "Cross": [.crosshair],
        "No": [.forbidden],
        "SizeNS": [.resizeNS, .windowNS],
        "SizeWE": [.resizeWE, .windowEW],
        "SizeNWSE": [.windowNWSE],
        "SizeNESW": [.windowNESW],
        "SizeAll": [.move],
    ]

    /// Get macOS cursor types for a Windows cursor filename
    /// - Parameter windowsName: Filename (with or without extension)
    /// - Returns: Array of matching CursorType, empty if no match
    static func cursorTypes(for windowsName: String) -> [CursorType] {
        // Remove extension if present
        let name = windowsName
            .replacingOccurrences(of: ".cur", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: ".ani", with: "", options: .caseInsensitive)

        // Try exact match first
        if let types = mapping[name] {
            return types
        }

        // Try case-insensitive match
        let lowercaseName = name.lowercased()
        for (key, types) in mapping {
            if key.lowercased() == lowercaseName {
                return types
            }
        }

        return []
    }

    /// Check if a filename is a known Windows cursor
    static func isKnownCursor(_ windowsName: String) -> Bool {
        return !cursorTypes(for: windowsName).isEmpty
    }

    /// Get all supported Windows cursor names
    static var supportedCursorNames: [String] {
        return Array(mapping.keys).sorted()
    }
}
