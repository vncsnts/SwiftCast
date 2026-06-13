//
//  DefaultVideoEditorManager.swift
//  SwiftCast
//

import Foundation

@MainActor
final class DefaultVideoEditorManager: ObservableObject, VideoEditorManager {
    static let shared = DefaultVideoEditorManager()

    @Published private(set) var selectedSession: RecordingSession?
    @Published var cameraClipLayout: CameraClipLayout = .default
    @Published private(set) var isInManualFocusMode = false
    @Published private(set) var isExporting = false
    @Published private(set) var exportProgress: Double = 0
    @Published private(set) var exportedURL: URL?

    func loadSession(_ session: RecordingSession) {
        selectedSession = session
        cameraClipLayout = .default
        exportedURL = session.exportedVideoURL
        isInManualFocusMode = false
        exportProgress = 0
    }

    func setMaskMode(_ mode: CameraClipMask) {
        cameraClipLayout.maskMode = mode
    }

    func setZoom(_ zoom: CGFloat) {
        cameraClipLayout.zoom = max(1.0, min(zoom, 4.0))
    }

    func setFocusPoint(_ point: CGPoint) {
        cameraClipLayout.focusPoint = CGPoint(
            x: max(0, min(point.x, 1)),
            y: max(0, min(point.y, 1))
        )
    }

    func toggleFaceTracking() {
        cameraClipLayout.isFaceTrackingEnabled.toggle()
    }

    func enterManualFocusMode() {
        isInManualFocusMode = true
    }

    func exitManualFocusMode() {
        isInManualFocusMode = false
    }

    func resetLayout() {
        cameraClipLayout = .default
    }

    func beginExport(using service: any VideoExportService) {
        guard let session = selectedSession else { return }
        let layout = cameraClipLayout
        isExporting = true
        exportProgress = 0
        exportedURL = nil
        Task {
            do {
                let url = try await service.exportVideo(session: session, layout: layout) { [weak self] progress in
                    Task { @MainActor [weak self] in
                        self?.exportProgress = progress
                    }
                }
                exportedURL = url
                isExporting = false
            } catch {
                isExporting = false
            }
        }
    }
}
