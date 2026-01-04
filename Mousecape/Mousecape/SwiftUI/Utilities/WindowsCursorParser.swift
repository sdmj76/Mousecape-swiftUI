//
//  WindowsCursorParser.swift
//  Mousecape
//
//  Native Swift parser for Windows .cur and .ani cursor files.
//  Replaces the Python-based curconvert.py for zero external dependencies.
//

import Foundation
import AppKit
import ImageIO

// MARK: - Parser Errors

enum WindowsCursorParserError: LocalizedError {
    case fileNotFound
    case invalidFormat(String)
    case unsupportedFormat(String)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Cursor file not found"
        case .invalidFormat(let message):
            return "Invalid cursor format: \(message)"
        case .unsupportedFormat(let message):
            return "Unsupported format: \(message)"
        case .decodingFailed(let message):
            return "Failed to decode cursor: \(message)"
        }
    }
}

// MARK: - Parser Result

/// Result from parsing a Windows cursor file
struct WindowsCursorParseResult {
    let image: CGImage
    let width: Int
    let height: Int
    let hotspotX: Int
    let hotspotY: Int
    let frameCount: Int
    let frameDuration: Double

    /// Convert to PNG data
    func pngData() -> Data? {
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, "public.png" as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        return mutableData as Data
    }
}

// MARK: - Binary Reader Helper

/// Helper for reading binary data with Little Endian byte order
private struct BinaryReader {
    let data: Data
    var offset: Int = 0

    init(_ data: Data) {
        self.data = data
    }

    var remaining: Int {
        return data.count - offset
    }

    mutating func readUInt8() throws -> UInt8 {
        guard offset + 1 <= data.count else {
            throw WindowsCursorParserError.invalidFormat("Unexpected end of data")
        }
        let value = data[offset]
        offset += 1
        return value
    }

    mutating func readUInt16() throws -> UInt16 {
        guard offset + 2 <= data.count else {
            throw WindowsCursorParserError.invalidFormat("Unexpected end of data")
        }
        // Read bytes individually to avoid alignment issues
        let b0 = UInt16(data[offset])
        let b1 = UInt16(data[offset + 1])
        offset += 2
        // Little endian: low byte first
        return b0 | (b1 << 8)
    }

    mutating func readUInt32() throws -> UInt32 {
        guard offset + 4 <= data.count else {
            throw WindowsCursorParserError.invalidFormat("Unexpected end of data")
        }
        // Read bytes individually to avoid alignment issues
        let b0 = UInt32(data[offset])
        let b1 = UInt32(data[offset + 1])
        let b2 = UInt32(data[offset + 2])
        let b3 = UInt32(data[offset + 3])
        offset += 4
        // Little endian: low byte first
        return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
    }

    mutating func readInt32() throws -> Int32 {
        let unsigned = try readUInt32()
        return Int32(bitPattern: unsigned)
    }

    mutating func readBytes(_ count: Int) throws -> Data {
        guard offset + count <= data.count else {
            throw WindowsCursorParserError.invalidFormat("Unexpected end of data")
        }
        let bytes = data.subdata(in: offset..<(offset + count))
        offset += count
        return bytes
    }

    mutating func skip(_ count: Int) throws {
        guard offset + count <= data.count else {
            throw WindowsCursorParserError.invalidFormat("Unexpected end of data")
        }
        offset += count
    }

    mutating func seek(to position: Int) throws {
        guard position >= 0 && position <= data.count else {
            throw WindowsCursorParserError.invalidFormat("Invalid seek position")
        }
        offset = position
    }

    func peekBytes(_ count: Int) -> Data? {
        guard offset + count <= data.count else { return nil }
        return data.subdata(in: offset..<(offset + count))
    }
}

// MARK: - ICONDIR Entry

private struct IconDirEntry {
    let width: Int      // 0 means 256
    let height: Int     // 0 means 256
    let colorCount: Int
    let reserved: Int
    let hotspotX: Int   // For cursors: hotspot X
    let hotspotY: Int   // For cursors: hotspot Y
    let imageSize: Int
    let imageOffset: Int
}

// MARK: - Main Parser

/// Native Swift parser for Windows cursor files
struct WindowsCursorParser {

    // MARK: - Public API

    /// Parse a cursor file from URL
    static func parse(fileURL: URL) throws -> WindowsCursorParseResult {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw WindowsCursorParserError.fileNotFound
        }

        let data = try Data(contentsOf: fileURL)
        let ext = fileURL.pathExtension.lowercased()

