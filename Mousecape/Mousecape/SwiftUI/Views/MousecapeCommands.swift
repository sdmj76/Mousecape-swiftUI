//
//  MousecapeCommands.swift
//  Mousecape
//
//  System menu bar commands
//  Removes Edit menu, Cape menu matches context menu
//

import SwiftUI

struct MousecapeCommands: Commands {
    @FocusedValue(\.selectedCape) var selectedCapeBinding: Binding<CursorLibrary?>?

    private var selectedCape: CursorLibrary? {
        selectedCapeBinding?.wrappedValue
    }

    var body: some Commands {
        // Replace default New Document command
        CommandGroup(replacing: .newItem) {
            Button("New Cape") {
                Task { @MainActor in
                    AppState.shared.createNewCape()
                }
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("Import Cape...") {
                Task { @MainActor in
                    AppState.shared.importCape()
                }
            }
            .keyboardShortcut("i", modifiers: .command)

            Divider()

            Button("Open Cape Folder") {
                Task { @MainActor in
                    AppState.shared.openCapeFolder()
                }
            }
        }

        // Remove Edit menu items (Undo/Redo/Cut/Copy/Paste)
        CommandGroup(replacing: .textEditing) { }
        CommandGroup(replacing: .undoRedo) { }
        CommandGroup(replacing: .pasteboard) { }

        // Cape menu - matches context menu
        CommandMenu("Cape") {
            Button("Apply") {
                if let cape = selectedCape {
                    Task { @MainActor in
                        AppState.shared.applyCape(cape)
                    }
                }
            }
            .keyboardShortcut("a", modifiers: .command)
            .disabled(selectedCape == nil)

            Button("Edit") {
                if let cape = selectedCape {
                    Task { @MainActor in
                        AppState.shared.editCape(cape)
                    }
                }
            }
            .keyboardShortcut("e", modifiers: .command)
            .disabled(selectedCape == nil)

            Divider()

            Button("Export...") {
                if let cape = selectedCape {
                    Task { @MainActor in
                        AppState.shared.exportCape(cape)
                    }
                }
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(selectedCape == nil)

            Button("Show in Finder") {
                if let cape = selectedCape {
                    Task { @MainActor in
                        AppState.shared.showInFinder(cape)
                    }
                }
            }
            .disabled(selectedCape == nil)

            Divider()

            Button("Reset to Default") {
                Task { @MainActor in
                    AppState.shared.resetToDefault()
                }
            }
            .keyboardShortcut("r", modifiers: .command)

            Divider()

            Button("Delete") {
                if let cape = selectedCape {
                    Task { @MainActor in
                        AppState.shared.confirmDeleteCape(cape)
                    }
                }
            }
            .keyboardShortcut(.delete)
            .disabled(selectedCape == nil)
        }

        // View menu
        CommandMenu("View") {
            Button("Refresh") {
                Task { @MainActor in
                    AppState.shared.refreshCapes()
                }
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
        }

        // Help menu
        CommandGroup(replacing: .help) {
            Button("Mousecape Help") {
                if let url = URL(string: "https://github.com/alexzielenski/Mousecape#readme") {
                    NSWorkspace.shared.open(url)
                }
            }

            Button("Report an Issue") {
                if let url = URL(string: "https://github.com/alexzielenski/Mousecape/issues") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}
