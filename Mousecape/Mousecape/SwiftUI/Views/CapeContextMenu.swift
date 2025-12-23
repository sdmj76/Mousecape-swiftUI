//
//  CapeContextMenu.swift
//  Mousecape
//
//  Context menu for Cape actions (right-click menu)
//  Uses SF Symbols for icons
//

import SwiftUI

struct CapeContextMenu: View {
    let cape: CursorLibrary
    @Environment(AppState.self) private var appState

    private var isApplied: Bool {
        appState.appliedCape?.id == cape.id
    }

    var body: some View {
        // Apply
        Button {
            appState.applyCape(cape)
        } label: {
            Label("Apply", systemImage: "checkmark.circle")
        }
        .disabled(isApplied)

        // Edit
        Button {
            appState.editCape(cape)
        } label: {
            Label("Edit", systemImage: "square.and.pencil")
        }

        Divider()

        // Export
        Button {
            appState.exportCape(cape)
        } label: {
            Label("Export...", systemImage: "square.and.arrow.up")
        }

        // Show in Finder
        Button {
            appState.showInFinder(cape)
        } label: {
            Label("Show in Finder", systemImage: "folder")
        }

        Divider()

        // Delete (with confirmation)
        Button(role: .destructive) {
            appState.confirmDeleteCape(cape)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Text("Right-click to see menu")
    }
    .frame(width: 200, height: 100)
    .contextMenu {
        CapeContextMenu(cape: CursorLibrary(name: "Test Cape", author: "Test"))
    }
    .environment(AppState.shared)
}