        switch ext {
        case "cur":
            return try parseCUR(data: data)
        case "ani":
            return try parseANI(data: data)
        default:
            throw WindowsCursorParserError.unsupportedFormat("Unknown extension: \(ext)")
        }
    }

    /// Parse a folder of cursor files
    static func parseFolder(folderURL: URL) throws -> [WindowsCursorParseResult] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: folderURL, includingPropertiesForKeys: nil) else {
            throw WindowsCursorParserError.invalidFormat("Cannot enumerate folder")
        }

        var results: [WindowsCursorParseResult] = []

        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            if ext == "cur" || ext == "ani" {
                if let result = try? parse(fileURL: fileURL) {
                    results.append(result)
                }
            }
        }

        return results
    }

    // MARK: - CUR Parsing

    /// Parse a .cur (static cursor) file
    static func parseCUR(data: Data) throws -> WindowsCursorParseResult {
        var reader = BinaryReader(data)

        // Read ICONDIR header
        let reserved = try reader.readUInt16()
        let imageType = try reader.readUInt16()
        let imageCount = try reader.readUInt16()

        guard reserved == 0 else {
            throw WindowsCursorParserError.invalidFormat("Invalid reserved field")
        }

        guard imageType == 2 else {
            throw WindowsCursorParserError.invalidFormat("Not a cursor file (type=\(imageType), expected 2)")
        }

        guard imageCount >= 1 else {
            throw WindowsCursorParserError.invalidFormat("No cursor images in file")
        }

        // Read all ICONDIRENTRY entries
        var entries: [IconDirEntry] = []
        for _ in 0..<imageCount {
            let width = Int(try reader.readUInt8())
            let height = Int(try reader.readUInt8())
            let colorCount = Int(try reader.readUInt8())
            let reserved = Int(try reader.readUInt8())
            let hotspotX = Int(try reader.readUInt16())
            let hotspotY = Int(try reader.readUInt16())
            let imageSize = Int(try reader.readUInt32())
            let imageOffset = Int(try reader.readUInt32())

            entries.append(IconDirEntry(
                width: width == 0 ? 256 : width,
                height: height == 0 ? 256 : height,
                colorCount: colorCount,
                reserved: reserved,
                hotspotX: hotspotX,
                hotspotY: hotspotY,
                imageSize: imageSize,
                imageOffset: imageOffset
            ))
        }

        // Choose the largest image (prefer higher resolution)
        guard let bestEntry = entries.max(by: { $0.width * $0.height < $1.width * $1.height }) else {
            throw WindowsCursorParserError.invalidFormat("No valid entries")
        }

        // Read image data
        try reader.seek(to: bestEntry.imageOffset)
        let imageData = try reader.readBytes(bestEntry.imageSize)

        // Decode the image
        let cgImage = try decodeImageData(imageData, width: bestEntry.width, height: bestEntry.height)

        return WindowsCursorParseResult(
            image: cgImage,
            width: cgImage.width,
            height: cgImage.height,
            hotspotX: bestEntry.hotspotX,
            hotspotY: bestEntry.hotspotY,
            frameCount: 1,
            frameDuration: 0.0
        )
    }

    // MARK: - ANI Parsing

    /// Parse a .ani (animated cursor) file
    static func parseANI(data: Data) throws -> WindowsCursorParseResult {
        var reader = BinaryReader(data)

        // Verify RIFF header
        let riffHeader = try reader.readBytes(4)
        guard riffHeader == Data("RIFF".utf8) else {
            throw WindowsCursorParserError.invalidFormat("Not a valid RIFF file")
        }

        let _ = try reader.readUInt32() // file size

        let aconType = try reader.readBytes(4)
        guard aconType == Data("ACON".utf8) else {
            throw WindowsCursorParserError.invalidFormat("Not an animated cursor file")
        }

        // Parse chunks
        var anihData: ANIHeader?
        var rateData: [UInt32]?
        var frames: [FrameData] = []

        while reader.remaining >= 8 {
            let chunkID = try reader.readBytes(4)
            let chunkSize = Int(try reader.readUInt32())

            if chunkID == Data("anih".utf8) {
                anihData = try parseANIHChunk(reader: &reader, size: chunkSize)
            } else if chunkID == Data("rate".utf8) {
                let numFrames = anihData?.numFrames ?? 0
                rateData = try parseRateChunk(reader: &reader, size: chunkSize, numFrames: numFrames)
            } else if chunkID == Data("LIST".utf8) {
                let listType = try reader.readBytes(4)
                if listType == Data("fram".utf8) {
                    frames = try parseFramList(reader: &reader, size: chunkSize - 4)
                } else {
                    try reader.skip(chunkSize - 4)
                }
            } else {
                try reader.skip(chunkSize)
            }

            // Pad to even boundary
            if chunkSize % 2 == 1 && reader.remaining > 0 {
                try reader.skip(1)
            }
        }

        guard !frames.isEmpty else {
            throw WindowsCursorParserError.invalidFormat("No frames found in ANI file")
        }

        // Use default values if anih not found
        let header = anihData ?? ANIHeader(
            headerSize: 36,
            numFrames: UInt32(frames.count),
            numSteps: UInt32(frames.count),
            width: 0,
            height: 0,
            bitCount: 0,
            numPlanes: 0,
            displayRate: 10,
            flags: 0
        )

        // Calculate frame duration (jiffies to seconds, 1 jiffy = 1/60 sec)
        let frameDuration: Double
        if let rates = rateData, !rates.isEmpty {
            let avgRate = Double(rates.reduce(0, +)) / Double(rates.count)
            frameDuration = avgRate / 60.0
        } else {
            frameDuration = Double(header.displayRate) / 60.0
        }

        // Get dimensions from first frame
        guard let firstFrame = frames.first else {
            throw WindowsCursorParserError.invalidFormat("No valid frames")
        }

        let frameWidth = firstFrame.image.width
        let frameHeight = firstFrame.image.height

        // Create sprite sheet (all frames stacked vertically)
        let spriteSheet = try createSpriteSheet(frames: frames, width: frameWidth, height: frameHeight)

        return WindowsCursorParseResult(
            image: spriteSheet,
            width: frameWidth,
            height: frameHeight,
            hotspotX: firstFrame.hotspotX,
            hotspotY: firstFrame.hotspotY,
            frameCount: frames.count,
            frameDuration: frameDuration
        )
    }

    // MARK: - ANI Chunk Parsing

    private struct ANIHeader {
        let headerSize: UInt32
        let numFrames: UInt32
        let numSteps: UInt32
        let width: UInt32
        let height: UInt32
        let bitCount: UInt32
        let numPlanes: UInt32
        let displayRate: UInt32
        let flags: UInt32
    }

    private struct FrameData {
        let image: CGImage
        let hotspotX: Int
        let hotspotY: Int
    }

    private static func parseANIHChunk(reader: inout BinaryReader, size: Int) throws -> ANIHeader {
        guard size >= 36 else {
            try reader.skip(size)
            return ANIHeader(headerSize: 36, numFrames: 1, numSteps: 1, width: 0, height: 0, bitCount: 0, numPlanes: 0, displayRate: 10, flags: 0)
        }

        let headerSize = try reader.readUInt32()
        let numFrames = try reader.readUInt32()
        let numSteps = try reader.readUInt32()
        let width = try reader.readUInt32()
        let height = try reader.readUInt32()
        let bitCount = try reader.readUInt32()
        let numPlanes = try reader.readUInt32()
        let displayRate = try reader.readUInt32()
        let flags = try reader.readUInt32()

        // Skip remaining bytes if any
        if size > 36 {
            try reader.skip(size - 36)
        }

        return ANIHeader(
            headerSize: headerSize,
            numFrames: numFrames,
            numSteps: numSteps,
            width: width,
            height: height,
            bitCount: bitCount,
            numPlanes: numPlanes,
            displayRate: displayRate,
            flags: flags
        )
    }

    private static func parseRateChunk(reader: inout BinaryReader, size: Int, numFrames: UInt32) throws -> [UInt32] {
        var rates: [UInt32] = []
        let count = min(Int(numFrames), size / 4)

        for _ in 0..<count {
            let rate = try reader.readUInt32()
            rates.append(rate)
        }

        // Skip remaining bytes
        let remaining = size - (count * 4)
        if remaining > 0 {
            try reader.skip(remaining)
        }

        return rates
    }

    private static func parseFramList(reader: inout BinaryReader, size: Int) throws -> [FrameData] {
        var frames: [FrameData] = []
        let endOffset = reader.offset + size

        while reader.offset < endOffset - 8 {
            let chunkID = try reader.readBytes(4)
            let chunkSize = Int(try reader.readUInt32())

            if chunkID == Data("icon".utf8) {
                let iconData = try reader.readBytes(chunkSize)
                if let frame = try? parseIconChunk(data: iconData) {
                    frames.append(frame)
                }
            } else {
                try reader.skip(chunkSize)
            }

            // Pad to even boundary
            if chunkSize % 2 == 1 && reader.offset < endOffset {
                try reader.skip(1)
            }
        }

        return frames
    }

    private static func parseIconChunk(data: Data) throws -> FrameData {
        var reader = BinaryReader(data)

        // Read ICONDIR header
        let reserved = try reader.readUInt16()
        let imageType = try reader.readUInt16()
        let imageCount = try reader.readUInt16()

        guard reserved == 0 && imageType >= 1 && imageType <= 2 && imageCount >= 1 else {
            throw WindowsCursorParserError.invalidFormat("Invalid icon chunk")
        }

        // Read first ICONDIRENTRY
        let width = Int(try reader.readUInt8())
        let height = Int(try reader.readUInt8())
        let _ = try reader.readUInt8() // colorCount
        let _ = try reader.readUInt8() // reserved
        let hotspotX = Int(try reader.readUInt16())
        let hotspotY = Int(try reader.readUInt16())
        let imageSize = Int(try reader.readUInt32())
        let imageOffset = Int(try reader.readUInt32())

        let actualWidth = width == 0 ? 256 : width
        let actualHeight = height == 0 ? 256 : height

        guard imageOffset + imageSize <= data.count else {
            throw WindowsCursorParserError.invalidFormat("Invalid image offset in icon chunk")
        }

        let imageData = data.subdata(in: imageOffset..<(imageOffset + imageSize))
        let cgImage = try decodeImageData(imageData, width: actualWidth, height: actualHeight)

        return FrameData(image: cgImage, hotspotX: hotspotX, hotspotY: hotspotY)
    }

    // MARK: - Image Decoding

    /// Decode image data (PNG or BMP/DIB format)
    private static func decodeImageData(_ data: Data, width: Int, height: Int) throws -> CGImage {
        // Check for PNG signature
        let pngSignature = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        if data.prefix(8) == pngSignature {
            return try decodePNG(data: data)
        }

        // Otherwise it's BMP/DIB format
        return try decodeBMPCursor(data: data, width: width, height: height)
    }

    /// Decode PNG data
    private static func decodePNG(data: Data) throws -> CGImage {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw WindowsCursorParserError.decodingFailed("Failed to decode PNG")
        }
        return cgImage
    }

    /// Decode BMP/DIB cursor image data
    private static func decodeBMPCursor(data: Data, width: Int, height: Int) throws -> CGImage {
        var reader = BinaryReader(data)

        // Read BITMAPINFOHEADER (40 bytes standard)
        let headerSize = try reader.readUInt32()
        let bmpWidth = Int(try reader.readInt32())
        let bmpHeight = Int(try reader.readInt32())  // Doubled for XOR+AND masks
        let _ = try reader.readUInt16() // planes (unused)
        let bitCount = try reader.readUInt16()
        let compression = try reader.readUInt32()
        let _ = try reader.readUInt32() // imageSize
        let _ = try reader.readInt32()  // xPelsPerMeter
        let _ = try reader.readInt32()  // yPelsPerMeter
        let clrUsed = try reader.readUInt32()  // biClrUsed - actual number of colors in palette
        let _ = try reader.readUInt32() // clrImportant

        // Skip any remaining header bytes (for BITMAPV4/V5 headers)
        if headerSize > 40 {
            try reader.skip(Int(headerSize) - 40)
        }

        // Actual height is half (top half is XOR, bottom half is AND)
        let actualHeight = abs(bmpHeight) / 2
        let actualWidth = bmpWidth > 0 ? bmpWidth : width

        // Calculate actual palette size
        let paletteSize: Int
        if bitCount <= 8 {
            if clrUsed > 0 {
                paletteSize = Int(clrUsed)
            } else {
                paletteSize = 1 << Int(bitCount)  // 2^bitCount
            }
        } else {
            paletteSize = 0
        }

        // Handle RLE compression
        if compression == 1 && bitCount == 8 {
            // RLE8 compression
            return try decodeRLE8BMP(reader: &reader, width: actualWidth, height: actualHeight, paletteSize: paletteSize)
        } else if compression == 2 && bitCount == 4 {
            // RLE4 compression
            return try decodeRLE4BMP(reader: &reader, width: actualWidth, height: actualHeight, paletteSize: paletteSize)
        }

        switch bitCount {
        case 32:
            return try decode32BitBMP(reader: &reader, width: actualWidth, height: actualHeight)
        case 24:
            return try decode24BitBMP(reader: &reader, width: actualWidth, height: actualHeight)
        case 16:
            return try decode16BitBMP(reader: &reader, width: actualWidth, height: actualHeight, compression: compression)
        case 8:
            return try decode8BitBMP(reader: &reader, width: actualWidth, height: actualHeight, paletteSize: paletteSize)
        case 4:
            return try decode4BitBMP(reader: &reader, width: actualWidth, height: actualHeight, paletteSize: paletteSize)
        case 1:
            return try decode1BitBMP(reader: &reader, width: actualWidth, height: actualHeight, paletteSize: paletteSize)
        default:
            // For other bit depths, try using ImageIO with a BMP header wrapper
            return try decodeBMPWithHeader(data: data, width: width, height: height)
        }
    }

    /// Decode 16-bit RGB BMP (RGB555 or RGB565)
    private static func decode16BitBMP(reader: inout BinaryReader, width: Int, height: Int, compression: UInt32) throws -> CGImage {
        let rowSize = ((width * 2 + 3) / 4) * 4  // Padded to 4 bytes
        let padding = rowSize - width * 2

        var pixelData = Data(count: width * height * 4)

        // Determine format: compression=0 is RGB555, compression=3 is bitfields (usually RGB565)
        let isRGB565 = (compression == 3)

        // Read color data (bottom-to-top)
        for y in 0..<height {
            let targetY = height - 1 - y

            for x in 0..<width {
                let pixel = try reader.readUInt16()

                let r: UInt8
                let g: UInt8
                let b: UInt8

                if isRGB565 {
                    // RGB565: RRRRRGGGGGGBBBBB
                    r = UInt8((pixel >> 11) & 0x1F) << 3
                    g = UInt8((pixel >> 5) & 0x3F) << 2
                    b = UInt8(pixel & 0x1F) << 3
                } else {
                    // RGB555: XRRRRRGGGGGBBBBB
                    r = UInt8((pixel >> 10) & 0x1F) << 3
                    g = UInt8((pixel >> 5) & 0x1F) << 3
                    b = UInt8(pixel & 0x1F) << 3
                }

                let offset = (targetY * width + x) * 4
                pixelData[offset] = r
                pixelData[offset + 1] = g
                pixelData[offset + 2] = b
                pixelData[offset + 3] = 255
            }

            // Skip padding
            if padding > 0 {
                try reader.skip(padding)
            }
        }

        // Read AND mask (1-bit transparency)
        let andRowSize = ((width + 31) / 32) * 4

        for y in 0..<height {
            let targetY = height - 1 - y

            for byteIndex in 0..<andRowSize {
                let maskByte: UInt8
                if reader.remaining > 0 {
                    maskByte = try reader.readUInt8()
                } else {
                    break
                }

                for bit in 0..<8 {
                    let x = byteIndex * 8 + bit
                    if x >= width { break }

                    let isTransparent = (maskByte >> (7 - bit)) & 1 == 1
                    if isTransparent {
                        let offset = (targetY * width + x) * 4
                        pixelData[offset + 3] = 0
                    }
                }
            }
        }

        return try createCGImage(from: pixelData, width: width, height: height)
    }

    /// Decode RLE8 compressed 8-bit BMP
    private static func decodeRLE8BMP(reader: inout BinaryReader, width: Int, height: Int, paletteSize: Int) throws -> CGImage {
        // Read color palette
        let actualPaletteSize = paletteSize > 0 ? min(paletteSize, 256) : 256
        var palette: [(r: UInt8, g: UInt8, b: UInt8, a: UInt8)] = []
        for _ in 0..<actualPaletteSize {
            let b = try reader.readUInt8()
            let g = try reader.readUInt8()
            let r = try reader.readUInt8()
            let _ = try reader.readUInt8()
            palette.append((r: r, g: g, b: b, a: 255))
        }

        var pixelData = Data(repeating: 0, count: width * height * 4)
        var x = 0
        var y = height - 1  // Start from bottom

        while reader.remaining >= 2 {
            let count = Int(try reader.readUInt8())
            let value = try reader.readUInt8()

            if count > 0 {
                // Encoded mode: repeat 'value' 'count' times
                let color = Int(value) < palette.count ? palette[Int(value)] : (r: UInt8(0), g: UInt8(0), b: UInt8(0), a: UInt8(255))
                for _ in 0..<count {
                    if x < width && y >= 0 {
                        let offset = (y * width + x) * 4
                        pixelData[offset] = color.r
                        pixelData[offset + 1] = color.g
                        pixelData[offset + 2] = color.b
                        pixelData[offset + 3] = color.a
                        x += 1
                    }
                }
            } else {
                // Escape mode
                switch value {
                case 0:
                    // End of line
                    x = 0
                    y -= 1
                case 1:
                    // End of bitmap
                    break
                case 2:
                    // Delta
                    if reader.remaining >= 2 {
                        let dx = Int(try reader.readUInt8())
                        let dy = Int(try reader.readUInt8())
                        x += dx
                        y -= dy
                    }
                default:
                    // Absolute mode: 'value' literal bytes follow
                    let literalCount = Int(value)
                    for _ in 0..<literalCount {
                        if reader.remaining > 0 && x < width && y >= 0 {
                            let index = Int(try reader.readUInt8())
                            let color = index < palette.count ? palette[index] : (r: UInt8(0), g: UInt8(0), b: UInt8(0), a: UInt8(255))
                            let offset = (y * width + x) * 4
                            pixelData[offset] = color.r
                            pixelData[offset + 1] = color.g
                            pixelData[offset + 2] = color.b
                            pixelData[offset + 3] = color.a
                            x += 1
                        }
                    }
                    // Padding to word boundary
                    if literalCount % 2 == 1 && reader.remaining > 0 {
                        _ = try reader.readUInt8()
                    }
                }
            }
        }

        // Read AND mask
        let andRowSize = ((width + 31) / 32) * 4
        for row in 0..<height {
            let targetY = height - 1 - row
            for byteIndex in 0..<andRowSize {
                if reader.remaining > 0 {
                    let maskByte = try reader.readUInt8()
                    for bit in 0..<8 {
                        let px = byteIndex * 8 + bit
                        if px >= width { break }
                        let isTransparent = (maskByte >> (7 - bit)) & 1 == 1
                        if isTransparent {
                            let offset = (targetY * width + px) * 4
                            pixelData[offset + 3] = 0
                        }
                    }
                }
            }
        }

        return try createCGImage(from: pixelData, width: width, height: height)
    }

    /// Decode RLE4 compressed 4-bit BMP
    private static func decodeRLE4BMP(reader: inout BinaryReader, width: Int, height: Int, paletteSize: Int) throws -> CGImage {
        // Read color palette
        let actualPaletteSize = paletteSize > 0 ? min(paletteSize, 16) : 16
        var palette: [(r: UInt8, g: UInt8, b: UInt8, a: UInt8)] = []
        for _ in 0..<actualPaletteSize {
            let b = try reader.readUInt8()
            let g = try reader.readUInt8()
            let r = try reader.readUInt8()
            let _ = try reader.readUInt8()
            palette.append((r: r, g: g, b: b, a: 255))
        }

        var pixelData = Data(repeating: 0, count: width * height * 4)
        var x = 0
        var y = height - 1

        while reader.remaining >= 2 {
            let count = Int(try reader.readUInt8())
            let value = try reader.readUInt8()

            if count > 0 {
                // Encoded mode: alternate between high and low nibbles
                let highIndex = Int((value >> 4) & 0x0F)
                let lowIndex = Int(value & 0x0F)
                let highColor = highIndex < palette.count ? palette[highIndex] : (r: UInt8(0), g: UInt8(0), b: UInt8(0), a: UInt8(255))
                let lowColor = lowIndex < palette.count ? palette[lowIndex] : (r: UInt8(0), g: UInt8(0), b: UInt8(0), a: UInt8(255))

                for i in 0..<count {
                    if x < width && y >= 0 {
                        let color = (i % 2 == 0) ? highColor : lowColor
                        let offset = (y * width + x) * 4
                        pixelData[offset] = color.r
                        pixelData[offset + 1] = color.g
                        pixelData[offset + 2] = color.b
                        pixelData[offset + 3] = color.a
                        x += 1
                    }
                }
            } else {
                switch value {
                case 0:
                    x = 0
                    y -= 1
                case 1:
                    break
                case 2:
                    if reader.remaining >= 2 {
                        let dx = Int(try reader.readUInt8())
                        let dy = Int(try reader.readUInt8())
                        x += dx
                        y -= dy
                    }
                default:
                    // Absolute mode
                    let literalCount = Int(value)
                    let bytesToRead = (literalCount + 1) / 2
                    for i in 0..<bytesToRead {
                        if reader.remaining > 0 {
                            let byte = try reader.readUInt8()
                            let highIndex = Int((byte >> 4) & 0x0F)
                            let lowIndex = Int(byte & 0x0F)

                            if x < width && y >= 0 && i * 2 < literalCount {
                                let color = highIndex < palette.count ? palette[highIndex] : (r: UInt8(0), g: UInt8(0), b: UInt8(0), a: UInt8(255))
                                let offset = (y * width + x) * 4
                                pixelData[offset] = color.r
                                pixelData[offset + 1] = color.g
                                pixelData[offset + 2] = color.b
                                pixelData[offset + 3] = color.a
                                x += 1
                            }

                            if x < width && y >= 0 && i * 2 + 1 < literalCount {
                                let color = lowIndex < palette.count ? palette[lowIndex] : (r: UInt8(0), g: UInt8(0), b: UInt8(0), a: UInt8(255))
                                let offset = (y * width + x) * 4
                                pixelData[offset] = color.r
                                pixelData[offset + 1] = color.g
                                pixelData[offset + 2] = color.b
                                pixelData[offset + 3] = color.a
                                x += 1
                            }
                        }
                    }
                    // Padding to word boundary
                    if bytesToRead % 2 == 1 && reader.remaining > 0 {
                        _ = try reader.readUInt8()
                    }
                }
            }
        }

        // Read AND mask
        let andRowSize = ((width + 31) / 32) * 4
        for row in 0..<height {
            let targetY = height - 1 - row
            for byteIndex in 0..<andRowSize {
                if reader.remaining > 0 {
                    let maskByte = try reader.readUInt8()
                    for bit in 0..<8 {
                        let px = byteIndex * 8 + bit
                        if px >= width { break }
                        let isTransparent = (maskByte >> (7 - bit)) & 1 == 1
                        if isTransparent {
                            let offset = (targetY * width + px) * 4
                            pixelData[offset + 3] = 0
                        }
                    }
                }
            }
        }

        return try createCGImage(from: pixelData, width: width, height: height)
    }

    /// Decode 32-bit BGRA BMP
    private static func decode32BitBMP(reader: inout BinaryReader, width: Int, height: Int) throws -> CGImage {
        var pixelData = Data(count: width * height * 4)

        // Read rows bottom-to-top (BMP is stored upside down)
        for y in 0..<height {
            let targetY = height - 1 - y

            for x in 0..<width {
                let b = try reader.readUInt8()
                let g = try reader.readUInt8()
                let r = try reader.readUInt8()
                let a = try reader.readUInt8()

                let offset = (targetY * width + x) * 4
                pixelData[offset] = r
                pixelData[offset + 1] = g
                pixelData[offset + 2] = b
                pixelData[offset + 3] = a
            }
        }

        return try createCGImage(from: pixelData, width: width, height: height)
    }

    /// Decode 8-bit paletted BMP with AND mask
    private static func decode8BitBMP(reader: inout BinaryReader, width: Int, height: Int, paletteSize: Int) throws -> CGImage {
        // Read color palette (up to 256 colors, BGRA format)
        let actualPaletteSize = paletteSize > 0 ? min(paletteSize, 256) : 256
        var palette: [(r: UInt8, g: UInt8, b: UInt8, a: UInt8)] = []
        for _ in 0..<actualPaletteSize {
            let b = try reader.readUInt8()
            let g = try reader.readUInt8()
            let r = try reader.readUInt8()
            let _ = try reader.readUInt8() // reserved/alpha (usually 0)
            palette.append((r: r, g: g, b: b, a: 255))
        }

        let rowSize = ((width + 3) / 4) * 4  // Padded to 4 bytes
        let padding = rowSize - width

        var pixelData = Data(count: width * height * 4)

        // Read indexed color data (bottom-to-top)
        for y in 0..<height {
            let targetY = height - 1 - y

            for x in 0..<width {
                let index = Int(try reader.readUInt8())
                let color = index < palette.count ? palette[index] : (r: UInt8(0), g: UInt8(0), b: UInt8(0), a: UInt8(255))

                let offset = (targetY * width + x) * 4
                pixelData[offset] = color.r
                pixelData[offset + 1] = color.g
                pixelData[offset + 2] = color.b
                pixelData[offset + 3] = color.a
            }

            // Skip padding
            if padding > 0 {
                try reader.skip(padding)
            }
        }

        // Read AND mask (1-bit transparency)
        let andRowSize = ((width + 31) / 32) * 4

        for y in 0..<height {
            let targetY = height - 1 - y

            for byteIndex in 0..<andRowSize {
                let maskByte: UInt8
                if reader.remaining > 0 {
                    maskByte = try reader.readUInt8()
                } else {
                    break
                }

                for bit in 0..<8 {
                    let x = byteIndex * 8 + bit
                    if x >= width { break }

                    let isTransparent = (maskByte >> (7 - bit)) & 1 == 1
                    if isTransparent {
                        let offset = (targetY * width + x) * 4
                        pixelData[offset + 3] = 0  // Set alpha to 0
                    }
                }
            }
        }

        return try createCGImage(from: pixelData, width: width, height: height)
    }

    /// Decode 4-bit paletted BMP with AND mask
    private static func decode4BitBMP(reader: inout BinaryReader, width: Int, height: Int, paletteSize: Int) throws -> CGImage {
        // Read color palette (up to 16 colors, BGRA format)
        let actualPaletteSize = paletteSize > 0 ? min(paletteSize, 16) : 16
        var palette: [(r: UInt8, g: UInt8, b: UInt8, a: UInt8)] = []
        for _ in 0..<actualPaletteSize {
            let b = try reader.readUInt8()
            let g = try reader.readUInt8()
            let r = try reader.readUInt8()
            let _ = try reader.readUInt8() // reserved
            palette.append((r: r, g: g, b: b, a: 255))
        }

        let rowSize = ((width * 4 + 31) / 32) * 4  // Bits to bytes, padded to 4 bytes

        var pixelData = Data(count: width * height * 4)

        // Read indexed color data (bottom-to-top)
        for y in 0..<height {
            let targetY = height - 1 - y
            var x = 0
            var bytesRead = 0

            while x < width {
                let byte = try reader.readUInt8()
                bytesRead += 1

                // High nibble first
                let highIndex = Int((byte >> 4) & 0x0F)
                if x < width {
                    let color = highIndex < palette.count ? palette[highIndex] : (r: UInt8(0), g: UInt8(0), b: UInt8(0), a: UInt8(255))
                    let offset = (targetY * width + x) * 4
                    pixelData[offset] = color.r
                    pixelData[offset + 1] = color.g
                    pixelData[offset + 2] = color.b
                    pixelData[offset + 3] = color.a
                    x += 1
                }

                // Low nibble
                let lowIndex = Int(byte & 0x0F)
                if x < width {
                    let color = lowIndex < palette.count ? palette[lowIndex] : (r: UInt8(0), g: UInt8(0), b: UInt8(0), a: UInt8(255))
                    let offset = (targetY * width + x) * 4
                    pixelData[offset] = color.r
                    pixelData[offset + 1] = color.g
                    pixelData[offset + 2] = color.b
                    pixelData[offset + 3] = color.a
                    x += 1
                }
            }

            // Skip remaining padding
            let padding = rowSize - bytesRead
            if padding > 0 {
                try reader.skip(padding)
            }
        }

        // Read AND mask (1-bit transparency)
        let andRowSize = ((width + 31) / 32) * 4

        for y in 0..<height {
            let targetY = height - 1 - y

            for byteIndex in 0..<andRowSize {
                let maskByte: UInt8
                if reader.remaining > 0 {
                    maskByte = try reader.readUInt8()
                } else {
                    break
                }

                for bit in 0..<8 {
                    let x = byteIndex * 8 + bit
                    if x >= width { break }

                    let isTransparent = (maskByte >> (7 - bit)) & 1 == 1
                    if isTransparent {
                        let offset = (targetY * width + x) * 4
                        pixelData[offset + 3] = 0
                    }
                }
            }
        }

        return try createCGImage(from: pixelData, width: width, height: height)
    }

    /// Decode 1-bit monochrome BMP with AND mask
    private static func decode1BitBMP(reader: inout BinaryReader, width: Int, height: Int, paletteSize: Int) throws -> CGImage {
        // Read color palette (2 colors, BGRA format)
        let actualPaletteSize = paletteSize > 0 ? min(paletteSize, 2) : 2
        var palette: [(r: UInt8, g: UInt8, b: UInt8, a: UInt8)] = []
        for _ in 0..<actualPaletteSize {
            let b = try reader.readUInt8()
            let g = try reader.readUInt8()
            let r = try reader.readUInt8()
            let _ = try reader.readUInt8() // reserved
            palette.append((r: r, g: g, b: b, a: 255))
        }

        let rowSize = ((width + 31) / 32) * 4  // Padded to 4 bytes

        var pixelData = Data(count: width * height * 4)

        // Read indexed color data (bottom-to-top)
        for y in 0..<height {
            let targetY = height - 1 - y

            for byteIndex in 0..<rowSize {
                let byte = try reader.readUInt8()

                for bit in 0..<8 {
                    let x = byteIndex * 8 + bit
                    if x >= width { break }

                    let index = Int((byte >> (7 - bit)) & 1)
                    let color = index < palette.count ? palette[index] : (r: UInt8(0), g: UInt8(0), b: UInt8(0), a: UInt8(255))

                    let offset = (targetY * width + x) * 4
                    pixelData[offset] = color.r
                    pixelData[offset + 1] = color.g
                    pixelData[offset + 2] = color.b
                    pixelData[offset + 3] = color.a
                }
            }
        }

        // Read AND mask (1-bit transparency)
        for y in 0..<height {
            let targetY = height - 1 - y

            for byteIndex in 0..<rowSize {
                let maskByte: UInt8
                if reader.remaining > 0 {
                    maskByte = try reader.readUInt8()
                } else {
                    break
                }

                for bit in 0..<8 {
                    let x = byteIndex * 8 + bit
                    if x >= width { break }

                    let isTransparent = (maskByte >> (7 - bit)) & 1 == 1
                    if isTransparent {
                        let offset = (targetY * width + x) * 4
                        pixelData[offset + 3] = 0
                    }
                }
            }
        }

        return try createCGImage(from: pixelData, width: width, height: height)
    }

    /// Decode 24-bit BGR BMP with separate AND mask
    private static func decode24BitBMP(reader: inout BinaryReader, width: Int, height: Int) throws -> CGImage {
        let rowSize = ((width * 3 + 3) / 4) * 4  // Padded to 4 bytes
        let padding = rowSize - width * 3

        var pixelData = Data(count: width * height * 4)

        // Read color data (bottom-to-top)
        for y in 0..<height {
            let targetY = height - 1 - y

            for x in 0..<width {
                let b = try reader.readUInt8()
                let g = try reader.readUInt8()
                let r = try reader.readUInt8()

                let offset = (targetY * width + x) * 4
                pixelData[offset] = r
                pixelData[offset + 1] = g
                pixelData[offset + 2] = b
                pixelData[offset + 3] = 255  // Will be updated by AND mask
            }

            // Skip padding
            if padding > 0 {
                try reader.skip(padding)
            }
        }

        // Read AND mask (1-bit transparency)
        let andRowSize = ((width + 31) / 32) * 4

        for y in 0..<height {
            let targetY = height - 1 - y

            for byteIndex in 0..<(andRowSize) {
                let maskByte: UInt8
                if reader.remaining > 0 {
                    maskByte = try reader.readUInt8()
                } else {
                    break
                }

                for bit in 0..<8 {
                    let x = byteIndex * 8 + bit
                    if x >= width { break }

                    let isTransparent = (maskByte >> (7 - bit)) & 1 == 1
                    if isTransparent {
                        let offset = (targetY * width + x) * 4
                        pixelData[offset + 3] = 0  // Set alpha to 0
                    }
                }
            }
        }

        return try createCGImage(from: pixelData, width: width, height: height)
    }

    /// Fallback: wrap DIB with BMP header and use ImageIO
    private static func decodeBMPWithHeader(data: Data, width: Int, height: Int) throws -> CGImage {
        // Create BMP file header
        var bmpData = Data()

        // BM signature
        bmpData.append(contentsOf: [0x42, 0x4D])

        // File size
        let fileSize = UInt32(14 + data.count)
        bmpData.append(contentsOf: withUnsafeBytes(of: fileSize.littleEndian) { Array($0) })

        // Reserved
        bmpData.append(contentsOf: [0x00, 0x00, 0x00, 0x00])

        // Offset to pixel data (14 + header size)
        let headerSize = data.prefix(4).withUnsafeBytes { $0.load(as: UInt32.self) }
        let offset = UInt32(14) + headerSize
        bmpData.append(contentsOf: withUnsafeBytes(of: offset.littleEndian) { Array($0) })

        // Append DIB data
        bmpData.append(data)

        // Try to decode with ImageIO
        guard let imageSource = CGImageSourceCreateWithData(bmpData as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            // Create a placeholder image if decoding fails
            return try createPlaceholderImage(width: width, height: height)
        }

        return cgImage
    }

    /// Create CGImage from RGBA pixel data
    private static func createCGImage(from data: Data, width: Int, height: Int) throws -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let provider = CGDataProvider(data: data as CFData) else {
            throw WindowsCursorParserError.decodingFailed("Failed to create data provider")
        }

        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else {
            throw WindowsCursorParserError.decodingFailed("Failed to create CGImage")
        }

        return cgImage
    }

    /// Create a placeholder image for unsupported formats
    private static func createPlaceholderImage(width: Int, height: Int) throws -> CGImage {
        var pixelData = Data(count: width * height * 4)

        // Fill with semi-transparent magenta (indicates unsupported format)
        for i in stride(from: 0, to: pixelData.count, by: 4) {
            pixelData[i] = 255      // R
            pixelData[i + 1] = 0    // G
            pixelData[i + 2] = 255  // B
            pixelData[i + 3] = 128  // A
        }

        return try createCGImage(from: pixelData, width: width, height: height)
    }

    /// Create sprite sheet from multiple frames
    private static func createSpriteSheet(frames: [FrameData], width: Int, height: Int) throws -> CGImage {
        let totalHeight = height * frames.count

        // Create a graphics context for the sprite sheet
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: totalHeight,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw WindowsCursorParserError.decodingFailed("Failed to create graphics context")
        }

        // Draw each frame
        for (index, frame) in frames.enumerated() {
            let y = totalHeight - (index + 1) * height  // CGContext origin is bottom-left

            // Scale frame if needed
            var frameImage = frame.image
            if frame.image.width != width || frame.image.height != height {
                if let scaled = scaleImage(frame.image, to: CGSize(width: width, height: height)) {
                    frameImage = scaled
                }
            }

            context.draw(frameImage, in: CGRect(x: 0, y: y, width: width, height: height))
        }

        guard let spriteSheet = context.makeImage() else {
            throw WindowsCursorParserError.decodingFailed("Failed to create sprite sheet")
        }

        return spriteSheet
    }

    /// Scale an image to a new size
    private static func scaleImage(_ image: CGImage, to size: CGSize) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(size.width) * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(origin: .zero, size: size))

        return context.makeImage()
    }
}
