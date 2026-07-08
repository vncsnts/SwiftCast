//
//  DefaultFaceTrackingService.swift
//  SwiftCast
//

import AVFoundation
import CoreGraphics
import Vision

/// Precomputes a face track for a finished clip on disk. Unlike live per-frame
/// tracking during playback, the whole trajectory is known up front, so the
/// output can be smoothed with a zero-phase (forward + backward) filter —
/// genuinely smooth motion with no lag, jitter, or decode-timing races.
actor DefaultFaceTrackingService: FaceTrackingService {
    static let shared = DefaultFaceTrackingService()

    enum FaceTrackingError: LocalizedError {
        case noVideoTrack
        case readerFailed(Error?)

        var errorDescription: String? {
            switch self {
            case .noVideoTrack:
                return "The camera clip has no video track to analyze."
            case .readerFailed(let error):
                return error?.localizedDescription ?? "The camera clip could not be read for face analysis."
            }
        }
    }

    /// Clip-time spacing between analyzed frames (~6 samples/sec). Head motion in a
    /// recorded talking-head clip is slow; this is plenty once smoothed + interpolated.
    private let sampleInterval: TimeInterval = 1.0 / 6.0
    private let confidenceThreshold: VNConfidence = 0.5
    /// EMA factor per smoothing pass; applied forward then backward for zero phase lag.
    private let smoothingAlpha: CGFloat = 0.35

    private var cache: [URL: [FaceTrackSample]] = [:]

    func analyzeFaceTrack(url: URL) async throws -> [FaceTrackSample] {
        if let cached = cache[url] {
            return cached
        }
        let raw = try await collectRawSamples(url: url)
        let smoothed = Self.zeroPhaseSmoothed(raw, alpha: smoothingAlpha)
        cache[url] = smoothed
        return smoothed
    }

    // MARK: - Raw sampling

    /// Sequentially decodes the clip with AVAssetReader (far cheaper than repeated
    /// random-access AVAssetImageGenerator calls) and runs face detection every
    /// `sampleInterval` seconds of clip time.
    private func collectRawSamples(url: URL) async throws -> [FaceTrackSample] {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw FaceTrackingError.noVideoTrack
        }
        // Decoded buffers are in natural orientation; the preferredTransform (e.g. the 180°
        // rotation the camera recorder writes) is only applied at display time by AVPlayer.
        // Hand Vision the display orientation so face coordinates land in the same space
        // the editor preview and export compositor render in.
        let orientation = ((try? await track.load(.preferredTransform)) ?? .identity).videoOrientation

        let reader: AVAssetReader
        do {
            reader = try AVAssetReader(asset: asset)
        } catch {
            throw FaceTrackingError.readerFailed(error)
        }
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ])
        output.alwaysCopiesSampleData = false
        reader.add(output)
        guard reader.startReading() else {
            throw FaceTrackingError.readerFailed(reader.error)
        }
        defer { reader.cancelReading() }

        var samples: [FaceTrackSample] = []
        var nextSampleTime: TimeInterval = 0
        var lastPoint: CGPoint?

        while let buffer = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            let time = CMSampleBufferGetPresentationTimeStamp(buffer).seconds
            // Frames between sample points are decoded (sequential readers must) but
            // skipped for the expensive Vision work.
            guard time.isFinite, time >= nextSampleTime else { continue }
            nextSampleTime = time + sampleInterval
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) else { continue }

            if let face = detectFaceCenter(in: pixelBuffer, orientation: orientation, near: lastPoint) {
                lastPoint = face
                samples.append(FaceTrackSample(time: time, point: face))
            } else if let held = lastPoint {
                // Miss: hold the last known position so the track never snaps away.
                samples.append(FaceTrackSample(time: time, point: held))
            }
            // Leading misses (before the first-ever detection) emit no samples; the
            // playback lookup clamps to the first sample, so the clip's start holds
            // where the face first appeared instead of swooping in from center.
        }
        if reader.status == .failed {
            throw FaceTrackingError.readerFailed(reader.error)
        }
        return samples
    }

    /// Runs face detection on one frame and returns the chosen face center in
    /// normalized SwiftUI top-left coordinates.
    private func detectFaceCenter(in pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation, near previous: CGPoint?) -> CGPoint? {
        let request = VNDetectFaceRectanglesRequest()
        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:]).perform([request])
        let candidates = (request.results ?? []).filter { $0.confidence > confidenceThreshold }
        guard !candidates.isEmpty else { return nil }

        let chosen: VNFaceObservation
        if let previous {
            // Continuity across multiple faces: stick with the face nearest the last sample.
            chosen = candidates.min { candidate, other in
                Self.squaredDistance(Self.center(of: candidate), previous)
                    < Self.squaredDistance(Self.center(of: other), previous)
            }!
        } else {
            // First lock: prefer the most prominent (largest) face.
            chosen = candidates.max { candidate, other in
                candidate.boundingBox.width * candidate.boundingBox.height
                    < other.boundingBox.width * other.boundingBox.height
            }!
        }
        return Self.center(of: chosen)
    }

    private static func center(of face: VNFaceObservation) -> CGPoint {
        // Vision bounding boxes are bottom-left origin → flip y to SwiftUI top-left.
        CGPoint(x: face.boundingBox.midX, y: 1 - face.boundingBox.midY)
    }

    private static func squaredDistance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        (a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)
    }

    // MARK: - Offline smoothing

    /// Zero-phase smoothing: an exponential-moving-average pass forward, then the same
    /// pass backward over the result. The backward pass cancels the phase lag the
    /// forward pass introduces — only possible because the full track exists up front.
    private static func zeroPhaseSmoothed(_ samples: [FaceTrackSample], alpha: CGFloat) -> [FaceTrackSample] {
        guard samples.count > 2 else { return samples }
        var points = emaPass(samples.map(\.point), alpha: alpha)
        points = Array(emaPass(Array(points.reversed()), alpha: alpha).reversed())
        return zip(samples, points).map { FaceTrackSample(time: $0.time, point: $1) }
    }

    private static func emaPass(_ points: [CGPoint], alpha: CGFloat) -> [CGPoint] {
        guard var previous = points.first else { return points }
        return points.map { point in
            previous = CGPoint(
                x: previous.x + (point.x - previous.x) * alpha,
                y: previous.y + (point.y - previous.y) * alpha
            )
            return previous
        }
    }
}
