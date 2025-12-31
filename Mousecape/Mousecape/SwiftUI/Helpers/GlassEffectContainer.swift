//
//  GlassEffectContainer.swift
//  Mousecape
//
//  Container for visual effects
//  Uses Liquid Glass on macOS 26+, Material backgrounds on macOS 15
//

import SwiftUI

/// Container that groups multiple visual effect elements
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
    }
}

// MARK: - Adaptive Glass/Material Effect Modifiers

extension View {
    /// Apply glass effect on macOS 26+, material background on macOS 15
    @ViewBuilder
    func adaptiveGlass(in shape: some Shape = RoundedRectangle(cornerRadius: 12)) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.regularMaterial, in: shape)
        }
    }

    /// Apply clear/subtle glass effect on macOS 26+, ultra thin material on macOS 15
    @ViewBuilder
    func adaptiveGlassClear(in shape: some Shape = RoundedRectangle(cornerRadius: 12)) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.clear, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }

    /// Apply tinted glass effect (e.g., for "Applied" badge)
    @ViewBuilder
    func adaptiveGlassTinted(color: Color, in shape: some Shape = .capsule) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular.tint(color), in: shape)
        } else {
            self.background(color.opacity(0.2), in: shape)
                .background(.regularMaterial, in: shape)
        }
    }

    /// Apply conditional glass effect based on state (selected/hovered)
    @ViewBuilder
    func adaptiveGlassConditional(
        isActive: Bool,
        in shape: some Shape = RoundedRectangle(cornerRadius: 10)
    ) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(isActive ? .regular : .clear, in: shape)
        } else {
            self.background(
                isActive ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(.clear),
                in: shape
            )
        }
    }

    /// Apply glass button style
    @ViewBuilder
    func glassButtonStyle() -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: .circle)
        } else {
            self.background(.regularMaterial, in: .circle)
        }
    }

    /// Apply toolbar glass button style
    @ViewBuilder
    func toolbarGlassButton() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.borderless)
                .glassEffect(.regular.interactive(), in: .circle)
        } else {
            self.buttonStyle(.borderless)
                .background(.regularMaterial, in: .circle)
        }
    }
}

// MARK: - Adaptive Toolbar Spacer

/// Adaptive toolbar spacer that uses ToolbarSpacer on macOS 26+
/// On macOS 15, toolbar items are placed without explicit spacers
struct AdaptiveToolbarSpacer: ToolbarContent {
    enum SpacerType {
        case flexible
        case fixed
    }

    let type: SpacerType

    init(_ type: SpacerType = .flexible) {
        self.type = type
    }

    var body: some ToolbarContent {
        if #available(macOS 26.0, *) {
            switch type {
            case .flexible:
                ToolbarSpacer(.flexible)
            case .fixed:
                ToolbarSpacer(.fixed)
            }
        } else {
            // On macOS 15, no spacer needed - toolbar handles layout automatically
            ToolbarItem { EmptyView() }
        }
    }
}

// MARK: - Preview

#Preview("Glass Effect Container") {
    GlassEffectContainer(spacing: 8) {
        Button(action: {}) {
            Image(systemName: "plus")
        }
        .glassButtonStyle()

        Button(action: {}) {
            Image(systemName: "minus")
        }
        .glassButtonStyle()

        Button(action: {}) {
            Image(systemName: "pencil")
        }
        .glassButtonStyle()
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
