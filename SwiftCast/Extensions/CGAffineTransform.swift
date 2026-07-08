//
//  CGAffineTransform.swift
//  SwiftCast
//

import CoreGraphics
import ImageIO

extension CGAffineTransform {
    /// Maps a video track's `preferredTransform` to the equivalent EXIF orientation.
    ///
    /// Decoded pixel buffers (AVAssetReader, custom AVVideoCompositing sources) arrive in
    /// the track's *natural* orientation — the preferredTransform is metadata that players
    /// apply at display time. Anything that analyzes or composites raw buffers must apply
    /// the same rotation itself or its coordinates/output won't match what AVPlayer shows.
    var videoOrientation: CGImagePropertyOrientation {
        let mirrored = (a * d - b * c) < 0
        // A mirrored transform decomposes as rotation ∘ horizontal-flip; factor the flip
        // out before reading the angle, or a plain selfie mirror (a: -1, d: 1 — what the
        // camera recorder writes, and what ffprobe misreports as "rotation: -180")
        // misclassifies as .downMirrored, a vertical flip.
        let angle = mirrored ? atan2(-b, -a) : atan2(b, a)
        // Quarter-turns of the rotation component, in video space (top-left, y-down).
        switch (Int((angle / (.pi / 2)).rounded()) + 4) % 4 {
        case 1: return mirrored ? .rightMirrored : .right
        case 2: return mirrored ? .downMirrored : .down
        case 3: return mirrored ? .leftMirrored : .left
        default: return mirrored ? .upMirrored : .up
        }
    }
}
