//
//  FaceTrackSample.swift
//  SwiftCast
//

import CoreGraphics
import Foundation

/// One sample of a precomputed face track: where the face center is at a given
/// moment of the camera clip.
struct FaceTrackSample: Sendable {
    /// Presentation time within the clip, in seconds.
    let time: TimeInterval
    /// Face center in normalized SwiftUI coordinates (top-left origin, 0–1),
    /// before any zoom/pan anchor transform is applied.
    let point: CGPoint
}

extension Array where Element == FaceTrackSample {
    /// Binary-searches the two samples bracketing `time` and linearly interpolates
    /// between them. Clamps to the first/last sample outside the track's range.
    /// Shared by the editor's playback preview and the export compositor so both
    /// read the identical precomputed, smoothed face track.
    func interpolatedPoint(at time: TimeInterval) -> CGPoint? {
        guard let first, let last else { return nil }
        if time <= first.time { return first.point }
        if time >= last.time { return last.point }
        var low = 0
        var high = count - 1
        while high - low > 1 {
            let mid = (low + high) / 2
            if self[mid].time <= time { low = mid } else { high = mid }
        }
        let a = self[low]
        let b = self[high]
        let span = b.time - a.time
        let fraction = span > 0 ? CGFloat((time - a.time) / span) : 0
        return CGPoint(
            x: a.point.x + (b.point.x - a.point.x) * fraction,
            y: a.point.y + (b.point.y - a.point.y) * fraction
        )
    }
}
