//
//  CameraClipLayout.swift
//  SwiftCast
//

import CoreGraphics

struct CameraClipLayout {
    /// Normalized frame (0–1) in SwiftUI coordinates (top-left origin) relative to the screen canvas.
    var frame: CGRect
    /// Zoom multiplier applied on top of the fill scale. 1.0 = fit the clip to the frame.
    var zoom: CGFloat
    /// Where inside the camera to focus (0,0 = top-left, 1,1 = bottom-right, 0.5,0.5 = center).
    var focusPoint: CGPoint
    var maskMode: CameraClipMask
    var isFaceTrackingEnabled: Bool

    static let `default` = CameraClipLayout(
        frame: CGRect(x: 0.68, y: 0.52, width: 0.28, height: 0.42),
        zoom: 1.0,
        focusPoint: CGPoint(x: 0.5, y: 0.5),
        maskMode: .none,
        isFaceTrackingEnabled: false
    )
}
