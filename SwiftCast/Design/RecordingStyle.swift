//
//  RecordingStyle.swift
//  SwiftCast
//

import SwiftUI

/// Resolved visual properties for the recording screen. All styling the view needs
/// beyond direct theme-token reads is externalised here — no inline magic numbers in
/// the view. `makeStyle(with:)` is the only place values are decided.
struct RecordingStyle {
    let previewHeight: CGFloat
    let statusDotDiameter: CGFloat
    /// Width of the leading icon column in a source row; the row divider indents past it.
    let sourceRowIconWidth: CGFloat
    let librarySheetSize: CGSize

    static func makeStyle(with theme: any AppTheme) -> RecordingStyle {
        RecordingStyle(
            previewHeight: 240,
            statusDotDiameter: 7,
            sourceRowIconWidth: 20,
            librarySheetSize: CGSize(width: 860, height: 640)
        )
    }
}
