//
//  FaceTrackingService.swift
//  SwiftCast
//

import Foundation

protocol FaceTrackingService: Actor {
    /// Walks the entire video at `url` offline and returns a smoothed face-center
    /// track (normalized SwiftUI top-left coordinates), sampled at a fixed rate
    /// and sorted by time. Results are cached per URL, so repeat calls are cheap.
    func analyzeFaceTrack(url: URL) async throws -> [FaceTrackSample]
}
