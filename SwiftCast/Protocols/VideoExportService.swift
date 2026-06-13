//
//  VideoExportService.swift
//  SwiftCast
//

import Foundation

protocol VideoExportService: Actor {
    func exportVideo(
        session: RecordingSession,
        layout: CameraClipLayout,
        onProgress: @Sendable @escaping (Double) -> Void
    ) async throws -> URL
}
