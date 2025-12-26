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
    @Environment(LocalizationManager.self) private var localization

    var body: some View {
        ZStack {
            switch appState.currentPage {
            case .home:
                HomeView()
            case .settings:
                SettingsView()
            }

            // Loading overlay
            if appState.isLoading {
                LoadingOverlayView(message: appState.loadingMessage)
            }
        }
        .alert(
            appState.importResultIsSuccess ? localization.localized("Import Complete") : localization.localized("Import Failed"),
            isPresented: Binding(
                get: { appState.showImportResult },
                set: { appState.showImportResult = $0 }
            )
        ) {
            Button(localization.localized("OK")) {
                appState.showImportResult = false
            }
        } message: {
            Text(appState.importResultMessage)
        }
    }
}

// MARK: - Loading Overlay

struct LoadingOverlayView: View {
    let message: String

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            // Loading card
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle())

                Text(message)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .shadow(radius: 20)
            )
        }
    }
}

// MARK: - Preview

#Preview {
    MainView()
        .environment(AppState.shared)
        .environment(LocalizationManager.shared)
}
