//
//  WindowsINFParser.swift
//  Mousecape
//
//  Parses Windows cursor install.inf files to extract cursor mappings.
//  Uses [Scheme.Reg] position-based mapping for reliable cursor type detection.
//

import Foundation

/// Represents a parsed install.inf file with cursor mappings
struct WindowsINFMapping {
    /// Mapping from position index (0-16) to filename
    let cursorFilesByPosition: [Int: String]

    /// Scheme name from the INF
    let schemeName: String?

    /// Cursor directory from the INF
    let cursorDir: String?
}

/// INF parsing error with detailed reason
enum INFParseError: Error, LocalizedError {
    case fileNotFound(String)
    case encodingError(String)
    case noSchemeRegSection
    case noCursorPaths
    case noValidCursors

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "INF file not found: \(path)"
        case .encodingError(let path):
            return "Failed to read INF file (encoding error): \(path)"
        case .noSchemeRegSection:
            return "No [Scheme.Reg] section found in INF file"
        case .noCursorPaths:
            return "No cursor paths found in [Scheme.Reg]"
        case .noValidCursors:
            return "No valid cursor filenames could be resolved"
        }
    }
}

/// Parser for Windows cursor install.inf files
struct WindowsINFParser {

    /// Windows registry fixed-order cursor type mapping (positions 0-16)
    /// Based on Windows Control Panel\Cursors\Schemes registry format
    static let schemeRegPositionMapping: [[CursorType]] = [
        [.arrow, .arrowCtx],           // 0: Normal Select
        [.help],                        // 1: Help Select
        [.wait],                        // 2: Working in Background
        [.busy],                        // 3: Busy
        [.crosshair],                   // 4: Precision Select
        [.iBeam, .iBeamXOR],           // 5: Text Select
        [.open],                        // 6: Handwriting (com.apple.cursor.12)
        [.forbidden],                   // 7: Unavailable
        [.resizeNS, .windowNS],        // 8: Vertical Resize
        [.resizeWE, .windowEW],        // 9: Horizontal Resize
        [.windowNWSE],                  // 10: Diagonal Resize 1 (NW-SE)
        [.windowNESW],                  // 11: Diagonal Resize 2 (NE-SW)
        [.move],                        // 12: Move
        [.alias],                       // 13: Alternate Select
        [.pointing, .link],            // 14: Link Select
        [],                             // 15: Location Select (no macOS equivalent)
        [],                             // 16: Person Select (no macOS equivalent)
    ]

    /// Parse an install.inf file
    /// - Parameter url: URL to the .inf file
    /// - Returns: Result with parsed INF mapping or error reason
    static func parse(url: URL) -> Result<WindowsINFMapping, INFParseError> {
        debugLog("=== Parsing Windows INF ===")
        debugLog("File: \(url.lastPathComponent)")

        // Check if file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            debugLog("Error: INF file not found")
            return .failure(.fileNotFound(url.lastPathComponent))
        }

