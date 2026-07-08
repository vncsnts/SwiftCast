//
//  CameraClipGeometry.swift
//  SwiftCast
//

import CoreGraphics

/// Resolved on-canvas geometry for the camera clip overlay: where the clip box sits,
/// how large the aspect-filled camera surface is after zoom, and the pan offset that
/// positions the focus point. Computed by `EditorViewModel` so the view stays a dumb
/// renderer, and mirrors the export compositor's math so preview and export match.
struct CameraClipGeometry {
    /// Size of the visible clip box.
    let clipSize: CGSize
    /// Center of the clip box in canvas coordinates.
    let clipCenter: CGPoint
    /// Size of the aspect-filled, zoomed camera surface behind the clip box.
    let scaledSize: CGSize
    /// Offset applied to the camera surface so the focus point is framed.
    let panOffset: CGSize
}
