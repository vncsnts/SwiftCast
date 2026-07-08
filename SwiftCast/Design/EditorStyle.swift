//
//  EditorStyle.swift
//  SwiftCast
//

import SwiftUI

/// Resolved visual properties for the editor screen. All styling the view needs beyond
/// direct theme-token reads is externalised here — no inline magic numbers in the view.
/// `makeStyle(with:)` is the only place values are decided: theme tokens where a token
/// exists, editor-specific component tokens otherwise.
struct EditorStyle {
    // MARK: - Canvas
    let playbackButtonFont: Font
    let playbackButtonDiameter: CGFloat
    let playbackButtonScrim: Color
    let playbackIconColor: Color
    let playbackButtonPadding: CGFloat
    let focusRingWidth: CGFloat
    let focusRingGlowRadius: CGFloat
    let focusHairlineWidth: CGFloat
    let dragOutlineWidth: CGFloat
    let dragOutlineCornerRadius: CGFloat

    // MARK: - Toolbar
    let toolbarHeight: CGFloat
    let toolbarDividerHeight: CGFloat
    let zoomSliderWidth: CGFloat
    let maskIconFont: Font
    let maskIconButtonSize: CGFloat

    static func makeStyle(with theme: any AppTheme) -> EditorStyle {
        EditorStyle(
            playbackButtonFont: .system(size: 18, weight: .semibold),
            playbackButtonDiameter: 40,
            playbackButtonScrim: Color.black.opacity(0.45),
            playbackIconColor: theme.color.foreground.onAccent,
            playbackButtonPadding: theme.padding.medium,
            focusRingWidth: 3,
            focusRingGlowRadius: 8,
            focusHairlineWidth: 1,
            dragOutlineWidth: 1.5,
            dragOutlineCornerRadius: 2,
            toolbarHeight: 80,
            toolbarDividerHeight: 60,
            zoomSliderWidth: 100,
            maskIconFont: .system(size: 16),
            maskIconButtonSize: 30
        )
    }
}
