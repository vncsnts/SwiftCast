//
//  EditorViewModel.swift
//  SwiftCast
//

import AVFoundation
import Vision
import SwiftUI

@MainActor
final class EditorViewModel: ObservableObject {
    @Published var cameraClipLayout: CameraClipLayout = .default
    @Published var isInManualFocusMode = false
    @Published var isExporting = false
    @Published var exportProgress: Double = 0
    @Published var exportedURL: URL?
    @Published var alertMessage = ""
    @Published var isOnAlert = false
    @Published var showExportSuccess = false

    @Published var isPlaying = false
    /// Actual aspect ratio of the screen clip. Starts at 16:9 and updates once the asset loads.
    @Published var screenAspectRatio: CGFloat = 16.0 / 9.0

    // Drag state for repositioning the camera clip
    @Published var isDraggingClip = false
    private var dragStartFrame: CGRect = .zero

    let session: RecordingSession

    let screenPlayer: AVPlayer
    let cameraPlayer: AVPlayer

    init(session: RecordingSession) {
        self.session = session
        screenPlayer = AVPlayer(url: session.screenClipURL ?? URL(fileURLWithPath: ""))
        cameraPlayer = AVPlayer(url: session.cameraClipURL ?? URL(fileURLWithPath: ""))
        if session.exportedVideoURL != nil {
            exportedURL = session.exportedVideoURL
        }
        Task { await loadScreenAspectRatio() }
    }

    private func loadScreenAspectRatio() async {
        guard let url = session.screenClipURL else { return }
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first else { return }
        guard let naturalSize = try? await track.load(.naturalSize),
              let transform = try? await track.load(.preferredTransform) else { return }
        // Apply the track transform to get the display-oriented dimensions.
        let transformedSize = naturalSize.applying(transform)
        let w = abs(transformedSize.width)
        let h = abs(transformedSize.height)
        guard h > 0 else { return }
        screenAspectRatio = w / h
    }

    // MARK: - Layout Mutations

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
        if cameraClipLayout.isFaceTrackingEnabled {
            detectFaceAndSetFocusPoint()
        }
    }

    func enterManualFocusMode() {
        isInManualFocusMode = true
    }

    func exitManualFocusMode() {
        isInManualFocusMode = false
    }

    func resetLayout() {
        cameraClipLayout = .default
        isInManualFocusMode = false
    }

    // MARK: - Drag

    func clipDragBegan() {
        dragStartFrame = cameraClipLayout.frame
        isDraggingClip = true
    }

    func clipDragChanged(translation: CGSize, canvasSize: CGSize) {
        let dx = translation.width / canvasSize.width
        let dy = translation.height / canvasSize.height
        var newFrame = dragStartFrame
        newFrame.origin.x = max(0, min(dragStartFrame.origin.x + dx, 1 - dragStartFrame.width))
        newFrame.origin.y = max(0, min(dragStartFrame.origin.y + dy, 1 - dragStartFrame.height))
        cameraClipLayout.frame = newFrame
    }

    func clipDragEnded() {
        isDraggingClip = false
    }

    // MARK: - Face Detection

    func detectFaceAndSetFocusPoint() {
        guard let cameraURL = session.cameraClipURL else { return }
        Task {
            let asset = AVURLAsset(url: cameraURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 640, height: 360)
            let time = CMTime(seconds: 0.5, preferredTimescale: 600)

            guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else { return }

            let request = VNDetectFaceRectanglesRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])

            guard let face = request.results?.first else { return }
            // Vision uses bottom-left origin — flip Y for SwiftUI
            let point = CGPoint(x: face.boundingBox.midX, y: 1 - face.boundingBox.midY)
            setFocusPoint(point)
        }
    }

    // MARK: - Export

    func exportVideo() {
        isExporting = true
        exportProgress = 0
        exportedURL = nil
        let layout = cameraClipLayout
        let session = self.session
        Task {
            do {
                let url = try await DefaultVideoExportService.shared.exportVideo(
                    session: session,
                    layout: layout
                ) { [weak self] progress in
                    Task { @MainActor [weak self] in
                        self?.exportProgress = progress
                    }
                }
                exportedURL = url
                isExporting = false
                showExportSuccess = true
            } catch {
                isExporting = false
                alertMessage = error.localizedDescription
                isOnAlert = true
            }
        }
    }

    // MARK: - Playback

    func playAll() {
        screenPlayer.seek(to: .zero)
        cameraPlayer.seek(to: .zero)
        screenPlayer.play()
        cameraPlayer.play()
        isPlaying = true
    }

    func pauseAll() {
        screenPlayer.pause()
        cameraPlayer.pause()
        isPlaying = false
    }
}
