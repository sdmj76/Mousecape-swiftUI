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

    /// Edit mode: selected cursor
    var editingSelectedCursor: Cursor?

    /// Edit mode: show cape info panel
    var showCapeInfo: Bool = false

    /// Edit mode: track if changes were made (manual tracking)
    var hasUnsavedChanges: Bool = false

    /// Refresh trigger for cursor list (increment to force refresh)
    var cursorListRefreshTrigger: Int = 0

    /// Refresh trigger for cape info (file name display)
    var capeInfoRefreshTrigger: Int = 0

    /// Refresh trigger for cape list/grid (increment to force refresh)
    var capeListRefreshTrigger: Int = 0

    /// Show add cursor sheet
    var showAddCursorSheet: Bool = false

    /// Show delete cursor confirmation
    var showDeleteCursorConfirmation: Bool = false

    /// Delete confirmation state
    var showDeleteConfirmation: Bool = false
    var capeToDelete: CursorLibrary?

    /// Discard changes confirmation state
    var showDiscardConfirmation: Bool = false

    /// Duplicate filename error state
    var showDuplicateFilenameError: Bool = false
    var duplicateFilename: String = ""

    /// Validation error state
    var showValidationError: Bool = false
    var validationErrorMessage: String = ""

    /// Image import warning state (for non-square images)
    var showImageImportWarning: Bool = false
    var imageImportWarningMessage: String = ""

    /// Loading state
    var isLoading: Bool = false

    /// Error state
    var lastError: Error?
    var showError: Bool = false

    // MARK: - Undo/Redo

    /// Undo stack - stores closures to undo changes
    private var undoStack: [() -> Void] = []

    /// Redo stack - stores closures to redo changes
    private var redoStack: [() -> Void] = []

    /// Maximum undo history size
    private let maxUndoHistory = 20

    /// Whether undo is available
    var canUndo: Bool { !undoStack.isEmpty }

    /// Whether redo is available
    var canRedo: Bool { !redoStack.isEmpty }

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

        // Remember current selections by their underlying ObjC objects
        let selectedObjc = selectedCape?.underlyingLibrary
        let appliedObjc = appliedCape?.underlyingLibrary

        // Load capes from the ObjC controller
        if let objcCapes = controller.capes as? Set<MCCursorLibrary> {
            capes = objcCapes.map { CursorLibrary(objcLibrary: $0) }
            capes.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        // Restore selections by finding wrappers for the same ObjC objects
        if let selectedObjc = selectedObjc {
            selectedCape = capes.first { $0.underlyingLibrary === selectedObjc }
        }

        // Check for applied cape (from controller or previously tracked)
        if let applied = controller.appliedCape {
            appliedCape = capes.first { $0.underlyingLibrary === applied }
        } else if let appliedObjc = appliedObjc {
            appliedCape = capes.first { $0.underlyingLibrary === appliedObjc }
        }
    }

    private func loadPreferences() {
        // Reserved for future preferences loading
    }

    // MARK: - Cape Actions

    /// Create a new empty cape
    func createNewCape() {
        let author = NSFullUserName()
        let baseName = "New Cape"

        // Find unique name by adding suffix if needed
        let uniqueName = findUniqueName(baseName: baseName, author: author)
        let newCape = CursorLibrary(name: uniqueName, author: author)

        // Set file URL before adding to library (required for save/delete)
        if let libraryURL = libraryController?.libraryURL {
            let fileURL = libraryURL.appendingPathComponent("\(newCape.identifier).cape")
            newCape.fileURL = fileURL
            // Save immediately to create the file
            newCape.underlyingLibrary.write(toFile: fileURL.path, atomically: true)
        }

        addCape(newCape)
        selectedCape = newCape
        capeInfoRefreshTrigger += 1  // Refresh file name display
        editCape(newCape)
    }

    /// Find a unique name by adding suffix (1), (2), etc. if needed
    private func findUniqueName(baseName: String, author: String) -> String {
        var name = baseName
        var counter = 1

        while isIdentifierExists(name: name, author: author) {
            name = "\(baseName) (\(counter))"
            counter += 1
        }

        return name
    }

    /// Check if a cape with the given name/author combination already exists
    private func isIdentifierExists(name: String, author: String, excludingCape: CursorLibrary? = nil) -> Bool {
        let identifier = generateIdentifier(name: name, author: author)

        // Check existing files
        if let libraryURL = libraryController?.libraryURL {
            let fileURL = libraryURL.appendingPathComponent("\(identifier).cape")
            if FileManager.default.fileExists(atPath: fileURL.path) {
                // If we're excluding a cape and its fileURL matches, it's not a conflict
                if let excluding = excludingCape, excluding.fileURL == fileURL {
                    return false
                }
                return true
            }
        }

        return false
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
        // Save identifier for "Apply Last Cape on Launch" feature
        UserDefaults.standard.set(cape.identifier, forKey: "lastAppliedCapeIdentifier")
        // Also write MCAppliedCursor for mousecloakhelper (ObjC helper daemon)
        // Uses CFPreferences to write to current user + current host domain
        CFPreferencesSetValue(
            "MCAppliedCursor" as CFString,
            cape.identifier as CFString,
            "com.alexzielenski.Mousecape" as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        )
        CFPreferencesSynchronize(
            "com.alexzielenski.Mousecape" as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        )
    }

    /// Reset to default system cursors
    func resetToDefault() {
        libraryController?.restoreCape()
        appliedCape = nil
        // Clear last applied cape identifier
        UserDefaults.standard.removeObject(forKey: "lastAppliedCapeIdentifier")
        // Also clear MCAppliedCursor for mousecloakhelper
        CFPreferencesSetValue(
            "MCAppliedCursor" as CFString,
            nil,
            "com.alexzielenski.Mousecape" as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        )
        CFPreferencesSynchronize(
            "com.alexzielenski.Mousecape" as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        )
    }

    /// Edit a cape
    func editCape(_ cape: CursorLibrary) {
        // Invalidate cursor cache to ensure fresh data when entering edit mode
        cape.invalidateCursorCache()
        editingCape = cape
        isEditing = true
        hasUnsavedChanges = false
        capeInfoRefreshTrigger += 1  // Refresh file name display
        clearUndoHistory()
    }

    /// Mark that changes have been made
    func markAsChanged() {
        hasUnsavedChanges = true
    }

    /// Register an undoable change
    /// - Parameters:
    ///   - undoAction: Closure to undo the change
    ///   - redoAction: Closure to redo the change
    func registerUndo(undo undoAction: @escaping () -> Void, redo redoAction: @escaping () -> Void) {
        // Clear redo stack when new action is registered
        redoStack.removeAll()

        // Add to undo stack
        undoStack.append(undoAction)

        // Limit stack size
        if undoStack.count > maxUndoHistory {
            undoStack.removeFirst()
        }

        hasUnsavedChanges = true
    }

    /// Undo the last change
    func undo() {
        guard let undoAction = undoStack.popLast() else { return }
        undoAction()

        // If no more undo actions, check if we're back to saved state
        if undoStack.isEmpty {
            hasUnsavedChanges = false
        }
    }

    /// Redo the last undone change
    func redo() {
        guard let redoAction = redoStack.popLast() else { return }
        redoAction()
        hasUnsavedChanges = true
    }

    /// Clear undo/redo history
    func clearUndoHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
    }

    /// Request to close edit mode (may show confirmation if dirty)
    func requestCloseEdit() {
        if hasUnsavedChanges {
            showDiscardConfirmation = true
        } else {
            closeEdit()
        }
    }

    /// Close edit mode (discard changes)
    func closeEdit() {
        // Revert unsaved changes
        if hasUnsavedChanges {
            editingCape?.revertToSaved()
        }
        isEditing = false
        editingCape = nil
        editingSelectedCursor = nil
        showCapeInfo = false
        showDiscardConfirmation = false
        hasUnsavedChanges = false
        clearUndoHistory()
    }

    /// Close edit mode after saving
    func closeEditWithSave() {
        if let cape = editingCape {
            // Only close if save succeeds
            guard saveCape(cape) else { return }
            // Invalidate cursor cache to ensure fresh data on next access
            cape.invalidateCursorCache()
        }

        // Remember the cape we just edited (by its underlying ObjC object)
        let savedObjcCape = editingCape?.underlyingLibrary

        isEditing = false
        editingCape = nil
        editingSelectedCursor = nil
        showCapeInfo = false
        showDiscardConfirmation = false
        hasUnsavedChanges = false
        clearUndoHistory()

        // Reload capes to refresh the list with latest data
        // This will find the new wrapper for the same ObjC object
        loadCapes()

        // Select the cape we just saved (find its new wrapper)
        if let savedObjcCape = savedObjcCape {
            selectedCape = capes.first { $0.underlyingLibrary === savedObjcCape }
        }

        // Force UI refresh for cape list and preview panel
        capeListRefreshTrigger += 1
    }

    /// Save the currently editing cape
    /// Returns true if save was successful, false if blocked by validation or duplicate filename
    @discardableResult
    func saveCape(_ cape: CursorLibrary) -> Bool {
        // Validate all fields first
        guard validateBeforeSave() else { return false }

        // Generate new identifier based on current Name and Author
        let newIdentifier = generateIdentifier(name: cape.name, author: cape.author)

        // Check for duplicate filename (excluding current cape)
        if isIdentifierExists(name: cape.name, author: cape.author, excludingCape: cape) {
            duplicateFilename = "\(newIdentifier).cape"
            showDuplicateFilenameError = true
            return false
        }

        do {
            // Update identifier and fileURL if changed
            if let libraryURL = libraryController?.libraryURL {
                let oldFileURL = cape.fileURL
                let newFileURL = libraryURL.appendingPathComponent("\(newIdentifier).cape")

                // If filename will change, delete old file and update URL
                if oldFileURL != newFileURL {
                    // Delete old file if it exists
                    if let oldURL = oldFileURL {
                        try? FileManager.default.removeItem(at: oldURL)
                    }
                    cape.fileURL = newFileURL
                }

                // Update identifier
                cape.identifier = newIdentifier
            }

            try cape.save()
            hasUnsavedChanges = false
            capeInfoRefreshTrigger += 1  // Refresh file name display
            clearUndoHistory()  // Clear undo history after save
            // Invalidate cursor cache to ensure fresh data
            cape.invalidateCursorCache()
            return true
        } catch {
            lastError = error
            showError = true
            return false
        }
    }

    /// Generate identifier from name and author
    private func generateIdentifier(name: String, author: String) -> String {
        let sanitizedAuthor = CursorLibrary.sanitizeIdentifierComponent(author.isEmpty ? "Unknown" : author)
        let sanitizedName = CursorLibrary.sanitizeIdentifierComponent(name.isEmpty ? "Untitled" : name)
        return "local.\(sanitizedAuthor).\(sanitizedName)"
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
        let wasSelected = selectedCape?.id == cape.id
        let wasApplied = appliedCape?.id == cape.id

        // Clear selection first if this cape was selected (before deletion)
        if wasSelected {
            selectedCape = nil
        }

        // If this is the applied cape, reset to default
        if wasApplied {
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

        capeToDelete = nil
        showDeleteConfirmation = false
    }

    /// Refresh capes list
    func refreshCapes() {
        loadCapes()
    }

    // MARK: - Cursor Actions (Edit Mode)

    /// Delete the currently selected cursor
    func deleteSelectedCursor() {
        guard let cape = editingCape, let cursor = editingSelectedCursor else { return }
        cape.removeCursor(cursor)
        editingSelectedCursor = cape.cursors.first
        markAsChanged()
        cursorListRefreshTrigger += 1
        showDeleteCursorConfirmation = false
    }

    /// Add a cursor with the given type
    func addCursor(type: CursorType) {
        guard let cape = editingCape else { return }
        let newCursor = Cursor(identifier: type.rawValue)
        cape.addCursor(newCursor)
        editingSelectedCursor = newCursor
        markAsChanged()
        cursorListRefreshTrigger += 1
    }

    // MARK: - Preferences

    /// Open cape folder in Finder
    func openCapeFolder() {
        guard let url = libraryController?.libraryURL else { return }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }

    // MARK: - Validation

    /// Characters allowed in Name and Author fields
    /// Allows alphanumerics, spaces, and some safe punctuation
    static let allowedNameCharacters = CharacterSet.alphanumerics
        .union(CharacterSet(charactersIn: " -_()"))

    /// Check if a string is valid for Name/Author fields
    static func isValidNameOrAuthor(_ string: String) -> Bool {
        guard !string.isEmpty else { return false }
        return string.unicodeScalars.allSatisfy { allowedNameCharacters.contains($0) }
    }

    /// Filter a string to only contain valid Name/Author characters
    static func filterNameOrAuthor(_ string: String) -> String {
        String(string.unicodeScalars.filter { allowedNameCharacters.contains($0) })
    }

    /// Validate all fields before saving
    /// Returns true if valid, false if validation failed (shows error alert)
    func validateBeforeSave() -> Bool {
        guard let cape = editingCape else { return false }

        var errors: [String] = []

        // Validate cape name
        if cape.name.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("Name cannot be empty")
        }

        // Validate cape author
        if cape.author.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("Author cannot be empty")
        }

        // Validate cape version
        if cape.version <= 0 {
            errors.append("Version must be greater than 0")
        }

        // Validate ALL cursor fields (not just selected cursor)
        for cursor in cape.cursors {
            let cursorName = cursor.displayName

            if cursor.size.width <= 0 || cursor.size.height <= 0 {
                errors.append("[\(cursorName)] Size must be greater than 0")
            }
            if cursor.frameCount <= 0 {
                errors.append("[\(cursorName)] Frame count must be at least 1")
            }
            if cursor.frameDuration < 0 {
                errors.append("[\(cursorName)] Frame duration cannot be negative")
            }
            if cursor.hotSpot.x < 0 || cursor.hotSpot.y < 0 {
                errors.append("[\(cursorName)] Hotspot cannot be negative")
            }
        }

        if !errors.isEmpty {
            validationErrorMessage = errors.joined(separator: "\n")
            showValidationError = true
            return false
        }

        return true
    }
}

// MARK: - AppState Singleton

extension AppState {
    @MainActor static let shared = AppState()
}
