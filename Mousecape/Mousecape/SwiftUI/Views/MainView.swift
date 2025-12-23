//
//  MainView.swift
//  Mousecape
//
//  Main view with page switcher (Home / Settings)
//  Uses Liquid Glass design for macOS 26+
//

import SwiftUI

struct MainView: View {
    @Environment(AppState.self) private var appState
    @Environment(LocalizationManager.self) private var localization

    var body: some View {
        @Bindable var appState = appState

        // Content
        Group {
            switch appState.currentPage {
            case .home:
                HomeView()
            case .settings:
                SettingsView()
            }
        }
        // Toolbar in title bar area
        .toolbar {
            // Center: Page switcher
            ToolbarItem(placement: .principal) {
                Picker(selection: $appState.currentPage) {
                    ForEach(AppPage.allCases) { page in
                        Text(localization.localized(page.title))
                            .tag(page)
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                // .glassEffect(.regular, in: .capsule)
                .frame(width: 160)
            }

            // Right: Action buttons (only on Home page)
            ToolbarItemGroup(placement: .primaryAction) {
                if appState.currentPage == .home {
                    Button(action: { appState.createNewCape() }) {
                        Image(systemName: "plus")
                    }
                    .help("New Cape")

                    Button(action: { appState.importCape() }) {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .help("Import Cape")

                    Button(action: {
                        if let cape = appState.selectedCape {
                            appState.applyCape(cape)
                        }
                    }) {
                        Image(systemName: "checkmark.circle")
                    }
                    .help("Apply Cape")
                    .disabled(appState.selectedCape == nil)

                    Button(action: {
                        if let cape = appState.selectedCape {
                            appState.editCape(cape)
                        }
                    }) {
                        Image(systemName: "pencil")
                    }
                    .help("Edit Cape")
                    .disabled(appState.selectedCape == nil)

                    Button(action: {
                        if let cape = appState.selectedCape {
                            appState.exportCape(cape)
                        }
                    }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .help("Export Cape")
                    .disabled(appState.selectedCape == nil)

                    Button(role: .destructive, action: {
                        if let cape = appState.selectedCape {
                            appState.confirmDeleteCape(cape)
                        }
                    }) {
                        Image(systemName: "trash")
                    }
                    .help("Delete Cape")
                    .disabled(appState.selectedCape == nil)
                }
            }
        }
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
    }
}

// MARK: - Preview

#Preview {
    MainView()
        .environment(AppState.shared)
}
