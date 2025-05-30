//
//  CameraRecordManager.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 6/13/23.
//

@preconcurrency import AVFoundation
import CoreImage
import Vision

/// Manages camera and audio capture, device selection, and recording for SwiftCast.
/// Handles AVFoundation session setup, permissions, and writing video/audio to disk.
/// - Author: Vince Carlo Santos
/// - Created: 6/13/23
@MainActor
class CameraRecordManager: NSObject, ObservableObject, @unchecked Sendable {
    // MARK: - Published Properties
    /// The current video frame as a CGImage.
    @Published var frame: CGImage?
    /// List of available camera devices.
    @Published var cameraOptions: [AVCaptureDevice] = []
    /// The currently selected camera device.
    @Published var selectedCamera: SelectedDevice = SelectedDevice(localizedName: "", uniqueId: "") {
        didSet { setupCaptureSession() }
    }
    /// List of available audio devices.
    @Published var audioOptions: [AVCaptureDevice] = []
    /// The currently selected audio device.
    @Published var selectedAudio: SelectedDevice = SelectedDevice(localizedName: "", uniqueId: "")  {
        didSet { setupCaptureSession() }
    }
    /// Indicates if recording is in progress.
    @Published var isRecording = false
    /// Indicates if chunked recording is enabled.
    @Published var isChunked = false
    /// The detected hand position.
    @Published var handPosition: CGPoint? = nil
    /// The detected hand points for collision detection
    @Published var handPoints: [VNHumanHandPoseObservation.JointName: VNRecognizedPoint]? = nil

