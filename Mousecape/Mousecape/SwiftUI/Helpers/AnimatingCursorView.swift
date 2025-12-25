//
//  AnimatingCursorView.swift
//  Mousecape
//
//  Pure SwiftUI animated cursor view with sprite animation
//  Replaces MMAnimatingImageView for SwiftUI usage
//

import SwiftUI
import AppKit

/// SwiftUI view for displaying animated cursor sprites
struct AnimatingCursorView: View {
    let cursor: Cursor
    var showHotspot: Bool = false
    var refreshTrigger: Int = 0
    /// Scale factor for rendering (1.0 = original size, 0.5 = half size)
    var scale: CGFloat = 1.0

    @State private var currentFrame: Int = 0
    @State private var animationTimer: Timer?
    @AppStorage("showPreviewAnimations") private var showPreviewAnimations = true

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Cursor sprite frame
                if let frameImage = getFrameImage(at: currentFrame) {
                    let displaySize = CGSize(
                        width: frameImage.size.width * scale,
                        height: frameImage.size.height * scale
                    )
                    Image(nsImage: frameImage)
                        .interpolation(.high)
                        .resizable()
                        .frame(width: displaySize.width, height: displaySize.height)
                } else {
                    // Placeholder
                    Image(systemName: "cursorarrow")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                }

                // Hotspot indicator
                if showHotspot, let frameImage = getFrameImage(at: 0) {
                    HotspotIndicator(
                        hotspot: cursor.hotSpot,
                        frameSize: CGSize(width: frameImage.size.width, height: frameImage.size.height),
                        viewSize: geometry.size,
                        scale: scale
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            stopAnimation()
        }
        .onChange(of: cursor.frameCount) { _, _ in
            restartAnimation()
        }
        .onChange(of: cursor.frameDuration) { _, _ in
            restartAnimation()
        }
        .onChange(of: cursor.id) { _, _ in
            currentFrame = 0
            restartAnimation()
        }
        .onChange(of: refreshTrigger) { _, _ in
            // Force refresh - restart animation
            restartAnimation()
        }
        .onChange(of: showPreviewAnimations) { _, newValue in
            if newValue {
                startAnimation()
            } else {
                stopAnimation()
                currentFrame = 0
            }
        }
    }

    /// Extract a single frame from the sprite sheet
    private func getFrameImage(at frameIndex: Int) -> NSImage? {
        guard let image = cursor.image else { return nil }

        let frameCount = max(1, cursor.frameCount)
        let frameHeight = image.size.height / CGFloat(frameCount)
        let frameWidth = image.size.width

        // Guard against zero-size images
        guard frameWidth > 0, frameHeight > 0 else { return nil }

        // Calculate source rect for this frame (frames are stacked vertically, top to bottom)
        let sourceRect = NSRect(
            x: 0,
            y: image.size.height - CGFloat(frameIndex + 1) * frameHeight,
            width: frameWidth,
            height: frameHeight
        )

        // Create new image for this frame
        let frameImage = NSImage(size: NSSize(width: frameWidth, height: frameHeight))
        frameImage.lockFocus()
        image.draw(
            in: NSRect(x: 0, y: 0, width: frameWidth, height: frameHeight),
            from: sourceRect,
            operation: .copy,
            fraction: 1.0
        )
        frameImage.unlockFocus()

        return frameImage
    }

    private func startAnimation() {
        guard cursor.frameCount > 1, cursor.frameDuration > 0, showPreviewAnimations else {
            currentFrame = 0
            return
        }

        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: cursor.frameDuration, repeats: true) { _ in
            currentFrame = (currentFrame + 1) % cursor.frameCount
        }
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    private func restartAnimation() {
        stopAnimation()
        currentFrame = 0
        startAnimation()
    }
}

/// Hotspot indicator overlay
private struct HotspotIndicator: View {
    let hotspot: NSPoint
    let frameSize: CGSize
    let viewSize: CGSize
    let scale: CGFloat

    var body: some View {
        // Calculate the scaled image size
        let scaledWidth = frameSize.width * scale
        let scaledHeight = frameSize.height * scale

        // Calculate offset to center the image in the view
        let offsetX = (viewSize.width - scaledWidth) / 2
        let offsetY = (viewSize.height - scaledHeight) / 2

        // Hotspot position - hotspot.y is from top of image, SwiftUI y is also from top
        let x = offsetX + hotspot.x * scale
        let y = offsetY + hotspot.y * scale

        Circle()
            .fill(Color.red)
            .frame(width: 6, height: 6)
            .overlay(
                Circle()
                    .stroke(Color.primary.opacity(0.5), lineWidth: 0.5)
            )
            .position(x: x, y: y)
    }
}

// MARK: - Static Cursor Image View

/// A simpler view for non-animated cursor display
struct StaticCursorImageView: View {
    let cursor: Cursor
    let size: CGFloat

    init(cursor: Cursor, size: CGFloat = 48) {
        self.cursor = cursor
        self.size = size
    }

    var body: some View {
        if let image = cursor.previewImage(size: size) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image(systemName: "cursorarrow")
                .font(.system(size: size * 0.5))
                .foregroundStyle(.tertiary)
                .frame(width: size, height: size)
        }
    }
}

// MARK: - Cursor Thumbnail View

/// Small thumbnail for cursor preview
struct CursorThumbnailView: View {
    let cursor: Cursor
    let size: CGFloat
    let scale: CGFloat
    @State private var isAnimating = false

    init(cursor: Cursor, size: CGFloat = 32, scale: CGFloat = 1.0) {
        self.cursor = cursor
        self.size = size
        self.scale = scale
    }

    var body: some View {
        if cursor.isAnimated {
            AnimatingCursorView(cursor: cursor, showHotspot: false, scale: scale)
                .frame(width: size, height: size)
        } else {
            StaticCursorImageView(cursor: cursor, size: size)
        }
    }
}

// MARK: - Preview

#Preview("Animating Cursor View") {
    VStack(spacing: 20) {
        AnimatingCursorView(
            cursor: Cursor(identifier: "com.apple.coregraphics.Arrow"),
            showHotspot: true
        )
        .frame(width: 64, height: 64)
        .border(Color.gray.opacity(0.3))

        StaticCursorImageView(
            cursor: Cursor(identifier: "com.apple.coregraphics.Wait"),
            size: 48
        )
    }
    .padding()
}
