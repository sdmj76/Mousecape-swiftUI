//
//  WindowsINFParser.swift
//  Mousecape
//
//  Parses Windows cursor install.inf files to extract cursor mappings.
//

import Foundation

/// Represents a parsed install.inf file with cursor mappings
struct WindowsINFMapping {
    /// Mapping from cursor type key (e.g., "pointer") to filename (e.g., "Normal.ani")
    let cursorFiles: [String: String]

    /// Scheme name from the INF
    let schemeName: String?

    /// Cursor directory from the INF
    let cursorDir: String?
}

/// Parser for Windows cursor install.inf files
struct WindowsINFParser {

    /// INF cursor key to macOS cursor type mapping
    /// These keys come from the [Strings] section of install.inf
    /// Based on Mac-Windows cursor comparison table
    /// Note: Some INF files use alternate key names (e.g., "work" vs "working", "cross" vs "precision")
    static let infKeyToMacOS: [String: [CursorType]] = [
        // Direct mappings from comparison table
        "pointer": [.arrow],           // Arrow
        "text": [.iBeam],              // IBeam
        "link": [.pointing],           // Pointing (Hand/Link cursor)
        "busy": [.busy],               // Busy (Wait in registry)
        "working": [.wait],            // Wait (AppStarting in registry)
        "work": [.wait],               // Alternate name for Wait
        "precision": [.crosshair],     // Crosshair
        "cross": [.crosshair],         // Alternate name for Crosshair
        "unavailable": [.forbidden],   // Forbidden
        "vert": [.resizeNS, .windowNS], // Resize N-S and Window N-S
        "horz": [.resizeWE, .windowEW], // Resize W-E and Window W-E
        "dgn1": [.windowNWSE],         // Window NW-SE (SizeNWSE)
        "dgn2": [.windowNESW],         // Window NE-SW (SizeNESW)
        "move": [.move],               // Move
        "help": [.help],               // Help
        // Windows-only cursors (no macOS equivalent) - skipped:
        // "alternate" (UpArrow), "hand" (NWPen/Handwriting), "person", "pin", "location"
    ]

    /// Parse an install.inf file
    /// - Parameter url: URL to the install.inf file
    /// - Returns: Parsed INF mapping, or nil if parsing failed
    static func parse(url: URL) -> WindowsINFMapping? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            // Try Windows codepage encoding
            guard let content = try? String(contentsOf: url, encoding: .windowsCP1252) else {
                return nil
            }
            return parseContent(content)
        }
        return parseContent(content)
    }

    /// Parse INF content string
    private static func parseContent(_ content: String) -> WindowsINFMapping? {
        var cursorFiles: [String: String] = [:]
        var schemeName: String?
        var cursorDir: String?

        // Find [Strings] section
        let lines = content.components(separatedBy: .newlines)
        var inStringsSection = false

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // Check for section headers
            if trimmedLine.hasPrefix("[") && trimmedLine.hasSuffix("]") {
                inStringsSection = trimmedLine.lowercased() == "[strings]"
                continue
            }

            // Parse lines in [Strings] section
            if inStringsSection && !trimmedLine.isEmpty && !trimmedLine.hasPrefix(";") {
                // Parse key = "value" format
                if let (key, value) = parseKeyValue(trimmedLine) {
                    let lowercaseKey = key.lowercased()

                    if lowercaseKey == "scheme_name" {
                        schemeName = value
                    } else if lowercaseKey == "cur_dir" {
                        cursorDir = value
                    } else if infKeyToMacOS[lowercaseKey] != nil {
                        // This is a cursor key - store the filename
                        cursorFiles[lowercaseKey] = value
                    }
                }
            }
        }

        guard !cursorFiles.isEmpty else { return nil }

        return WindowsINFMapping(
            cursorFiles: cursorFiles,
            schemeName: schemeName,
            cursorDir: cursorDir
        )
    }

    /// Parse a key = value line
    private static func parseKeyValue(_ line: String) -> (key: String, value: String)? {
        // Split on first = sign
        guard let equalsIndex = line.firstIndex(of: "=") else { return nil }

        let key = String(line[..<equalsIndex]).trimmingCharacters(in: .whitespaces)
        var value = String(line[line.index(after: equalsIndex)...]).trimmingCharacters(in: .whitespaces)

        // Remove quotes
        if value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2 {
            value = String(value.dropFirst().dropLast())
        }

        guard !key.isEmpty && !value.isEmpty else { return nil }

        return (key, value)
    }

    /// Get macOS cursor types for an INF key
    /// - Parameter infKey: Key from INF [Strings] section (e.g., "pointer", "help")
    /// - Returns: Array of matching CursorType
    static func cursorTypes(for infKey: String) -> [CursorType] {
        return infKeyToMacOS[infKey.lowercased()] ?? []
    }

    /// Find install.inf in a folder (case-insensitive)
    /// - Parameter folderURL: Folder to search in
    /// - Returns: URL to install.inf if found
    static func findINF(in folderURL: URL) -> URL? {
        let fileManager = FileManager.default

        guard let contents = try? fileManager.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        // Look for install.inf (case-insensitive)
        for url in contents {
            if url.lastPathComponent.lowercased() == "install.inf" {
                return url
            }
        }

        return nil
    }
}