    // MARK: - Private Properties
    private var permissionGranted = false
    private let captureSession = AVCaptureSession()
    private var assetWriter = AVAssetWriter(contentType: .quickTimeMovie)
    private var currentSessionTime: CMTime = .zero
    private var videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: nil)
    private var audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
    private var bitAssetWriter = AVAssetWriter(contentType: .quickTimeMovie)
    private var bitAssetCount = 0
    private var bitVideoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: nil)
    private var bitAudioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
    private let audioQueue = DispatchQueue(label: "com.vncsnts.swiftCast.audioQueue")
    private let videoQueue = DispatchQueue(label: "com.vncsnts.swiftCast.videoQueue")
    private let context = CIContext()
    private var currentStreamId = ""
    private var handPoseRequest = VNDetectHumanHandPoseRequest()
    private var frameCount = 0
    private let visionFrameInterval = 2 // Process every 2nd frame for better performance
    private let minConfidence: Float = 0.5 // Increased confidence threshold for more accurate detection

    // MARK: - Lifecycle
    override init() {
        super.init()
        // Configure hand pose request for better accuracy
        handPoseRequest.maximumHandCount = 1 // Only detect one hand for better performance
        handPoseRequest.revision = VNDetectHumanHandPoseRequestRevision1 // Use latest revision
        checkPermission()
        self.detectAvailableCaptureDevices()
    }

    // MARK: - Public Methods
    /// Starts the camera capture session.
    func startCapture() {
        self.captureSession.startRunning()
    }

    /// Checks and requests camera and audio permissions.
    func checkPermission() {
        let videoAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let audioAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if videoAuthorizationStatus == .authorized && audioAuthorizationStatus == .authorized {
            permissionGranted = true
        } else if videoAuthorizationStatus == .notDetermined || audioAuthorizationStatus == .notDetermined {
            requestPermission()
        } else {
            permissionGranted = false
        }
    }

    /// Requests camera and audio permissions from the user.
    func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [unowned self] videoGranted in
            AVCaptureDevice.requestAccess(for: .audio) { audioGranted in
                self.permissionGranted = videoGranted && audioGranted
            }
        }
    }

    /// Sets the initial camera and audio devices.
    func setInitialDevices() {
        selectedCamera = SelectedDevice(localizedName: AVCaptureDevice.default(for: .video)?.localizedName ?? "", uniqueId: AVCaptureDevice.default(for: .video)?.uniqueID ?? "")
        selectedAudio = SelectedDevice(localizedName: AVCaptureDevice.default(for: .audio)?.localizedName ?? "", uniqueId: AVCaptureDevice.default(for: .audio)?.uniqueID ?? "")
    }

    /// Detects and updates the list of available capture devices.
    func detectAvailableCaptureDevices() {
        findAvailableDevices()
        setInitialDevices()
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            DispatchQueue.main.async {
                self.findAvailableDevices()
            }
        }
    }

    /// Finds available camera and audio devices.
    func findAvailableDevices() {
        if !isRecording {
            let availableCameraDevices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .externalUnknown], mediaType: .video, position: .unspecified).devices
            cameraOptions = availableCameraDevices
            let availableAudioDevices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInMicrophone, .externalUnknown], mediaType: .audio, position: .unspecified).devices
            audioOptions = availableAudioDevices
        }
    }

    /// Sets up the capture session with the selected devices.
    func setupCaptureSession() {
        guard permissionGranted else { return }
        clearSessionDevices()
        guard let videoDevice = cameraOptions.first(where: {$0.uniqueID == selectedCamera.uniqueId}) else { return }
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else { return }
        guard captureSession.canAddInput(videoDeviceInput) else { return }
        captureSession.addInput(videoDeviceInput)
        var formatDescription: CMFormatDescription?
        if let has1920 = videoDevice.formats.first(where: {$0.formatDescription.dimensions.width == 1920}) {
            formatDescription = has1920.formatDescription
        } else {
            formatDescription = videoDevice.activeFormat.formatDescription
        }
        guard let validFormat = formatDescription else { return }
        let dimensions = CMVideoFormatDescriptionGetDimensions(validFormat)
        let resolution = CGSize(width: CGFloat(dimensions.width), height: CGFloat(dimensions.height))
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: resolution.width,
            AVVideoHeightKey: resolution.height
        ]
        videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoWriterInput.expectsMediaDataInRealTime = true
        horizontallyFlipInput(videoWriterInput)
        if isChunked {
            bitVideoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            bitVideoWriterInput.expectsMediaDataInRealTime = true
            horizontallyFlipInput(bitVideoWriterInput)
        }
        guard let audioDevice = audioOptions.first(where: {$0.uniqueID == selectedAudio.uniqueId}) else { return }
        guard let audioDeviceInput = try? AVCaptureDeviceInput(device: audioDevice) else { return }
        guard captureSession.canAddInput(audioDeviceInput) else { return }
        captureSession.addInput(audioDeviceInput)
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = false
        let audioOutput = AVCaptureAudioDataOutput()
        guard captureSession.canAddOutput(videoOutput), captureSession.canAddOutput(audioOutput) else { return }
        captureSession.addOutput(videoOutput)
        captureSession.addOutput(audioOutput)
        audioOutput.setSampleBufferDelegate(self, queue: audioQueue)
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        let audioSettings = audioOutput.recommendedAudioSettingsForAssetWriter(writingTo: .wav)
        audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioWriterInput.expectsMediaDataInRealTime = true
        if isChunked {
            bitAudioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            bitAudioWriterInput.expectsMediaDataInRealTime = true
        }
    }

    /// Flips the video input horizontally.
    /// - Parameter assetInput: The video writer input to flip.
    func horizontallyFlipInput(_ assetInput: AVAssetWriterInput) {
        let horiztonalFlip = CGAffineTransform(scaleX: -1.0, y: 1.0)
        assetInput.transform = assetInput.transform.concatenating(horiztonalFlip)
    }

    /// Removes all inputs and outputs from the capture session.
    func clearSessionDevices() {
        for videoInput in captureSession.inputs {
            captureSession.removeInput(videoInput)
        }
        for videoOutput in captureSession.outputs {
            captureSession.removeOutput(videoOutput)
        }
    }

    /// Selects a camera device.
    /// - Parameter device: The camera device to select.
    func selectCamera(device: AVCaptureDevice) {
        selectedCamera = SelectedDevice(localizedName: device.localizedName, uniqueId: device.uniqueID)
    }

    /// Selects an audio device.
    /// - Parameter device: The audio device to select.
    func selectAudio(device: AVCaptureDevice) {
        selectedAudio = SelectedDevice(localizedName: device.localizedName, uniqueId: device.uniqueID)
    }

    /// Starts recording with the given stream ID.
    /// - Parameter streamId: The stream identifier.
    func startRecording(with streamId: String) async {
        currentStreamId = streamId
        isRecording = true
        let videoOutputUrl = videoFileLocation()
        do {
            assetWriter = try AVAssetWriter(url: videoOutputUrl, fileType: .mp4)
            if isChunked {
                let bitVideoOutputUrl = videoFileLocation().appendingPathComponent("bit_\(bitAssetCount)")
                bitAssetWriter = try AVAssetWriter(url: bitVideoOutputUrl, fileType: .mp4)
                bitAssetCount += 1
            }
            assetWriter.add(videoWriterInput)
            assetWriter.add(audioWriterInput)
            if isChunked {
                bitAssetWriter.add(bitVideoWriterInput)
                bitAssetWriter.add(bitAudioWriterInput)
            }
        } catch {
            print("CameraRecordManager: Failed to create asset writer - \(error.localizedDescription)")
        }
    }

    /// Stops the current recording session.
    func stopRecording() async {
        isRecording = false
        await assetWriter.finishWriting()
        if isChunked {
            await bitAssetWriter.finishWriting()
        }
        currentStreamId = ""
    }

    /// Returns the file URL for the current video recording.
    /// - Returns: The URL for the video file.
    func videoFileLocation() -> URL {
        let fileManager = FileManager.default
        let documentsPath = NSSearchPathForDirectoriesInDomains(.moviesDirectory, .userDomainMask, true)[0] as NSString
        let swiftCastFolderPath = (documentsPath.appendingPathComponent("SwiftCast") as NSString).expandingTildeInPath
        let videoOutputUrl = URL(fileURLWithPath: swiftCastFolderPath).appendingPathComponent("\(currentStreamId)").appendingPathExtension("mp4")
        do {
            if !fileManager.fileExists(atPath: swiftCastFolderPath) {
                try fileManager.createDirectory(atPath: swiftCastFolderPath, withIntermediateDirectories: true, attributes: nil)
                print("CameraRecordManager: Created 'SwiftCast' Folder.")
            }
            if fileManager.fileExists(atPath: videoOutputUrl.path) {
                try fileManager.removeItem(at: videoOutputUrl)
                print("CameraRecordManager: Deleted existing file with the same path.")
            }
        } catch {
            print("CameraRecordManager: \(error.localizedDescription)")
        }
        return videoOutputUrl
    }

    // MARK: - Private Helpers
    /// Returns whether audio should be processed.
    @MainActor
    private func shouldProcessAudio() -> Bool {
        return isRecording
    }
    /// Returns whether chunked audio should be processed.
    @MainActor
    private func shouldProcessChunkedAudio() -> Bool {
        return isRecording && isChunked
    }
    /// Handles appending audio sample buffers to the asset writers.
    /// - Parameters:
    ///   - sampleBuffer: The audio sample buffer.
    ///   - time: The presentation time.
    nonisolated private func handleAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer, at time: CMTime) {
        Task { @MainActor in
            if self.audioWriterInput.isReadyForMoreMediaData && self.isRecording {
                self.assetWriter.startSession(atSourceTime: time)
                self.audioWriterInput.append(sampleBuffer)
            }
            if self.bitAudioWriterInput.isReadyForMoreMediaData && self.isRecording && self.isChunked {
                self.bitAssetWriter.startSession(atSourceTime: time)
                self.bitAudioWriterInput.append(sampleBuffer)
            }
        }
    }
    /// Processes a video frame for hand pose and updates handPosition.
    private func processFrameForHandPose(_ sampleBuffer: CMSampleBuffer) {
        frameCount += 1
        if frameCount % visionFrameInterval != 0 { return }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Create image request handler with correct orientation
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, 
                                          orientation: .up, // Use .up for correct orientation
                                          options: [:])
        do {
            try handler.perform([handPoseRequest])
            if let observation = handPoseRequest.results?.first {
                let points = try observation.recognizedPoints(.all)
                
                // Get key points with high confidence
                let wrist = points[.wrist]
                let indexFingerMCP = points[.indexMCP] // Index finger knuckle
                let middleFingerMCP = points[.middleMCP] // Middle finger knuckle
                
                // Only update if we have good confidence in key points
                if let wrist = wrist, wrist.confidence > minConfidence,
                   let indexMCP = indexFingerMCP, indexMCP.confidence > minConfidence,
                   let middleMCP = middleFingerMCP, middleMCP.confidence > minConfidence {
                    
                    // Calculate hand position as average of key points for better stability
                    let avgX = (wrist.location.x + indexMCP.location.x + middleMCP.location.x) / 3
                    let avgY = (wrist.location.y + indexMCP.location.y + middleMCP.location.y) / 3
                    
                    Task { @MainActor in
                        // Flip both x and y coordinates to match the camera preview
                        self.handPosition = CGPoint(x: 1.0 - avgX, y: 1.0 - avgY)
                        self.handPoints = points
                    }
                } else {
                    Task { @MainActor in
                        self.handPosition = nil
                        self.handPoints = nil
                    }
                }
            } else {
                Task { @MainActor in
                    self.handPosition = nil
                    self.handPoints = nil
                }
            }
        } catch {
            print("Vision error during perform: \(error)")
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate & AVCaptureAudioDataOutputSampleBufferDelegate
extension CameraRecordManager: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    /// Handles output of video and audio sample buffers from the capture session.
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        print("captureOutput called.")
        guard sampleBuffer.isValid else { 
            print("captureOutput: sampleBuffer is invalid.")
            return 
        }
        let sourceTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let isVideoOutput = output.isKind(of: AVCaptureVideoDataOutput.self)
        let isAudioOutput = output.isKind(of: AVCaptureAudioDataOutput.self)
        
        print("captureOutput: isVideoOutput=\(isVideoOutput), isAudioOutput=\(isAudioOutput)")

        Task { @MainActor in
            self.currentSessionTime = sourceTime
            if isVideoOutput {
                 print("captureOutput: Processing video output.")
                if self.videoWriterInput.isReadyForMoreMediaData && self.isRecording {
                    self.assetWriter.startSession(atSourceTime: sourceTime)
                    self.videoWriterInput.append(sampleBuffer)
                }
                if self.bitVideoWriterInput.isReadyForMoreMediaData && self.isRecording && self.isChunked {
                    self.bitAssetWriter.startSession(atSourceTime: sourceTime)
                    self.bitVideoWriterInput.append(sampleBuffer)
                }
                if let cgImage = self.imageFromSampleBuffer(sampleBuffer: sampleBuffer) {
                    self.frame = cgImage
                     print("captureOutput: Called processFrameForHandPose for video.")
                    self.processFrameForHandPose(sampleBuffer)
                }
            } else if isAudioOutput {
                 print("captureOutput: Processing audio output.")
                self.handleAudioSampleBuffer(sampleBuffer, at: sourceTime)
            }
        }
    }
    /// Converts a video sample buffer to a CGImage and applies a horizontal flip for preview.
    /// - Parameter sampleBuffer: The video sample buffer.
    /// - Returns: The resulting flipped CGImage, or nil if conversion fails.
    @MainActor
    private func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> CGImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        
        // Apply horizontal flip for preview
        let flippedCiImage = ciImage.transformed(by: CGAffineTransform(scaleX: -1, y: 1))
        
        guard let flippedCgImage = context.createCGImage(flippedCiImage, from: flippedCiImage.extent) else { return nil }
        
        return flippedCgImage
    }
}

/// Represents a selected device (camera or audio).
struct SelectedDevice: Sendable {
    var localizedName: String
    var uniqueId: String
}
