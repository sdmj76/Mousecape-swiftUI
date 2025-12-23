//
//  CapePreviewPanel.swift
//  Mousecape
//
//  Preview panel showing cape details and cursor grid
//

import SwiftUI

struct CapePreviewPanel: View {
    let cape: CursorLibrary
    @Environment(AppState.self) private var appState

    private var isApplied: Bool {
        appState.appliedCape?.id == cape.id
    }

    var body: some View {
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
                        Text("by \(cape.author)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
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
                CursorFlowGrid(cursors: cape.cursors)
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

// MARK: - Cursor Flow Grid (Auto-wrapping)

struct CursorFlowGrid: View {
    let cursors: [Cursor]

    private let columns = [
        GridItem(.adaptive(minimum: 64, maximum: 80), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(cursors) { cursor in
                CursorPreviewCell(cursor: cursor)
            }
        }
    }
}

// MARK: - Cursor Preview Cell

struct CursorPreviewCell: View {
    let cursor: Cursor
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 4) {
            AnimatingCursorView(cursor: cursor, showHotspot: false)
                .frame(width: 48, height: 48)

            Text(cursor.displayName)
                .font(.caption2)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(8)
        .glassEffect(
            isHovered ? .regular : .clear,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .scaleEffect(isHovered ? 1.1 : 1.0)
        .animation(.spring(duration: 0.2), value: isHovered)
        .onHover { isHovered = $0 }
        .help(cursor.identifier)
    }
}

// MARK: - Preview

#Preview {
    CapePreviewPanel(cape: CursorLibrary(name: "Preview Cape", author: "Test"))
        .environment(AppState.shared)
        .frame(width: 500, height: 400)
}
