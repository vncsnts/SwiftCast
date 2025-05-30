//
//  MaterialView.swift
//  RecordMe
//
//  Created by Vince Carlo Santos on 6/10/23.
//

import SwiftUI

/// A SwiftUI wrapper for NSVisualEffectView to provide a material background.
struct MaterialView: NSViewRepresentable {
    /// Creates the NSVisualEffectView.
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        return view
    }
    /// Updates the NSVisualEffectView (no-op).
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// A view modifier that adds a material background to a view.
struct MaterialViewModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(MaterialView())
    }
}

extension View {
    /// Adds a material background to the view.
    func materialBackground() -> some View {
        self.modifier(MaterialViewModifier())
    }
}
