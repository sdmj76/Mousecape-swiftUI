//
//  GlassEffectContainer.swift
//  Mousecape
//
//  Container for Liquid Glass effects in macOS 26+
//  Groups multiple glass elements for shared background sampling
//

import SwiftUI

/// Container that groups multiple glass effect elements
/// Elements share background sampling for seamless appearance
struct GlassEffectContainer<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    init(spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        HStack(spacing: spacing) {
            content
        }
        // In macOS 26, this would use .glassEffectContainer
        // For now, we just group the elements
    }
}

// MARK: - Glass Effect Modifiers

extension View {
    /// Apply Liquid Glass effect with default capsule shape
    @ViewBuilder
    func glassButtonStyle() -> some View {
        self.glassEffect(.regular.interactive(), in: .circle)
    }

    /// Apply Liquid Glass effect for toolbar buttons
    @ViewBuilder
    func toolbarGlassButton() -> some View {
        self
            .buttonStyle(.borderless)
            .glassEffect(.regular.interactive(), in: .circle)
    }
}

// MARK: - Preview

#Preview("Glass Effect Container") {
    GlassEffectContainer(spacing: 8) {
        Button(action: {}) {
            Image(systemName: "plus")
        }
        .glassEffect(.regular.interactive(), in: .circle)

        Button(action: {}) {
            Image(systemName: "minus")
        }
        .glassEffect(.regular.interactive(), in: .circle)

        Button(action: {}) {
            Image(systemName: "pencil")
        }
        .glassEffect(.regular.interactive(), in: .circle)
    }
    .padding()
    .background(
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}
