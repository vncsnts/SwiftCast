//
//  VideoEditorManager.swift
//  SwiftCast
//

import Foundation

@MainActor
protocol VideoEditorManager: AnyObject {
    var selectedSession: RecordingSession? { get }
    var cameraClipLayout: CameraClipLayout { get set }
    var isInManualFocusMode: Bool { get }
    var isExporting: Bool { get }
    var exportProgress: Double { get }
    var exportedURL: URL? { get }

    func loadSession(_ session: RecordingSession)
    func setMaskMode(_ mode: CameraClipMask)
    func setZoom(_ zoom: CGFloat)
    func setFocusPoint(_ point: CGPoint)
    func toggleFaceTracking()
    func enterManualFocusMode()
    func exitManualFocusMode()
    func resetLayout()
}
