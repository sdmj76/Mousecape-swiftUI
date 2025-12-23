//
//  AnimatingCursorView.swift
//  Mousecape
//
//  NSViewRepresentable wrapper for MMAnimatingImageView
//  Displays animated cursor previews in SwiftUI
//

import SwiftUI
import AppKit

struct AnimatingCursorView: NSViewRepresentable {
    let cursor: Cursor
    var showHotspot: Bool = false

    func makeNSView(context: Context) -> MMAnimatingImageView {
        let view = MMAnimatingImageView()
        view.shouldAnimate = true
        view.shouldAllowDragging = false
        configureView(view)
        return view
    }

    func updateNSView(_ nsView: MMAnimatingImageView, context: Context) {
        configureView(nsView)
    }

    private func configureView(_ view: MMAnimatingImageView) {
        view.image = cursor.image
        view.frameCount = cursor.frameCount
        view.frameDuration = cursor.frameDuration
        view.hotSpot = cursor.hotSpot
        view.shouldShowHotSpot = showHotspot
        view.shouldAnimate = cursor.isAnimated
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
    @State private var isAnimating = false

    init(cursor: Cursor, size: CGFloat = 32) {
        self.cursor = cursor
        self.size = size
    }

    var body: some View {
        if cursor.isAnimated {
            AnimatingCursorView(cursor: cursor, showHotspot: false)
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
