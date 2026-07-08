//
//  DefaultVideoExportService.swift
//  SwiftCast
//

import AVFoundation
import CoreImage

// MARK: - Service

actor DefaultVideoExportService: VideoExportService {
    static let shared = DefaultVideoExportService()

    private let faceTrackingService: any FaceTrackingService

    init(faceTrackingService: any FaceTrackingService = DefaultFaceTrackingService.shared) {
        self.faceTrackingService = faceTrackingService
    }

    func exportVideo(
        session: RecordingSession,
        layout: CameraClipLayout,
        onProgress: @Sendable @escaping (Double) -> Void
    ) async throws -> URL {
        guard let screenURL = session.screenClipURL,
              let cameraURL = session.cameraClipURL else {
            throw ExportError.missingClips
        }

        // Reuse the same offline, zero-phase-smoothed face track as the editor preview,
        // instead of detecting faces independently on every exported frame (which had no
        // temporal continuity and was the actual source of jitter in the exported video).
        var faceTrack: [FaceTrackSample] = []
        if layout.isFaceTrackingEnabled {
            faceTrack = (try? await faceTrackingService.analyzeFaceTrack(url: cameraURL)) ?? []
        }

        let screenAsset = AVURLAsset(url: screenURL)
        let cameraAsset = AVURLAsset(url: cameraURL)

        let screenVideoTracks = try await screenAsset.loadTracks(withMediaType: .video)
        let cameraVideoTracks = try await cameraAsset.loadTracks(withMediaType: .video)
        let cameraAudioTracks = try await cameraAsset.loadTracks(withMediaType: .audio)

        guard let screenTrack = screenVideoTracks.first,
              let cameraTrack = cameraVideoTracks.first else {
            throw ExportError.noVideoTracks
        }

        let screenDuration = try await screenAsset.load(.duration)
        let cameraDuration = try await cameraAsset.load(.duration)
        let duration = CMTimeMinimum(screenDuration, cameraDuration)
        let timeRange = CMTimeRange(start: .zero, duration: duration)

        // Custom compositors receive source frames in natural (encoded) orientation; the
        // preferredTransform (e.g. the 180° rotation on recorded camera clips) is display
        // metadata the compositor must apply itself, or the export won't match the preview.
        let screenTransform = try await screenTrack.load(.preferredTransform)
        let cameraTransform = try await cameraTrack.load(.preferredTransform)
        let naturalSize = try await screenTrack.load(.naturalSize)
        let transformedSize = naturalSize.applying(screenTransform)
        let canvasSize = CGSize(width: abs(transformedSize.width), height: abs(transformedSize.height))

        let composition = AVMutableComposition()

        let compScreen = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
        try compScreen.insertTimeRange(timeRange, of: screenTrack, at: .zero)

        let compCamera = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
        try compCamera.insertTimeRange(timeRange, of: cameraTrack, at: .zero)

        if let audioTrack = cameraAudioTracks.first {
            let compAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
            try compAudio.insertTimeRange(timeRange, of: audioTrack, at: .zero)
        }

        let instruction = SwiftCastCompositionInstruction(
            timeRange: timeRange,
            screenTrackID: compScreen.trackID,
            cameraTrackID: compCamera.trackID,
            layout: layout,
            canvasSize: canvasSize,
            faceTrack: faceTrack,
            screenOrientation: screenTransform.videoOrientation,
            cameraOrientation: cameraTransform.videoOrientation
        )

        let videoComposition = AVMutableVideoComposition()
        videoComposition.customVideoCompositorClass = SwiftCastVideoCompositor.self
        videoComposition.instructions = [instruction]
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.renderSize = canvasSize

        let outputURL = session.folderURL.appendingPathComponent("exported.mp4")
        try? FileManager.default.removeItem(at: outputURL)

        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw ExportError.exportFailed
        }
        exporter.outputURL = outputURL
        exporter.outputFileType = .mp4
        exporter.videoComposition = videoComposition

        let progressTask = Task {
            while !Task.isCancelled {
                onProgress(Double(exporter.progress))
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }

        await exporter.export()
        progressTask.cancel()

        if exporter.status == .completed {
            onProgress(1.0)
            return outputURL
        }
        throw exporter.error ?? ExportError.exportFailed
    }
}

// MARK: - Composition Instruction

