//
//  LoadingViewModifier.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 7/13/23.
//

import SwiftUI

/// A view modifier that overlays a loading indicator and message over content.
struct LoadingView: ViewModifier {
    /// Indicates whether the loading view should be shown.
    @Binding var isLoading: Bool
    /// The message to display in the loading view.
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
    
    /// The loading indicator and message view.
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
    /// Adds a loading overlay to the view.
    /// - Parameters:
    ///   - isLoading: Binding to control loading state.
    ///   - message: Binding for the loading message.
    func loadingView(isLoading: Binding<Bool>, message: Binding<String> = .constant("Loading")) -> some View {
        self.modifier(LoadingView(isLoading: isLoading, message: message))
    }
}
