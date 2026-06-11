//
//  AppTheme.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 6/11/26.
//

import SwiftUI

/// Declares every visual token a brand must provide, grouped into namespaces
/// so new views get autocomplete-driven access: `t.color.foreground.accent`,
/// `t.color.background.card`, `t.spacing.medium`, `t.padding.large`,
/// `t.cornerRadius.small`, `t.font.heading`, etc.
///
/// Views read tokens via `@Environment(\.appTheme)` and never hardcode
/// colors, fonts, spacing, or radii. A new brand is created by adding a new
/// conformer only — views never change.
protocol AppTheme {
    // MARK: - Identity
    var name: String { get }
    /// nil follows the system appearance (HIG default); set to force a scheme.
    var colorScheme: ColorScheme? { get }

    // MARK: - Token groups
    var color: ThemeColor { get }
    var spacing: ThemeSpacing { get }
    var cornerRadius: ThemeRadius { get }
    var font: ThemeFont { get }
}

extension AppTheme {
    /// Padding shares the spacing scale; exposed under its own name so padding
    /// contexts read naturally: `.padding(t.padding.large)`.
    var padding: ThemeSpacing { spacing }
}

// MARK: - Token groups

/// Color tokens, grouped by role: `foreground` (text/icons), `background`
/// (fills/surfaces), `border` (hairlines/dividers), and `status` (state
/// indicators). Brands vary these freely; views reference them by role.
struct ThemeColor {
    let foreground: ThemeForegroundColor
    let background: ThemeBackgroundColor
    let border: ThemeBorderColor
    let status: ThemeStatusColor
}

/// Colors painted on text, icons, and symbols.
struct ThemeForegroundColor {
    let accent: Color
    let `default`: Color
    let secondary: Color
    let tertiary: Color
    let onAccent: Color
}

/// Colors used to fill shapes, cards, and window surfaces.
struct ThemeBackgroundColor {
    let accent: Color
    let gradient: LinearGradient
    let canvas: Color
    let card: Color
    let cardHover: Color
}

/// Colors used for hairlines and dividers.
struct ThemeBorderColor {
    let `default`: Color
}

/// Colors that communicate recording/session state.
struct ThemeStatusColor {
    let recording: Color
    let paused: Color
    let success: Color
}

/// Spacing scale (pt). Used for both layout spacing and padding.
struct ThemeSpacing {
    let xs: CGFloat
    let small: CGFloat
    let medium: CGFloat
    let large: CGFloat
    let xl: CGFloat
}

/// Corner radius scale (pt).
struct ThemeRadius {
    let small: CGFloat
    let medium: CGFloat
    let large: CGFloat
}

/// Typography tokens, named by role.
struct ThemeFont {
    let heading: Font
    let iconLarge: Font
    let caption: Font
    let body: Font
    let helper: Font
    let pillValue: Font
    let pillLabel: Font
    let button: Font
    let hotkey: Font
    let timer: Font
}
