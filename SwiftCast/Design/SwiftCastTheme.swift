//
//  SwiftCastTheme.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 6/11/26.
//

import SwiftUI

/// The default SwiftCast brand. System-adaptive colors keep the existing
/// look; tokens centralize the values previously hardcoded in views.
struct SwiftCastTheme: AppTheme {
    // MARK: - Identity
    let name = "SwiftCast"
    let colorScheme: ColorScheme? = nil

    // MARK: - Color
    let color = ThemeColor(
        foreground: ThemeForegroundColor(
            accent: Color.accentColor,
            default: Color(nsColor: .labelColor),
            secondary: Color(nsColor: .secondaryLabelColor),
            tertiary: Color(nsColor: .tertiaryLabelColor),
            onAccent: Color.white
        ),
        background: ThemeBackgroundColor(
            accent: Color.accentColor,
            gradient: LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), Color(nsColor: .underPageBackgroundColor)],
                startPoint: .top,
                endPoint: .bottom
            ),
            canvas: Color(nsColor: .windowBackgroundColor),
            card: Color(nsColor: .underPageBackgroundColor),
            cardHover: Color(nsColor: .controlBackgroundColor)
        ),
        border: ThemeBorderColor(
            default: Color(nsColor: .separatorColor)
        ),
        status: ThemeStatusColor(
            recording: Color.red,
            paused: Color.orange,
            success: Color.green
        )
    )

    // MARK: - Spacing (pt)
    let spacing = ThemeSpacing(xs: 4, small: 8, medium: 12, large: 16, xl: 24)

    // MARK: - Radii (pt)
    let cornerRadius = ThemeRadius(small: 6, medium: 16, large: 20)

    // MARK: - Typography
    let font = ThemeFont(
        heading: .system(size: 22, weight: .bold),
        iconLarge: .system(size: 40, weight: .medium),
        caption: .system(size: 11, weight: .semibold),
        body: .system(size: 13),
        helper: .system(size: 11),
        pillValue: .system(size: 13, weight: .semibold),
        pillLabel: .system(size: 11, weight: .semibold),
        button: .system(size: 13, weight: .semibold),
        hotkey: .system(size: 11, weight: .medium, design: .monospaced),
        timer: .system(size: 24, weight: .semibold, design: .monospaced)
    )
}