final class SwiftCastCompositionInstruction: NSObject, AVVideoCompositionInstructionProtocol {
    var timeRange: CMTimeRange
    var enablePostProcessing = false
    var containsTweening = false
    var requiredSourceTrackIDs: [NSValue]?
    var passthroughTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid

    let screenTrackID: CMPersistentTrackID
    let cameraTrackID: CMPersistentTrackID
    let layout: CameraClipLayout
    let canvasSize: CGSize
    /// Precomputed, zero-phase-smoothed face track (empty when face tracking is disabled
    /// or no face was ever detected). Looked up by composition time instead of re-running
    /// Vision on every exported frame.
    let faceTrack: [FaceTrackSample]
    /// Display orientations from each track's preferredTransform, applied to the raw
    /// source buffers so the composite matches what AVPlayer shows in the editor.
    let screenOrientation: CGImagePropertyOrientation
    let cameraOrientation: CGImagePropertyOrientation

    init(timeRange: CMTimeRange, screenTrackID: CMPersistentTrackID, cameraTrackID: CMPersistentTrackID, layout: CameraClipLayout, canvasSize: CGSize, faceTrack: [FaceTrackSample], screenOrientation: CGImagePropertyOrientation, cameraOrientation: CGImagePropertyOrientation) {
        self.timeRange = timeRange
        self.screenTrackID = screenTrackID
        self.cameraTrackID = cameraTrackID
        self.layout = layout
        self.canvasSize = canvasSize
        self.faceTrack = faceTrack
        self.screenOrientation = screenOrientation
        self.cameraOrientation = cameraOrientation
        self.requiredSourceTrackIDs = [
            NSNumber(value: screenTrackID),
            NSNumber(value: cameraTrackID)
        ]
    }
}

// MARK: - Custom Video Compositor

