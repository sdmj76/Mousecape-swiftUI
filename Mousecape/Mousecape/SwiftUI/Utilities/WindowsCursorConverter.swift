//
//  WindowsCursorConverter.swift
//  Mousecape
//
//  Converts Windows .cur/.ani cursor files using native Swift parser.
//  No external dependencies required.
//

import Foundation
import AppKit

// MARK: - Conversion Result

/// Result from converting a Windows cursor file
struct WindowsCursorResult {
    let width: Int
    let height: Int
    let hotspotX: Int
    let hotspotY: Int
    let frameCount: Int
    let frameDuration: Double
    let imageData: Data  // PNG sprite sheet (for animated: frames stacked vertically)
    let filename: String // Original filename without extension
}

// MARK: - Conversion Error

enum WindowsCursorError: LocalizedError {
    case conversionFailed(String)
    case imageDecodeFailed

    var errorDescription: String? {
        switch self {
        case .conversionFailed(let message):
            return "Conversion failed: \(message)"
        case .imageDecodeFailed:
            return "Failed to decode image data"
        }
    }
}

// MARK: - Converter

/// Converts Windows cursor files (.cur, .ani) to Mousecape format
final class WindowsCursorConverter: @unchecked Sendable {

    /// Shared instance
    static let shared = WindowsCursorConverter()

    /// Nonisolated accessor for use from any context
    nonisolated static var instance: WindowsCursorConverter { shared }

    private init() {}

    // MARK: - Public API

    /// Convert a single cursor file
    /// - Parameter fileURL: URL to .cur or .ani file
    /// - Returns: Conversion result with image data
    func convert(fileURL: URL) throws -> WindowsCursorResult {
        let filename = fileURL.deletingPathExtension().lastPathComponent

        do {
            let parseResult = try WindowsCursorParser.parse(fileURL: fileURL)
            return try convertParseResult(parseResult, filename: filename)
        } catch let error as WindowsCursorParserError {
            throw WindowsCursorError.conversionFailed(error.localizedDescription)
        }
    }

    /// Convert all cursor files in a folder
    /// - Parameter folderURL: URL to folder containing .cur/.ani files
    /// - Returns: Array of conversion results
    func convertFolder(folderURL: URL) throws -> [WindowsCursorResult] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: folderURL, includingPropertiesForKeys: nil) else {
            throw WindowsCursorError.conversionFailed("Cannot enumerate folder")
        }

        var results: [WindowsCursorResult] = []

        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            if ext == "cur" || ext == "ani" {
                if let result = try? convert(fileURL: fileURL) {
                    results.append(result)
                }
            }
        }

        return results
    }

    /// Convert cursor files in a folder using INF mapping
    /// - Parameters:
    ///   - folderURL: URL to folder containing .cur/.ani files and install.inf
    ///   - infMapping: Parsed INF mapping from install.inf
    /// - Returns: Array of (infKey, result) tuples for successful conversions
    func convertFolderWithINF(folderURL: URL, infMapping: WindowsINFMapping) throws -> [(infKey: String, result: WindowsCursorResult)] {
        var results: [(infKey: String, result: WindowsCursorResult)] = []

        for (infKey, filename) in infMapping.cursorFiles {
            let fileURL = folderURL.appendingPathComponent(filename)

            // Check if file exists
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                print("INF referenced file not found: \(filename)")
                continue
            }

            // Convert the file
            do {
                let result = try convert(fileURL: fileURL)
                results.append((infKey: infKey, result: result))
            } catch {
                print("Failed to convert \(filename): \(error.localizedDescription)")
            }
        }

        return results
    }

    // MARK: - Async Public API

    /// Convert all cursor files in a folder asynchronously
    /// - Parameter folderURL: URL to folder containing .cur/.ani files
    /// - Returns: Array of conversion results
    func convertFolderAsync(folderURL: URL) async throws -> [WindowsCursorResult] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let results = try self.convertFolder(folderURL: folderURL)
                    continuation.resume(returning: results)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Convert cursor files in a folder asynchronously using INF mapping
    /// - Parameters:
    ///   - folderURL: URL to folder containing .cur/.ani files and install.inf
    ///   - infMapping: Parsed INF mapping from install.inf
    /// - Returns: Array of (infKey, result) tuples for successful conversions
    func convertFolderWithINFAsync(folderURL: URL, infMapping: WindowsINFMapping) async throws -> [(infKey: String, result: WindowsCursorResult)] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let results = try self.convertFolderWithINF(folderURL: folderURL, infMapping: infMapping)
                    continuation.resume(returning: results)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Private Methods

    /// Convert a parse result to WindowsCursorResult
    private func convertParseResult(_ parseResult: WindowsCursorParseResult, filename: String) throws -> WindowsCursorResult {
        guard let pngData = parseResult.pngData() else {
            throw WindowsCursorError.imageDecodeFailed
        }

        return WindowsCursorResult(
            width: parseResult.width,
            height: parseResult.height,
            hotspotX: parseResult.hotspotX,
            hotspotY: parseResult.hotspotY,
            frameCount: parseResult.frameCount,
            frameDuration: parseResult.frameDuration,
            imageData: pngData,
            filename: filename
        )
    }
}

// MARK: - NSBitmapImageRep Extension

extension WindowsCursorResult {

    /// Create NSBitmapImageRep from the result
    /// For animated cursors, returns a sprite sheet with all frames stacked vertically
    func createBitmapImageRep() -> NSBitmapImageRep? {
        guard let image = NSImage(data: imageData) else { return nil }

        // Get the bitmap representation
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        return NSBitmapImageRep(cgImage: cgImage)
    }

    /// Create MCCursor from the result
    func createMCCursor(identifier: String) -> MCCursor? {
        guard let bitmap = createBitmapImageRep() else { return nil }

        let cursor = MCCursor()
        cursor.identifier = identifier
        cursor.frameCount = UInt(frameCount)
        cursor.frameDuration = frameDuration
        cursor.size = NSSize(width: CGFloat(width), height: CGFloat(height))
        cursor.hotSpot = NSPoint(x: CGFloat(hotspotX), y: CGFloat(hotspotY))

        // Set representation for 2x scale (standard HiDPI)
        cursor.setRepresentation(bitmap, for: MCCursorScale(rawValue: 200)!)

        return cursor
    }
}
