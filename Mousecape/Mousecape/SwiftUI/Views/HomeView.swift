//
//  HomeView.swift
//  Mousecape
//
//  Home view with Cape icon grid and preview panel
//

import SwiftUI

// MARK: - Preview Scale Constants

/// Scale factor for cursor previews in left sidebar grid
private let sidebarPreviewScale: CGFloat = 1.5

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(LocalizationManager.self) private var localization
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    // MARK: - Home Toolbar Content
    @ToolbarContentBuilder
    private var homeToolbarContent: some ToolbarContent {

        // Group 1: New, Delete, Edit
        ToolbarItemGroup {
            Menu {
                Button(localization.localized("New Cape")) {
                    appState.createNewCape()
                }
                #if ENABLE_WINDOWS_IMPORT
                Divider()
                Button(localization.localized("Import from Windows Cursors...")) {
                    appState.importWindowsCursorFolder()
                }
                #endif
            } label: {
                Image(systemName: "plus")
            }
            .help(localization.localized("New Cape"))

            Button(action: {
                if let cape = appState.selectedCape {
                    appState.confirmDeleteCape(cape)
                }
            }) {
                Image(systemName: "minus")
            }
            .help(localization.localized("Delete Cape"))
            .disabled(appState.selectedCape == nil)

            Button(action: {
                if let cape = appState.selectedCape {
                    appState.editCape(cape)
                }
            }) {
                Image(systemName: "square.and.pencil")
            }
            .help(localization.localized("Edit Cape"))
            .disabled(appState.selectedCape == nil)

            Button(action: {
                if let cape = appState.selectedCape {
                    appState.applyCape(cape)
                }
            }) {
                Image(systemName: "checkmark.circle")
            }
            .help(localization.localized("Apply Cape"))
            .disabled(appState.selectedCape == nil)
        }

        // Group 2: Import, Export
        ToolbarItemGroup {
            Button(action: { appState.importCape() }) {
                Image(systemName: "square.and.arrow.down")
            }
            .help(localization.localized("Import Cape"))

            Button(action: {
                if let cape = appState.selectedCape {
                    appState.exportCape(cape)
                }
            }) {
                Image(systemName: "square.and.arrow.up")
            }
            .help(localization.localized("Export Cape"))
            .disabled(appState.selectedCape == nil)
        }

        // Standalone: Settings
        ToolbarItem {
            Button(action: {
                appState.currentPage = .settings
            }) {
                Image(systemName: "gear")
            }
            .help(localization.localized("Settings"))
        }
    }

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Left side: Cape grid or Cursor list depending on mode
            Group {
                if appState.isEditing, let cape = appState.editingCape {
                    // Edit mode: show cursor list
                    CursorListView(
                        cape: cape,
                        selection: $appState.editingSelectedCursor
                    )
                } else if appState.capes.isEmpty {
                    EmptyStateView()
                } else {
                    CapeIconGridView()
                }
            }
            .scrollContentBackground(.hidden)
            .navigationSplitViewColumnWidth(min: 200, ideal: 280, max: 400)
        } detail: {
            // Right side: Preview or Edit panel
            // Wrapped in NavigationStack for proper toolbar navigation placement
            NavigationStack {
                // Use conditional root view instead of ZStack for proper navigationTitle
                if appState.isEditing, let cape = appState.editingCape {
                    EditDetailContent(cape: cape)
                        .navigationTitle(cape.name)
                } else if let cape = appState.selectedCape {
                    CapePreviewPanel(cape: cape)
                        .toolbar {
                            homeToolbarContent
                        }
                } else {
                    ContentUnavailableView(
                        localization.localized("Select a Cape"),
                        systemImage: "cursorarrow.click.2",
                        description: Text(localization.localized("Choose a cape from the list to preview"))
                    )
                    .toolbar {
                        homeToolbarContent
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .focusedSceneValue(\.selectedCape, $appState.selectedCape)
        // Remove sidebar toggle button in edit mode
        .toolbar(removing: .sidebarToggle)
        // Delete confirmation dialog
        .confirmationDialog(
            localization.localized("Delete Cape"),
            isPresented: $appState.showDeleteConfirmation,
            titleVisibility: .visible,
            presenting: appState.capeToDelete
        ) { cape in
            Button("\(localization.localized("Delete")) \"\(cape.name)\"", role: .destructive) {
                appState.deleteCape(cape)
            }
            Button(localization.localized("Cancel"), role: .cancel) {
                appState.capeToDelete = nil
            }
        } message: { cape in
            Text("\(localization.localized("Are you sure you want to delete")) \"\(cape.name)\"? \(localization.localized("This action cannot be undone."))")
        }
        // Discard changes confirmation alert (macOS native style)
        .alert(
            localization.localized("Unsaved Changes"),
            isPresented: $appState.showDiscardConfirmation
        ) {
            Button(localization.localized("Save")) {
                appState.closeEditWithSave()
            }
            .keyboardShortcut(.defaultAction)

            Button(localization.localized("Don't Save"), role: .destructive) {
                appState.closeEdit()
            }

            Button(localization.localized("Cancel"), role: .cancel) {
                appState.showDiscardConfirmation = false
            }
        } message: {
            Text(localization.localized("Do you want to save the changes you made?"))
        }
        // Delete cursor confirmation dialog
        .confirmationDialog(
            localization.localized("Delete Cursor?"),
            isPresented: $appState.showDeleteCursorConfirmation,
            titleVisibility: .visible
        ) {
            Button(localization.localized("Delete"), role: .destructive) {
                appState.deleteSelectedCursor()
            }
            Button(localization.localized("Cancel"), role: .cancel) {
                appState.showDeleteCursorConfirmation = false
            }
        } message: {
            if let cursor = appState.editingSelectedCursor {
                Text("\(localization.localized("Are you sure you want to delete")) '\(cursor.displayName)'?")
            }
        }
        // Duplicate filename error alert
        .alert(
            localization.localized("Duplicate Filename"),
            isPresented: $appState.showDuplicateFilenameError
        ) {
            Button(localization.localized("OK"), role: .cancel) {
                appState.showDuplicateFilenameError = false
            }
        } message: {
            Text("\(localization.localized("A cape with the filename")) \"\(appState.duplicateFilename)\" \(localization.localized("already exists. Please change the Name or Author to use a different filename."))")
        }
        // Validation error alert
        .alert(
            localization.localized("Validation Error"),
            isPresented: $appState.showValidationError
        ) {
            Button(localization.localized("OK"), role: .cancel) {
                appState.showValidationError = false
            }
        } message: {
            Text(appState.validationErrorMessage)
        }
        // Image import warning alert (non-square image)
        .alert(
            localization.localized("Image Adjusted"),
            isPresented: $appState.showImageImportWarning
        ) {
            Button(localization.localized("OK"), role: .cancel) {
                appState.showImageImportWarning = false
            }
        } message: {
            Text(appState.imageImportWarningMessage)
        }
        // Add cursor sheet
        .sheet(isPresented: $appState.showAddCursorSheet) {
            if let cape = appState.editingCape {
                AddCursorSheet(cape: cape)
            }
        }
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    @Environment(AppState.self) private var appState
    @Environment(LocalizationManager.self) private var localization

    var body: some View {
        ContentUnavailableView {
            Label(localization.localized("No Capes"), systemImage: "cursorarrow.slash")
        } description: {
            Text(localization.localized("Create a new cape or import an existing one to get started."))
        } actions: {
            HStack(spacing: 12) {
                Button(localization.localized("New Cape")) {
                    appState.createNewCape()
                }
                .buttonStyle(.borderedProminent)

                Button(localization.localized("Import Cape")) {
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
        GridItem(.adaptive(minimum: 64, maximum: 80), spacing: 12)
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
                if let cursor = cape.previewCursor {
                    AnimatingCursorView(
                        cursor: cursor,
                        showHotspot: false,
                        scale: sidebarPreviewScale
                    )
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
        .frame(width: 64)
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .adaptiveGlassConditional(isActive: isSelected || isHovered, in: RoundedRectangle(cornerRadius: 10))
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
        .environment(LocalizationManager.shared)
}
