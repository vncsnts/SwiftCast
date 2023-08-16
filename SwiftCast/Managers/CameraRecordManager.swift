//
//  CameraRecordManager.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 6/13/23.
//

import AVFoundation
import CoreImage

@MainActor
class CameraRecordManager: NSObject, ObservableObject {
    @Published var frame: CGImage?
    @Published var cameraOptions: [AVCaptureDevice] = []
    @Published var selectedCamera: SelectedDevice = SelectedDevice(localizedName: "", uniqueId: "") {
        didSet {
            setupCaptureSession()
        }
    }
    @Published var audioOptions: [AVCaptureDevice] = []
    @Published var selectedAudio: SelectedDevice = SelectedDevice(localizedName: "", uniqueId: "")  {
        didSet {
            setupCaptureSession()
        }
    }
    @Published var isRecording = false
    private var permissionGranted = false
    private let captureSession = AVCaptureSession()
    //    private var assetWriter = AVAssetWriter(contentType: .quickTimeMovie)
//    private var currentSessionTime: CMTime = .zero
    //    private var videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: nil)
    //    private var audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
    private var bitAssetWriter = AVAssetWriter(contentType: .quickTimeMovie)
    private var bitAssetCount = 0
    private var bitVideoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: nil)
    private var bitAudioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
    private let processQueue = DispatchQueue(label: "com.vncsnts.swiftCast.cameraBuffer")
    private let context = CIContext()
    private var currentStreamId = ""
    
    override init() {
        super.init()
        checkPermission()
        self.detectAvailableCaptureDevices()
    }
    
    func startCapture() {
        self.captureSession.startRunning()
    }
    
    func checkPermission() {
        let videoAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let audioAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        
        if videoAuthorizationStatus == .authorized && audioAuthorizationStatus == .authorized {
            // Both video and audio capture are authorized
            permissionGranted = true
        } else if videoAuthorizationStatus == .notDetermined || audioAuthorizationStatus == .notDetermined {
            // Video or audio capture authorization status not determined
            requestPermission()
        } else {
            // Video or audio capture authorization denied or restricted
            permissionGranted = false
        }
    }
    
    func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [unowned self] videoGranted in
            AVCaptureDevice.requestAccess(for: .audio) { audioGranted in
                self.permissionGranted = videoGranted && audioGranted
            }
        }
    }
    
    func setInitialDevices() {
        selectedCamera = SelectedDevice(localizedName: AVCaptureDevice.default(for: .video)?.localizedName ?? "", uniqueId: AVCaptureDevice.default(for: .video)?.uniqueID ?? "")
        selectedAudio = SelectedDevice(localizedName: AVCaptureDevice.default(for: .audio)?.localizedName ?? "", uniqueId: AVCaptureDevice.default(for: .audio)?.uniqueID ?? "")
    }
    
    func detectAvailableCaptureDevices() {
        findAvailableDevices()
        setInitialDevices()
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            DispatchQueue.main.async {
                self.findAvailableDevices()
            }
        }
    }
    
    func findAvailableDevices() {
        if !isRecording {
            let availableCameraDevices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .externalUnknown], mediaType: .video, position: .unspecified).devices
            cameraOptions = availableCameraDevices
            
            let availableAudioDevices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInMicrophone, .externalUnknown], mediaType: .audio, position: .unspecified).devices
            audioOptions = availableAudioDevices
        }
    }
    
    func setupCaptureSession() {
        //Inputs
        guard permissionGranted else { return }
        clearSessionDevices()
        
        //Camera
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
        
        //        videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        //        videoWriterInput.expectsMediaDataInRealTime = true
        bitVideoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        bitVideoWriterInput.expectsMediaDataInRealTime = true
        //        horizontallyFlipInput(videoWriterInput)
        horizontallyFlipInput(bitVideoWriterInput)
        //Audio
        guard let audioDevice = audioOptions.first(where: {$0.uniqueID == selectedAudio.uniqueId}) else { return }
        guard let audioDeviceInput = try? AVCaptureDeviceInput(device: audioDevice) else { return }
        guard captureSession.canAddInput(audioDeviceInput) else { return }
        captureSession.addInput(audioDeviceInput)
        
        //Outputs
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = false
        
        let audioOutput = AVCaptureAudioDataOutput()
        
        guard captureSession.canAddOutput(videoOutput), captureSession.canAddOutput(audioOutput) else { return }
        captureSession.addOutput(videoOutput)
        captureSession.addOutput(audioOutput)
        
        audioOutput.setSampleBufferDelegate(self, queue: processQueue)
        videoOutput.setSampleBufferDelegate(self, queue: processQueue)
        
        let audioSettings = audioOutput.recommendedAudioSettingsForAssetWriter(writingTo: .wav)
        
        bitAudioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        bitAudioWriterInput.expectsMediaDataInRealTime = true
    }
    
    func horizontallyFlipInput(_ assetInput: AVAssetWriterInput) {
        let horiztonalFlip = CGAffineTransform(scaleX: -1.0, y: 1.0)
        assetInput.transform = assetInput.transform.concatenating(horiztonalFlip)
    }
    
    func clearSessionDevices() {
        for videoInput in captureSession.inputs {
            captureSession.removeInput(videoInput)
        }
        for videoOutput in captureSession.outputs {
            captureSession.removeOutput(videoOutput)
        }
    }
    
    func selectCamera(device: AVCaptureDevice) {
        selectedCamera = SelectedDevice(localizedName: device.localizedName, uniqueId: device.uniqueID)
    }
    
    func selectAudio(device: AVCaptureDevice) {
        selectedAudio = SelectedDevice(localizedName: device.localizedName, uniqueId: device.uniqueID)
    }
    
    func setupWriter() async {
        Task {
            //            assetWriter = try AVAssetWriter(url: videoFileLocation(), fileType: .mp4)
            //            if assetWriter.canAdd(videoWriterInput) {
            //                assetWriter.add(videoWriterInput)
            //            }
            //            if assetWriter.canAdd(audioWriterInput) {
            //                assetWriter.add(audioWriterInput)
            //            }
            
            //            assetWriter.startWriting()
//            currentSessionTime = .zero
            bitAssetCount = 0
            repeat {
                bitAssetCount += 1
                bitAssetWriter = try AVAssetWriter(url: bitFileLocation(), fileType: .mp4)
                
                if bitAssetWriter.canAdd(bitVideoWriterInput) {
                    bitAssetWriter.add(bitVideoWriterInput)
                }
                if bitAssetWriter.canAdd(bitAudioWriterInput) {
                    bitAssetWriter.add(bitAudioWriterInput)
                }
                
                print("Camera Chunk - Start")
                try? await Task.sleep(nanoseconds: 1000000000)
                print("Camera Chunk - Will End")
                bitAudioWriterInput.markAsFinished()
                bitVideoWriterInput.markAsFinished()
                await bitAssetWriter.finishWriting()
            } while isRecording
        }
    }
    
    func startRecording(with streamId: String) async {
        currentStreamId = streamId
        await setupWriter()
        isRecording = true
    }
    
    func stopRecording() async {
        isRecording = false
        //        await assetWriter.finishWriting()
        currentStreamId = ""
    }
    
    func bitFileLocation() -> URL {
        let fileManager = FileManager.default
        let documentsPath = NSSearchPathForDirectoriesInDomains(.moviesDirectory, .userDomainMask, true)[0] as NSString
        let swiftCastFolderPath = (documentsPath.appendingPathComponent(SwiftCastFileManagerFolder.cameraQueue.rawValue) as NSString).expandingTildeInPath
        let videoOutputUrl = URL(fileURLWithPath: swiftCastFolderPath).appendingPathComponent("\(currentStreamId)-bit-\(bitAssetCount)").appendingPathExtension("mp4")
        
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
    
    //    func videoFileLocation() -> URL {
    //        let fileManager = FileManager.default
    //        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
    //        let swiftCastFolderPath = (documentsPath.appendingPathComponent("SwiftCast") as NSString).expandingTildeInPath
    //        let videoOutputUrl = URL(fileURLWithPath: swiftCastFolderPath).appendingPathComponent("\(currentStreamId)").appendingPathExtension("mp4")
    //
    //        do {
    //            if !fileManager.fileExists(atPath: swiftCastFolderPath) {
    //                try fileManager.createDirectory(atPath: swiftCastFolderPath, withIntermediateDirectories: true, attributes: nil)
    //                print("CameraRecordManager: Created 'SwiftCast' Folder.")
    //            }
    //
    //            if fileManager.fileExists(atPath: videoOutputUrl.path) {
    //                try fileManager.removeItem(at: videoOutputUrl)
    //                print("CameraRecordManager: Deleted existing file with the same path.")
    //            }
    //        } catch {
    //            print("CameraRecordManager: \(error.localizedDescription)")
    //        }
    //
    //        return videoOutputUrl
    //    }
}

