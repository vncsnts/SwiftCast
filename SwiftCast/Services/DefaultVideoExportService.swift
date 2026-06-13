//
//  DefaultVideoExportService.swift
//  SwiftCast
//

import AVFoundation
import CoreImage
import Vision

// MARK: - Service

actor DefaultVideoExportService: VideoExportService {
    static let shared = DefaultVideoExportService()

    func exportVideo(
        session: RecordingSession,
        layout: CameraClipLayout,
        onProgress: @Sendable @escaping (Double) -> Void
    ) async throws -> URL {
        guard let screenURL = session.screenClipURL,
              let cameraURL = session.cameraClipURL else {
            throw ExportError.missingClips
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
        let canvasSize = try await screenTrack.load(.naturalSize)

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
            canvasSize: canvasSize
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

    init(timeRange: CMTimeRange, screenTrackID: CMPersistentTrackID, cameraTrackID: CMPersistentTrackID, layout: CameraClipLayout, canvasSize: CGSize) {
        self.timeRange = timeRange
        self.screenTrackID = screenTrackID
        self.cameraTrackID = cameraTrackID
        self.layout = layout
        self.canvasSize = canvasSize
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

        if layout.isFaceTrackingEnabled, let focusPoint = detectFace(in: cameraBuffer) {
            layout.focusPoint = focusPoint
        }

        composite(screen: screenBuffer, camera: cameraBuffer, layout: layout, canvasSize: instruction.canvasSize, into: outputBuffer)
        request.finish(withComposedVideoFrame: outputBuffer)
    }

    // MARK: - Face Detection

    private func detectFace(in buffer: CVPixelBuffer) -> CGPoint? {
        let ciImage = CIImage(cvPixelBuffer: buffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
        guard let face = request.results?.first else { return nil }
        // Vision: bottom-left origin → SwiftUI: top-left origin (flip Y)
        return CGPoint(x: face.boundingBox.midX, y: 1 - face.boundingBox.midY)
    }

    // MARK: - Compositing

    private func composite(screen: CVPixelBuffer, camera: CVPixelBuffer, layout: CameraClipLayout, canvasSize: CGSize, into output: CVPixelBuffer) {
        let screenImage = CIImage(cvPixelBuffer: screen)
        var cameraImage = CIImage(cvPixelBuffer: camera)

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
