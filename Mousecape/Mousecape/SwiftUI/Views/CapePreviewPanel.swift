//
//  CapePreviewPanel.swift
//  Mousecape
//
//  Preview panel showing cape details and cursor grid
//

import SwiftUI

// MARK: - Preview Scale Constants

/// Scale factor for cursor previews in the preview panel
private let previewPanelScale: CGFloat = 1.5

struct CapePreviewPanel: View {
    let cape: CursorLibrary
    @Environment(AppState.self) private var appState
    @State private var zoomedCursor: Cursor?
    @State private var cachedCursors: [Cursor] = []
    @Namespace private var cursorNamespace
    @AppStorage("showAuthorInfo") private var showAuthorInfo = true

    private var isApplied: Bool {
        appState.appliedCape?.id == cape.id
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Top: Cape info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(cape.name)
                                    .font(.title2.bold())
                                if isApplied {
                                    AppliedBadge()
                                }
                            }
                            if showAuthorInfo {
                                Text("by \(cape.author)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding()
                    .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 12))
                }
                .padding()

                Divider()

                // Middle: Cursor preview grid (auto-wrapping)
                ScrollView {
                    CursorFlowGrid(
                        cursors: cachedCursors,
                        zoomedCursor: zoomedCursor,
                        namespace: cursorNamespace
                    ) { cursor in
                        withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                            zoomedCursor = cursor
                        }
                    }
                    .padding()
                }

                Divider()

                // Bottom: Cursor count
                HStack {
                    Text(cape.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding()
            }

            // Zoom overlay
            if let cursor = zoomedCursor {
                CursorZoomOverlay(
                    cursor: cursor,
                    namespace: cursorNamespace
                ) {
                    withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                        zoomedCursor = nil
                    }
                }
            }
        }
        .onAppear {
            refreshCursors()
        }
        .onChange(of: cape.id) { _, _ in
            refreshCursors()
        }
        .onChange(of: appState.capeListRefreshTrigger) { _, _ in
            refreshCursors()
        }
    }

    private func refreshCursors() {
        cape.invalidateCursorCache()
        cachedCursors = cape.cursors
    }
}

// MARK: - Applied Badge

struct AppliedBadge: View {
    var body: some View {
        Label("Applied", systemImage: "checkmark.circle.fill")
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .glassEffect(.regular.tint(.green), in: .capsule)
    }
}

// MARK: - Cursor Zoom Overlay

struct CursorZoomOverlay: View {
    let cursor: Cursor
    let namespace: Namespace.ID
    let onDismiss: () -> Void
    var showHotspot: Bool = false

    @State private var showDetails = false

    var body: some View {
        ZStack {
            // Dimmed background - click to dismiss
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            // Centered zoomed cursor with matched geometry
            VStack(spacing: 16) {
                AnimatingCursorView(cursor: cursor, showHotspot: showHotspot, scale: 3)
                    .frame(width: 128, height: 128)
                    .matchedGeometryEffect(id: cursor.id, in: namespace)

                // Details fade in after the cursor arrives
                if showDetails {
                    VStack(spacing: 4) {
                        Text(cursor.displayName)
                            .font(.title3.bold())

                        Text(cursor.identifier)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if cursor.frameCount > 1 {
                            Text("\(cursor.frameCount) frames")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .padding(24)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
            .shadow(radius: 20)
        }
        .contentShape(Rectangle())
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
        .onAppear {
            // Delay showing details until cursor animation completes
            withAnimation(.easeOut(duration: 0.3).delay(0.2)) {
                showDetails = true
            }
        }
    }
}

// MARK: - Cursor Flow Grid (Auto-wrapping)

struct CursorFlowGrid: View {
    let cursors: [Cursor]
    let zoomedCursor: Cursor?
    let namespace: Namespace.ID
    var onCursorTap: ((Cursor) -> Void)?
    @AppStorage("previewGridColumns") private var previewGridColumns = 0

    init(
        cursors: [Cursor],
        zoomedCursor: Cursor? = nil,
        namespace: Namespace.ID,
        onCursorTap: ((Cursor) -> Void)? = nil
    ) {
        self.cursors = cursors
        self.zoomedCursor = zoomedCursor
        self.namespace = namespace
        self.onCursorTap = onCursorTap
    }

    private var columns: [GridItem] {
        if previewGridColumns > 0 {
            // Fixed number of columns
            return Array(repeating: GridItem(.flexible(), spacing: 24), count: previewGridColumns)
        } else {
            // Auto (adaptive)
            return [GridItem(.adaptive(minimum: 80, maximum: 100), spacing: 24)]
        }
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(cursors) { cursor in
                CursorPreviewCell(
                    cursor: cursor,
                    isZoomed: zoomedCursor?.id == cursor.id,
                    namespace: namespace
                ) {
                    onCursorTap?(cursor)
                }
            }
        }
    }
}

// MARK: - Cursor Preview Cell

struct CursorPreviewCell: View {
    let cursor: Cursor
    let isZoomed: Bool
    let namespace: Namespace.ID
    var onTap: (() -> Void)?
    @State private var isHovered = false

    init(
        cursor: Cursor,
        isZoomed: Bool = false,
        namespace: Namespace.ID,
        onTap: (() -> Void)? = nil
    ) {
        self.cursor = cursor
        self.isZoomed = isZoomed
        self.namespace = namespace
        self.onTap = onTap
    }

    var body: some View {
        VStack(spacing: 4) {
            // Only show cursor here if not zoomed (it moves to overlay)
            if !isZoomed {
                AnimatingCursorView(
                    cursor: cursor,
                    showHotspot: false,
                    scale: previewPanelScale
                )
                .frame(width: 64, height: 64)
                .matchedGeometryEffect(id: cursor.id, in: namespace)
            } else {
                // Placeholder to maintain layout
                Color.clear
                    .frame(width: 64, height: 64)
            }

            if !isZoomed {
                Text(cursor.displayName)
                    .font(.caption2)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(8)
        .glassEffect(
            isHovered && !isZoomed ? .regular : .clear,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .opacity(isZoomed ? 0 : 1)
        .scaleEffect(isHovered && !isZoomed ? 1.1 : 1.0)
        .animation(.spring(duration: 0.2), value: isHovered)
        .onHover { isHovered = $0 }
        .onTapGesture {
            if !isZoomed {
                onTap?()
            }
        }
        .help(cursor.identifier)
    }
}

// MARK: - Preview

#Preview {
    CapePreviewPanel(cape: CursorLibrary(name: "Preview Cape", author: "Test"))
        .environment(AppState.shared)
        .environment(LocalizationManager.shared)
        .frame(width: 500, height: 400)
}
