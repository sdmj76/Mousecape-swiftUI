//
//  HomeView.swift
//  Mousecape
//
//  Home view with Cape icon grid and preview panel
//

import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView {
            // Left side: Cape icon grid
            Group {
                if appState.capes.isEmpty {
                    EmptyStateView()
                } else {
                    CapeIconGridView()
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 280, max: 400)
        } detail: {
            // Right side: Preview panel
            if let cape = appState.selectedCape {
                CapePreviewPanel(cape: cape)
            } else {
                ContentUnavailableView(
                    "Select a Cape",
                    systemImage: "cursorarrow.click.2",
                    description: Text("Choose a cape from the list to preview")
                )
            }
        }
        .focusedSceneValue(\.selectedCape, $appState.selectedCape)
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ContentUnavailableView {
            Label("No Capes", systemImage: "cursorarrow.slash")
        } description: {
            Text("Create a new cape or import an existing one to get started.")
        } actions: {
            HStack(spacing: 12) {
                Button("New Cape") {
                    appState.createNewCape()
                }
                .buttonStyle(.borderedProminent)

                Button("Import Cape") {
                    appState.importCape()
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

// MARK: - Cape Icon Grid View

struct CapeIconGridView: View {
    @Environment(AppState.self) private var appState

    private let columns = [
        GridItem(.adaptive(minimum: 80, maximum: 100), spacing: 12)
    ]

    var body: some View {
        @Bindable var appState = appState

        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(appState.capes) { cape in
                    CapeIconCell(cape: cape, onSelect: {
                        appState.selectedCape = cape
                    }, onDoubleClick: {
                        handleDoubleClick(cape)
                    })
                }
            }
            .padding()
        }
    }

    private func handleDoubleClick(_ cape: CursorLibrary) {
        let action = DoubleClickAction(rawValue: UserDefaults.standard.integer(forKey: "doubleClickAction")) ?? .applyCape
        switch action {
        case .applyCape:
            appState.applyCape(cape)
        case .editCape:
            appState.editCape(cape)
        case .doNothing:
            break
        }
    }
}

// MARK: - Cape Icon Cell (for Icon Mode)

struct CapeIconCell: View {
    let cape: CursorLibrary
    let onSelect: () -> Void
    let onDoubleClick: () -> Void
    @Environment(AppState.self) private var appState
    @State private var isHovered = false
    @State private var lastClickTime: Date?

    private var isSelected: Bool {
        appState.selectedCape?.id == cape.id
    }

    private var isApplied: Bool {
        appState.appliedCape?.id == cape.id
    }

    var body: some View {
        VStack(spacing: 6) {
            // Cursor preview
            ZStack {
                if let previewCursor = cape.previewCursor {
                    AnimatingCursorView(cursor: previewCursor, showHotspot: false)
                        .frame(width: 48, height: 48)
                } else {
                    Image(systemName: "cursorarrow.slash")
                        .font(.title)
                        .foregroundStyle(.tertiary)
                        .frame(width: 48, height: 48)
                }
            }

            // Cape name with applied indicator
            HStack(spacing: 2) {
                if isApplied {
                    Text("\u{25CF}")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
                Text(cape.name)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .truncationMode(.tail)
            }
        }
        .frame(width: 80)
        .padding(8)
        .glassEffect(
            isSelected ? .regular : (isHovered ? .regular : .clear),
            in: RoundedRectangle(cornerRadius: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        )
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.spring(duration: 0.2), value: isHovered)
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
        .onTapGesture {
            let now = Date()
            if let last = lastClickTime, now.timeIntervalSince(last) < 0.3 {
                // Double click detected
                onDoubleClick()
                lastClickTime = nil
            } else {
                // Single click - select immediately
                onSelect()
                lastClickTime = now
            }
        }
        .contextMenu {
            CapeContextMenu(cape: cape)
        }
    }
}

// MARK: - Preview

#Preview {
    HomeView()
        .environment(AppState.shared)
}
