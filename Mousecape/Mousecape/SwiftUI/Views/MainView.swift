//
//  MainView.swift
//  Mousecape
//
//  Main view with page-based navigation (Home / Settings)
//  Uses toolbar buttons for page switching
//

import SwiftUI

struct MainView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        switch appState.currentPage {
        case .home:
            HomeView()
        case .settings:
            SettingsView()
        }
    }
}

// MARK: - Preview

#Preview {
    MainView()
        .environment(AppState.shared)
        .environment(LocalizationManager.shared)
}
