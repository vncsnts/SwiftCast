//
//  EditorViewModel.swift
//  SwiftCast
//

import AVFoundation
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
    /// True while the one-time offline face-track analysis of the camera clip is running.
    @Published var isFaceTrackAnalyzing = false
    /// Actual aspect ratio of the screen clip. Starts at 16:9 and updates once the asset loads.
    @Published var screenAspectRatio: CGFloat = 16.0 / 9.0
    /// Actual aspect ratio of the camera clip. Starts at 16:9 and updates once the asset loads.
    @Published var cameraAspectRatio: CGFloat = 16.0 / 9.0

    // Drag state for repositioning the camera clip
    @Published var isDraggingClip = false
    private var dragStartFrame: CGRect = .zero

    // Drag state for manual focus adjustment
    var isFocusDragging = false
    private var focusDragStart: CGPoint = CGPoint(x: 0.5, y: 0.5)

    let session: RecordingSession

    let screenPlayer: AVPlayer
    let cameraPlayer: AVPlayer

    private var playbackEndObservers: [NSObjectProtocol] = []

    // Face tracking: the camera clip is a finished file on disk, so the face track is
    // precomputed once offline (smoothed with a zero-phase filter) and playback just
    // interpolates the resulting lookup table — no ML inference while playing.
    private let faceTrackingService: any FaceTrackingService
    private var faceTrack: [FaceTrackSample] = []
    private var faceTrackingTask: Task<Void, Never>?
    /// Cadence of the playback focus updates — a binary search + lerp, so effectively free.
    private static let faceTrackRefreshNanoseconds: UInt64 = 33_000_000 // ~30 fps
    /// Panning can only center the face where the scaled camera overflows the clip box, and
    /// aspect-fill overflows at most one axis at 1× — so tracking needs zoom headroom to
    /// have any effect. Enforced as a floor when the feature is switched on.
    private static let faceTrackingMinimumZoom: CGFloat = 1.5

    init(
        session: RecordingSession,
        faceTrackingService: any FaceTrackingService = DefaultFaceTrackingService.shared
    ) {
        self.session = session
        self.faceTrackingService = faceTrackingService
        screenPlayer = AVPlayer(url: session.screenClipURL ?? URL(fileURLWithPath: ""))
        cameraPlayer = AVPlayer(url: session.cameraClipURL ?? URL(fileURLWithPath: ""))
        if session.exportedVideoURL != nil {
            exportedURL = session.exportedVideoURL
        }
        Task { await loadScreenAspectRatio(); await loadCameraAspectRatio() }
        observePlaybackEnd()
    }

    deinit {
        playbackEndObservers.forEach { NotificationCenter.default.removeObserver($0) }
        faceTrackingTask?.cancel()
    }

    private func observePlaybackEnd() {
        let stop: (Notification) -> Void = { [weak self] _ in
            Task { @MainActor [weak self] in self?.pauseAll() }
        }
        for item in [screenPlayer.currentItem, cameraPlayer.currentItem].compactMap({ $0 }) {
            playbackEndObservers.append(
                NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: item,
                    queue: .main,
                    using: stop
                )
            )
        }
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

    private func loadCameraAspectRatio() async {
        guard let url = session.cameraClipURL else { return }
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first else { return }
        guard let naturalSize = try? await track.load(.naturalSize),
              let transform = try? await track.load(.preferredTransform) else { return }
        let transformedSize = naturalSize.applying(transform)
        let w = abs(transformedSize.width)
        let h = abs(transformedSize.height)
        guard h > 0 else { return }
        cameraAspectRatio = w / h
        applyClipAspectRatio(cameraAspectRatio)
    }

    // Resizes the clip frame width to match targetClipAR while keeping height and center fixed.
    private func applyClipAspectRatio(_ targetClipAR: CGFloat) {
        // The normalized frame ratio needed: frame.width/frame.height = targetClipAR / screenAspectRatio
        let normalizedAR = targetClipAR / screenAspectRatio
        var frame = cameraClipLayout.frame
        let centerX = frame.midX
        frame.size.width = min(frame.size.height * normalizedAR, 1.0)
        frame.origin.x = max(0, min(centerX - frame.size.width / 2, 1 - frame.size.width))
        cameraClipLayout.frame = frame
    }

    // MARK: - Layout Mutations

    func setMaskMode(_ mode: CameraClipMask) {
        cameraClipLayout.maskMode = mode
        applyClipAspectRatio(mode.impliedAspectRatio ?? cameraAspectRatio)
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
            if cameraClipLayout.zoom < Self.faceTrackingMinimumZoom {
                setZoom(Self.faceTrackingMinimumZoom)
            }
            startFaceTracking()
        } else {
            stopFaceTracking()
        }
    }

    func enterManualFocusMode() {
        isInManualFocusMode = true
    }

    func exitManualFocusMode() {
        isInManualFocusMode = false
        isFocusDragging = false
    }

    // MARK: - Focus Drag

    func beginFocusDrag() {
        isFocusDragging = true
        focusDragStart = cameraClipLayout.focusPoint
    }

    func updateFocusDrag(translation: CGSize, clipSize: CGSize) {
        setFocusPoint(CGPoint(
            x: focusDragStart.x + translation.width / clipSize.width,
            y: focusDragStart.y + translation.height / clipSize.height
        ))
    }

    func endFocusDrag() {
        isFocusDragging = false
    }

    func resetLayout() {
        stopFaceTracking()
        cameraClipLayout = .default
        isInManualFocusMode = false
        applyClipAspectRatio(cameraAspectRatio)
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

    // MARK: - Face Tracking

    private func startFaceTracking() {
        faceTrackingTask?.cancel()
        faceTrackingTask = Task { [weak self] in
            guard await self?.prepareFaceTrackIfNeeded() == true else { return }
            // Playback loop: pure table lookup + lerp — no ML inference, so no jitter,
            // no decode races, and scrubbing/seeking resolves instantly even while paused.
            while !Task.isCancelled {
                guard let self, self.cameraClipLayout.isFaceTrackingEnabled else { break }
                self.applyFaceTrackFocus(at: self.cameraPlayer.currentTime().seconds)
                try? await Task.sleep(nanoseconds: Self.faceTrackRefreshNanoseconds)
            }
        }
    }

    private func stopFaceTracking() {
        faceTrackingTask?.cancel()
        faceTrackingTask = nil
        isFaceTrackAnalyzing = false
    }

    /// Runs the one-time offline analysis of the camera clip (cached across toggles).
    /// Returns true when a usable face track is available.
    private func prepareFaceTrackIfNeeded() async -> Bool {
        if faceTrack.isEmpty {
            guard let url = session.cameraClipURL else { return false }
            isFaceTrackAnalyzing = true
            defer { isFaceTrackAnalyzing = false }
            do {
                faceTrack = try await faceTrackingService.analyzeFaceTrack(url: url)
            } catch is CancellationError {
                return false
            } catch {
                cameraClipLayout.isFaceTrackingEnabled = false
                alertMessage = error.localizedDescription
                isOnAlert = true
                return false
            }
        }
        guard !faceTrack.isEmpty else {
            cameraClipLayout.isFaceTrackingEnabled = false
            alertMessage = Copy.faceTrackingNoFaceMessage
            isOnAlert = true
            return false
        }
        return true
    }

    /// Interpolates the precomputed track at `time` and applies the zoom-aware focus anchor.
    private func applyFaceTrackFocus(at time: TimeInterval) {
        guard time.isFinite, let facePoint = faceTrack.interpolatedPoint(at: time) else { return }
        // Pixel aspect ratio of the clip box itself (layout.frame is normalized to the canvas,
        // whose own aspect ratio is screenAspectRatio).
        let clipAR = (cameraClipLayout.frame.width / cameraClipLayout.frame.height) * screenAspectRatio
        let target = Self.focusPoint(
            forRawFace: facePoint,
            cameraAR: cameraAspectRatio,
            clipAR: clipAR,
            zoom: cameraClipLayout.zoom
        )
        // Publishing an unchanged layout still re-renders the whole editor; while the
        // dead-banded track holds still, don't touch it at all.
        let current = cameraClipLayout.focusPoint
        guard abs(target.x - current.x) > 0.0001 || abs(target.y - current.y) > 0.0001 else { return }
        setFocusPoint(target)
    }

    /// Converts a raw face position (normalized, top-left origin, in the *source camera image*)
    /// into the `focusPoint` pan value that centers the face in the rendered clip box.
    ///
    /// This mirrors EditorView's aspect-fill + zoom + pan math (and the export compositor's
    /// `centeringFocusPoint`) rather than a plain scaleEffect anchor: the camera is scaled to
    /// *fill* the clip box first (which alone already overflows one axis whenever the camera's
    /// aspect ratio doesn't exactly match the clip box's — true almost always, even at zoom 1),
    /// and only then does `zoom` add further overflow on both axes. Panning has to account for
    /// however much each axis actually overflows, not just the zoom factor.
    private static func focusPoint(forRawFace face: CGPoint, cameraAR: CGFloat, clipAR: CGFloat, zoom: CGFloat) -> CGPoint {
        let widthRatio: CGFloat   // scaled camera width / clip width
        let heightRatio: CGFloat  // scaled camera height / clip height
        if cameraAR > clipAR {
            // Camera is relatively wider than the clip box — height is the fill dimension.
            widthRatio = (cameraAR / clipAR) * zoom
            heightRatio = zoom
        } else {
            widthRatio = zoom
            heightRatio = (clipAR / cameraAR) * zoom
        }
        func pan(_ facePos: CGFloat, _ ratio: CGFloat) -> CGFloat {
            // ratio <= 1 means this axis has no overflow to pan across.
            guard ratio > 1.0001 else { return 0.5 }
            return max(0, min((facePos * ratio - 0.5) / (ratio - 1), 1))
        }
        return CGPoint(x: pan(face.x, widthRatio), y: pan(face.y, heightRatio))
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