final class SwiftCastVideoCompositor: NSObject, AVVideoCompositing {
    var sourcePixelBufferAttributes: [String: Any]? = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
    ]
    var requiredPixelBufferAttributesForRenderContext: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
    ]

    private var renderContext: AVVideoCompositionRenderContext?
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    func renderContextChanged(_ newContext: AVVideoCompositionRenderContext) {
        renderContext = newContext
    }

    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        guard let instruction = request.videoCompositionInstruction as? SwiftCastCompositionInstruction,
              let screenBuffer = request.sourceFrame(byTrackID: instruction.screenTrackID),
              let cameraBuffer = request.sourceFrame(byTrackID: instruction.cameraTrackID),
              let outputBuffer = renderContext?.newPixelBuffer() else {
            request.finish(with: NSError(domain: "SwiftCast", code: -1))
            return
        }

        var layout = instruction.layout

        // Rotate raw buffers into display orientation up front so all downstream math
        // (face centering, aspect-fill, masking) runs in the same space as the preview.
        let screenImage = CIImage(cvPixelBuffer: screenBuffer).oriented(instruction.screenOrientation)
        let cameraImage = CIImage(cvPixelBuffer: cameraBuffer).oriented(instruction.cameraOrientation)

        if layout.isFaceTrackingEnabled,
           let rawFace = instruction.faceTrack.interpolatedPoint(at: request.compositionTime.seconds) {
            layout.focusPoint = centeringFocusPoint(for: rawFace, layout: layout, sourceSize: cameraImage.extent.size, canvasSize: instruction.canvasSize)
        }

        composite(screen: screenImage, camera: cameraImage, layout: layout, canvasSize: instruction.canvasSize, into: outputBuffer)
        request.finish(withComposedVideoFrame: outputBuffer)
    }

    /// Converts a raw face position (top-left origin, [0,1]) to the [0,1] pan factor
    /// that positions the face at the center of the clip frame in the composite output.
    private func centeringFocusPoint(for rawFace: CGPoint, layout: CameraClipLayout, sourceSize: CGSize, canvasSize: CGSize) -> CGPoint {
        let targetW = layout.frame.width * canvasSize.width
        let targetH = layout.frame.height * canvasSize.height
        let scale = max(targetW / sourceSize.width, targetH / sourceSize.height) * layout.zoom
        let scaledW = sourceSize.width * scale
        let scaledH = sourceSize.height * scale
        let overflowX = max(0, scaledW - targetW)
        let overflowY = max(0, scaledH - targetH)
        let px = overflowX > 0 ? max(0, min((rawFace.x * scaledW - targetW / 2) / overflowX, 1.0)) : 0.5
        let py = overflowY > 0 ? max(0, min((rawFace.y * scaledH - targetH / 2) / overflowY, 1.0)) : 0.5
        return CGPoint(x: px, y: py)
    }

    // MARK: - Compositing

    private func composite(screen screenImage: CIImage, camera: CIImage, layout: CameraClipLayout, canvasSize: CGSize, into output: CVPixelBuffer) {
        var cameraImage = camera

        // Convert layout.frame (SwiftUI top-left origin, normalized) to CIImage (bottom-left origin)
        let targetFrame = CGRect(
            x: layout.frame.origin.x * canvasSize.width,
            y: (1 - layout.frame.origin.y - layout.frame.height) * canvasSize.height,
            width: layout.frame.width * canvasSize.width,
            height: layout.frame.height * canvasSize.height
        )

        let sourceSize = cameraImage.extent.size
        let scaleToFill = max(targetFrame.width / sourceSize.width, targetFrame.height / sourceSize.height)
        let scale = scaleToFill * layout.zoom

        cameraImage = cameraImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let scaledW = sourceSize.width * scale
        let scaledH = sourceSize.height * scale

        // Compute offset so that the focusPoint area is centered in targetFrame.
        // focusPoint (0,0) = show top-left of camera (high Y in CIImage).
        let cropX = layout.focusPoint.x * max(0, scaledW - targetFrame.width)
        let cropY = layout.focusPoint.y * max(0, scaledH - targetFrame.height)
        let offsetX = targetFrame.origin.x - cropX
        let offsetY = targetFrame.origin.y - scaledH + cropY + targetFrame.height

        cameraImage = cameraImage.transformed(by: CGAffineTransform(translationX: offsetX, y: offsetY))

        let croppedCamera = cameraImage.cropped(to: targetFrame)

        // Skip masking entirely when no mask is selected — composites directly.
        let maskedCamera: CIImage
        if layout.maskMode == .none {
            maskedCamera = croppedCamera
        } else {
            let maskCI = buildMaskImage(for: layout.maskMode, in: targetFrame)
            let transparent = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0)).cropped(to: targetFrame)
            maskedCamera = croppedCamera.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputMaskImageKey: maskCI,
                kCIInputBackgroundImageKey: transparent
            ])
        }

        let result = maskedCamera.composited(over: screenImage)
        ciContext.render(result, to: output)
    }

    // MARK: - Mask Image Builder

    private func buildMaskImage(for mode: CameraClipMask, in rect: CGRect) -> CIImage {
        guard rect.width > 0, rect.height > 0 else { return CIImage.empty() }
        let w = Int(rect.width), h = Int(rect.height)
        let space = CGColorSpaceCreateDeviceGray()
        guard let ctx = CGContext(data: nil, width: w, height: h,
                                  bitsPerComponent: 8, bytesPerRow: w,
                                  space: space,
                                  bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return CIImage.empty() }

        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        let r = CGRect(origin: .zero, size: rect.size)
        let short = min(rect.width, rect.height)

        switch mode {
        case .none:
            ctx.fill(r)
        case .rectangle:
            ctx.fill(r)
        case .roundedRectangle:
            ctx.addPath(CGPath(roundedRect: r, cornerWidth: short * 0.18, cornerHeight: short * 0.18, transform: nil))
            ctx.fillPath()
        case .circle:
            ctx.fillEllipse(in: CGRect(x: (rect.width - short) / 2, y: (rect.height - short) / 2, width: short, height: short))
        case .ellipse:
            ctx.fillEllipse(in: r)
        case .capsule:
            let radius = short / 2
            ctx.addPath(CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil))
            ctx.fillPath()
        case .squircle:
            ctx.addPath(CGPath(roundedRect: r, cornerWidth: short * 0.38, cornerHeight: short * 0.38, transform: nil))
            ctx.fillPath()
        }

        guard let cgImage = ctx.makeImage() else { return CIImage.empty() }
        return CIImage(cgImage: cgImage)
            .transformed(by: CGAffineTransform(translationX: rect.origin.x, y: rect.origin.y))
    }
}

// MARK: - Errors

enum ExportError: LocalizedError {
    case missingClips
    case noVideoTracks
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .missingClips: return "Recording clips not found in this session."
        case .noVideoTracks: return "No video tracks found in the recording."
        case .exportFailed: return "Export failed. Please try again."
        }
    }
}
