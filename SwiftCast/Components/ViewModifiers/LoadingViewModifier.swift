//
//  LoadingViewModifier.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 7/13/23.
//

import SwiftUI

struct LoadingView: ViewModifier {
    @Environment(\.appTheme) private var t
    @Binding var isLoading: Bool
    @Binding var message: String
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if isLoading {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                loader()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }

    @ViewBuilder private func loader() -> some View {
        VStack(spacing: t.spacing.medium) {
            ProgressView()
            Text(message)
                .font(t.font.body)
                .foregroundColor(t.color.foreground.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(t.padding.xl)
        .frame(minWidth: 180)
        .glassCard(cornerRadius: t.cornerRadius.medium)
        .contentShape(Rectangle())
    }
}

extension View {
    func loadingView(isLoading: Binding<Bool>, message: Binding<String> = .constant("Loading")) -> some View {
        self.modifier(LoadingView(isLoading: isLoading, message: message))
    }
}
