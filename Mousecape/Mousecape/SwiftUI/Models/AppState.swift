//
//  AppState.swift
//  Mousecape
//
//  Main application state management for SwiftUI
//

import Foundation
import AppKit
import Combine
import UniformTypeIdentifiers

/// Main application state - ObservableObject for SwiftUI
@Observable @MainActor
final class AppState: @unchecked Sendable {

    // MARK: - Properties

    /// All loaded capes
    private(set) var capes: [CursorLibrary] = []

    /// Currently applied cape
    private(set) var appliedCape: CursorLibrary?

    /// Currently selected cape in the list
    var selectedCape: CursorLibrary?

    /// Current page (Home / Settings)
    var currentPage: AppPage = .home

    /// Edit mode state
    var isEditing: Bool = false

    /// Cape being edited
    var editingCape: CursorLibrary?

    /// Delete confirmation state
    var showDeleteConfirmation: Bool = false
    var capeToDelete: CursorLibrary?

    /// Loading state
    var isLoading: Bool = false

    /// Error state
    var lastError: Error?
    var showError: Bool = false

    // MARK: - ObjC Controller Bridge

    private var libraryController: MCLibraryController?

    // MARK: - Initialization

    init() {
        setupLibraryController()
        loadCapes()
        loadPreferences()
    }

    private func setupLibraryController() {
        // Get the library URL
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }

        let mousecapeDir = appSupport.appendingPathComponent("Mousecape", isDirectory: true)
        let capesDir = mousecapeDir.appendingPathComponent("capes", isDirectory: true)

        // Create directory if needed
        try? fileManager.createDirectory(at: capesDir, withIntermediateDirectories: true)

        // Initialize the ObjC controller
        libraryController = MCLibraryController(url: capesDir)
    }

    private func loadCapes() {
        guard let controller = libraryController else { return }

        // Load capes from the ObjC controller
        if let objcCapes = controller.capes as? Set<MCCursorLibrary> {
            capes = objcCapes.map { CursorLibrary(objcLibrary: $0) }
            capes.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        // Check for applied cape
        if let applied = controller.appliedCape {
            appliedCape = capes.first { $0.underlyingLibrary === applied }
        }
    }

    private func loadPreferences() {
        // Reserved for future preferences loading
    }

    // MARK: - Cape Actions

    /// Create a new empty cape
    func createNewCape() {
        let newCape = CursorLibrary(name: "New Cape", author: NSFullUserName())

        // Set file URL before adding to library (required for save/delete)
        if let libraryURL = libraryController?.libraryURL {
            let fileURL = libraryURL.appendingPathComponent("\(newCape.identifier).cape")
            newCape.fileURL = fileURL
            // Save immediately to create the file
            newCape.underlyingLibrary.write(toFile: fileURL.path, atomically: true)
        }

        addCape(newCape)
        selectedCape = newCape
        editCape(newCape)
    }

    /// Import a cape from URL
    func importCape(from url: URL? = nil) {
        if let url = url {
            importCapeFromURL(url)
        } else {
            // Show open panel
            let panel = NSOpenPanel()
            panel.title = "Import Cape"
            panel.allowedContentTypes = [UTType(filenameExtension: "cape")].compactMap { $0 }
            panel.allowsMultipleSelection = true
            panel.canChooseDirectories = false

            panel.begin { [weak self] response in
                guard response == .OK else { return }
                for url in panel.urls {
                    self?.importCapeFromURL(url)
                }
            }
        }
    }

    private func importCapeFromURL(_ url: URL) {
        libraryController?.importCape(at: url)
        loadCapes() // Reload to get the new cape
    }

    /// Add a cape to the library
    func addCape(_ cape: CursorLibrary) {
        libraryController?.addCape(cape.underlyingLibrary)
        loadCapes()
    }

    /// Apply a cape
    func applyCape(_ cape: CursorLibrary) {
        libraryController?.applyCape(cape.underlyingLibrary)
        appliedCape = cape
    }

    /// Reset to default system cursors
    func resetToDefault() {
        libraryController?.restoreCape()
        appliedCape = nil
    }

    /// Edit a cape
    func editCape(_ cape: CursorLibrary) {
        editingCape = cape
        isEditing = true
    }

    /// Close edit mode
    func closeEdit() {
        isEditing = false
        editingCape = nil
    }

    /// Save the currently editing cape
    func saveCape(_ cape: CursorLibrary) {
        do {
            try cape.save()
        } catch {
            lastError = error
            showError = true
        }
    }

    /// Export a cape to file
    func exportCape(_ cape: CursorLibrary, to url: URL? = nil) {
        if let url = url {
            exportCapeToURL(cape, url: url)
        } else {
            // Show save panel
            let panel = NSSavePanel()
            panel.title = "Export Cape"
            panel.nameFieldLabel = "Export As:"
            panel.nameFieldStringValue = "\(cape.name).cape"
            panel.allowedContentTypes = [UTType(filenameExtension: "cape")].compactMap { $0 }
            panel.canCreateDirectories = true

            panel.begin { [weak self] response in
                guard response == .OK, let url = panel.url else { return }
                self?.exportCapeToURL(cape, url: url)
            }
        }
    }

    private func exportCapeToURL(_ cape: CursorLibrary, url: URL) {
        cape.underlyingLibrary.write(toFile: url.path, atomically: true)
    }

    /// Show cape in Finder
    func showInFinder(_ cape: CursorLibrary) {
        guard let url = libraryController?.url(forCape: cape.underlyingLibrary) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Request delete confirmation for a cape
    func confirmDeleteCape(_ cape: CursorLibrary) {
        capeToDelete = cape
        showDeleteConfirmation = true
    }

    /// Delete a cape (after confirmation)
    func deleteCape(_ cape: CursorLibrary) {
        // If this is the applied cape, reset first
        if appliedCape?.id == cape.id {
            resetToDefault()
        }

        // Ensure cape has a file URL before attempting to delete
        if cape.fileURL == nil {
            // Try to get URL from library controller
            if let url = libraryController?.url(forCape: cape.underlyingLibrary) {
                cape.fileURL = url
            }
        }

        // Only call removeCape if fileURL exists
        if cape.fileURL != nil {
            libraryController?.removeCape(cape.underlyingLibrary)
        } else {
            // Just remove from memory if no file exists
            print("Warning: Cape has no file URL, removing from list only")
        }

        loadCapes()

        // Clear selection if deleted cape was selected
        if selectedCape?.id == cape.id {
            selectedCape = nil
        }

        capeToDelete = nil
        showDeleteConfirmation = false
    }

    /// Refresh capes list
    func refreshCapes() {
        loadCapes()
    }

    // MARK: - Preferences

    /// Open cape folder in Finder
    func openCapeFolder() {
        guard let url = libraryController?.libraryURL else { return }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }
}

// MARK: - AppState Singleton

extension AppState {
    @MainActor static let shared = AppState()
}
