//
//  MaterialView.swift
//  RecordMe
//
//  Created by Vince Carlo Santos on 6/10/23.
//

import SwiftUI

struct MaterialView: NSViewRepresentable {
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct MaterialViewModifier: ViewModifier {
    
    func body(content: Content) -> some View {
        content
            .background(MaterialView())
    }
}

extension View {
    func materialBackground() -> some View {
        self.modifier(MaterialViewModifier())
    }
}
