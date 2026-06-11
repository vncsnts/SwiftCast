//
//  ThemeEnvironment.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 6/11/26.
//

import SwiftUI

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: any AppTheme = SwiftCastTheme()
}

extension EnvironmentValues {
    var appTheme: any AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}

extension View {
    /// Injects a brand theme for the entire hierarchy below this view.
    /// Re-tints the UI without layout changes.
    func theme(_ theme: any AppTheme) -> some View {
        self
            .environment(\.appTheme, theme)
            .preferredColorScheme(theme.colorScheme)
    }
}
