//
//  LoadingViewModifier.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 7/13/23.
//

import SwiftUI

struct LoadingView: ViewModifier {
    @Binding var isLoading: Bool
    @Binding var message: String
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                loader()
            }
        }
    }
    
    @ViewBuilder private func loader() -> some View {
        VStack {
            VStack {
                Text(message)
                    .multilineTextAlignment(.center)
                ProgressView()
            }
            .padding()
        }
        .background(Color(NSColor.underPageBackgroundColor))
        .cornerRadius(10)
        .shadow(radius: 2)
        .contentShape(Rectangle())
    }
}

extension View {
    func loadingView(isLoading: Binding<Bool>, message: Binding<String> = .constant("Loading")) -> some View {
        self.modifier(LoadingView(isLoading: isLoading, message: message))
    }
}