extension CameraRecordManager: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        processQueue.async {
            if CMSampleBufferDataIsReady(sampleBuffer) {
                guard sampleBuffer.isValid else { return }
                let sourceTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
    //            self.currentSessionTime = sourceTime
                if output.isKind(of: AVCaptureVideoDataOutput.self) {
                    //                if self.videoWriterInput.isReadyForMoreMediaData && self.assetWriter.status == .writing && self.isRecording {
                    //                    self.assetWriter.startSession(atSourceTime: sourceTime)
                    //                    self.videoWriterInput.append(sampleBuffer)
                    //                }
                    
                    if self.bitVideoWriterInput.isReadyForMoreMediaData && self.isRecording {
                        self.bitAssetWriter.startWriting()
                        self.bitAssetWriter.startSession(atSourceTime: sourceTime)
                        self.bitVideoWriterInput.append(sampleBuffer)
                    }
                    
                    guard let cgImage = self.imageFromSampleBuffer(sampleBuffer: sampleBuffer) else { return }
                    DispatchQueue.main.async {
                        self.frame = cgImage
                    }
                } else if output.isKind(of: AVCaptureAudioDataOutput.self) {
                    //                if self.audioWriterInput.isReadyForMoreMediaData && self.assetWriter.status == .writing && self.isRecording {
                    //                    self.assetWriter.startSession(atSourceTime: sourceTime)
                    //                    self.audioWriterInput.append(sampleBuffer)
                    //                }
                    
                    if self.bitAudioWriterInput.isReadyForMoreMediaData && self.isRecording {
                        self.bitAssetWriter.startWriting()
                        self.bitAssetWriter.startSession(atSourceTime: sourceTime)
                        self.bitAudioWriterInput.append(sampleBuffer)
                    }
                }
            }
            
        }
    }
    
    
    private func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> CGImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        
        return cgImage
    }
}

struct SelectedDevice {
    var localizedName: String
    var uniqueId: String
}