        // Read file as ASCII, replacing invalid characters
        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .ascii) else {
            debugLog("Error: Failed to read INF file (encoding error)")
            return .failure(.encodingError(url.lastPathComponent))
        }

        debugLog("Read with ASCII encoding")
        return parseContent(content)
    }

    /// Parse INF content string
    private static func parseContent(_ content: String) -> Result<WindowsINFMapping, INFParseError> {
        debugLog("Parsing INF content (\(content.count) chars)")

        let lines = content.components(separatedBy: .newlines)

        // Step 1: Parse [Scheme.Reg] section to get cursor paths
        guard let schemeRegLine = findSchemeRegLine(lines) else {
            debugLog("Error: No [Scheme.Reg] section found")
            return .failure(.noSchemeRegSection)
        }

        // Step 2: Extract cursor paths from Scheme.Reg
        let cursorPaths = extractCursorPaths(from: schemeRegLine)
        guard !cursorPaths.isEmpty else {
            debugLog("Error: No cursor paths found in [Scheme.Reg]")
            return .failure(.noCursorPaths)
        }

        // Step 3: Parse [Strings] section (optional, for variable resolution)
        let strings = parseStringsSection(lines)

        // Step 4: Build position-to-filename mapping
        var cursorFilesByPosition: [Int: String] = [:]
        for (position, path) in cursorPaths.enumerated() {
            if let filename = resolveFilename(from: path, strings: strings) {
                cursorFilesByPosition[position] = filename
            }
            // Skip invalid paths silently
        }

        guard !cursorFilesByPosition.isEmpty else {
            debugLog("Error: No valid cursor filenames could be resolved")
            return .failure(.noValidCursors)
        }

        debugLog("INF parse result: \(cursorFilesByPosition.count) cursor mappings")
        for (position, filename) in cursorFilesByPosition.sorted(by: { $0.key < $1.key }) {
            debugLog("  Position \(position) -> \(filename)")
        }
        if let scheme = strings["scheme_name"] {
            debugLog("Scheme name: \(scheme)")
        }

        return .success(WindowsINFMapping(
            cursorFilesByPosition: cursorFilesByPosition,
            schemeName: strings["scheme_name"],
            cursorDir: strings["cur_dir"]
        ))
    }

    /// Find the HKCU,"Control Panel\Cursors\Schemes" line in [Scheme.Reg] section
    private static func findSchemeRegLine(_ lines: [String]) -> String? {
        var inSchemeRegSection = false

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // Check for section headers
            if trimmedLine.hasPrefix("[") && trimmedLine.hasSuffix("]") {
                inSchemeRegSection = trimmedLine.lowercased() == "[scheme.reg]"
                continue
            }

            // Look for the Cursors\Schemes line
            if inSchemeRegSection && !trimmedLine.isEmpty && !trimmedLine.hasPrefix(";") {
                let lowercased = trimmedLine.lowercased()
                if lowercased.contains("control panel\\cursors\\schemes") ||
                   lowercased.contains("control panel\\\\cursors\\\\schemes") {
                    return trimmedLine
                }
            }
        }

        return nil
    }

    /// Extract cursor paths from Scheme.Reg line
    /// Input: HKCU,"Control Panel\Cursors\Schemes","%SCHEME_NAME%",,"%10%\%CUR_DIR%\%pointer%,%10%\%CUR_DIR%\Normal.ani,..."
    /// Output: ["%10%\%CUR_DIR%\%pointer%", "%10%\%CUR_DIR%\Normal.ani", ...]
    private static func extractCursorPaths(from schemeRegLine: String) -> [String] {
        // Split by ",," to find the cursor list part (after the empty field)
        let parts = schemeRegLine.components(separatedBy: ",,")
        guard parts.count >= 2 else { return [] }

        // Get the cursor list part (everything after ",,")
        let cursorListPart = parts.dropFirst().joined(separator: ",,")

        // Remove surrounding quotes if present
        var cursorList = cursorListPart.trimmingCharacters(in: .whitespaces)
        if cursorList.hasPrefix("\"") && cursorList.hasSuffix("\"") && cursorList.count >= 2 {
            cursorList = String(cursorList.dropFirst().dropLast())
        }

        // Split by comma to get individual cursor paths
        return cursorList.components(separatedBy: ",")
    }

    /// Resolve filename from a cursor path
    /// - If path ends with %variable%, look up in strings
    /// - If path ends with filename.ext, use directly
    private static func resolveFilename(from path: String, strings: [String: String]) -> String? {
        let trimmedPath = path.trimmingCharacters(in: .whitespaces)
        guard !trimmedPath.isEmpty else { return nil }

        // Get the last component (after last \ or /)
        let lastComponent: String
        if let lastBackslash = trimmedPath.lastIndex(of: "\\") {
            lastComponent = String(trimmedPath[trimmedPath.index(after: lastBackslash)...])
        } else if let lastSlash = trimmedPath.lastIndex(of: "/") {
            lastComponent = String(trimmedPath[trimmedPath.index(after: lastSlash)...])
        } else {
            lastComponent = trimmedPath
        }

        // Check if it's a variable reference like %pointer%
        if lastComponent.hasPrefix("%") && lastComponent.hasSuffix("%") && lastComponent.count > 2 {
            // Extract variable name and look up in strings
            let varName = String(lastComponent.dropFirst().dropLast()).lowercased()
            return strings[varName]
        }

        // Otherwise, it's a direct filename - just clean it up
        let filename = lastComponent
        // Remove any remaining % markers that might be path variables
        if filename.contains("%") {
            return nil // Invalid format
        }
        return filename.isEmpty ? nil : filename
    }

    /// Parse [Strings] section to get all variable definitions (optional)
    private static func parseStringsSection(_ lines: [String]) -> [String: String] {
        var strings: [String: String] = [:]
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
                if let (key, value) = parseKeyValue(trimmedLine) {
                    strings[key.lowercased()] = value
                }
            }
        }

        return strings
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

    /// Get macOS cursor types for a position index
    /// - Parameter position: Position index (0-16) from Scheme.Reg
    /// - Returns: Array of matching CursorType
    static func cursorTypes(forPosition position: Int) -> [CursorType] {
        guard position >= 0 && position < schemeRegPositionMapping.count else {
            return []
        }
        return schemeRegPositionMapping[position]
    }

    /// Find and parse a valid INF file in a folder
    /// Searches for all *.inf files and returns the first one with valid [Scheme.Reg]
    /// - Parameter folderURL: Folder to search in
    /// - Returns: Result with parsed INF mapping or last error encountered
    static func findValidINF(in folderURL: URL) -> Result<WindowsINFMapping, INFParseError> {
        let fileManager = FileManager.default

        guard let contents = try? fileManager.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return .failure(.fileNotFound(folderURL.lastPathComponent))
        }

        // Find all .inf files
        let infFiles = contents.filter { $0.pathExtension.lowercased() == "inf" }

        guard !infFiles.isEmpty else {
            return .failure(.fileNotFound("*.inf"))
        }

        // Try each INF file until we find a valid one
        var lastError: INFParseError = .noSchemeRegSection
        for infURL in infFiles {
            switch parse(url: infURL) {
            case .success(let mapping):
                return .success(mapping)
            case .failure(let error):
                lastError = error
            }
        }

        return .failure(lastError)
    }
}
