//
//  GlassViewModifier.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 6/11/26.
//

import SwiftUI

/// Liquid Glass adapters: render real glass on macOS 26+ and fall back to
/// translucent materials on earlier systems, so call sites stay
/// version-agnostic.
extension View {
    /// Grouped-card surface: Liquid Glass on macOS 26+, ultra-thin material earlier.
    @ViewBuilder
    func glassCard(cornerRadius: CGFloat) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    /// Pill/badge surface: Liquid Glass capsule on macOS 26+, material capsule earlier.
    @ViewBuilder
    func glassCapsule() -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect()
        } else {
            self.background(.ultraThinMaterial, in: Capsule())
        }
    }

    /// Frosted window background on macOS 15+, default window chrome earlier.
    @ViewBuilder
    func windowGlassBackground() -> some View {
        if #available(macOS 15.0, *) {
            self.containerBackground(.ultraThinMaterial, for: .window)
        } else {
            self
        }
    }

    /// Largest available control size for primary action buttons.
    @ViewBuilder
    func primaryControlSize() -> some View {
        if #available(macOS 14.0, *) {
            self.controlSize(.extraLarge)
        } else {
            self.controlSize(.large)
        }
    }
}
