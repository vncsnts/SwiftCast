//
//  ScreenRecordManager.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 6/10/23.
//

import ScreenCaptureKit
import CoreGraphics
import AVFoundation

@MainActor
class ScreenRecordManager: NSObject, ObservableObject {
    /// The supported capture types.
    enum CaptureType {
        case display
        case window
    }
    
    @Published var isRecording = false
    
    // MARK: - Video Properties
    private(set) var availableDisplays = [SCDisplay]()
    private(set) var availableWindows = [SCWindow]()
    
    @Published var captureType: CaptureType = .display {
        didSet { updateEngine() }
    }
    
    @Published var selectedDisplay: SCDisplay? {
        didSet { updateEngine() }
    }
    
    @Published var selectedWindow: SCWindow? {
        didSet { updateEngine() }
    }
    
    @Published var isAppExcluded = true {
        didSet { updateEngine() }
    }
    
    @Published var isChunked = false
    
    private var stream: SCStream?
    private let screenQueue = DispatchQueue(label: "com.vncsnts.swiftCast.screenBuffer")
    private var scaleFactor: Int { Int(NSScreen.main?.backingScaleFactor ?? 2) }
    private var availableApps = [SCRunningApplication]()
    private var assetWriter = AVAssetWriter(contentType: .quickTimeMovie)
    private var videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: nil)
    private var bitAssetWriter = AVAssetWriter(contentType: .quickTimeMovie)
    private var bitVideoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: nil)
    private var bitVideoCount = 0
    private var averageBitrate = 130000000
    private var currentSampleTime: CMTime = .zero
    private var currentStreamId = ""

    public var canRecord: Bool {
        get async {
            do {
                // If the app doesn't have Screen Recording permission, this call generates an exception.
                try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                return true
            } catch {
                return false
            }
        }
    }
    
    /// - Tag: UpdateFilter
    private var contentFilter: SCContentFilter {
        let filter: SCContentFilter
        switch captureType {
        case .display:
            guard let display = selectedDisplay else { fatalError("No display selected.") }
            var excludedApps = [SCRunningApplication]()
            // If a user chooses to exclude the app from the stream,
            // exclude it by matching its bundle identifier.
            if isAppExcluded {
                excludedApps = availableApps.filter { app in
                    Bundle.main.bundleIdentifier == app.bundleIdentifier
                }
            }
            // Create a content filter with excluded apps.
            filter = SCContentFilter(display: display,
                                     excludingApplications: excludedApps,
                                     exceptingWindows: [])
        case .window:
            guard let window = selectedWindow else { fatalError("No window selected.") }
            
            // Create a content filter that includes a single window.
            filter = SCContentFilter(desktopIndependentWindow: window)
        }
        return filter
    }
    
    private var streamConfiguration: SCStreamConfiguration {
        
        let streamConfig = SCStreamConfiguration()
        
        // Configure the display content width and height.
        if captureType == .display, let display = selectedDisplay {
            streamConfig.width = display.width * scaleFactor
            streamConfig.height = display.height * scaleFactor
        }
        
        
        // Configure the window content width and height.
        if captureType == .window, let window = selectedWindow {
            streamConfig.width = Int(window.frame.width) * 2
            streamConfig.height = Int(window.frame.height) * 2
        }
        
        // Set the capture interval at 60 fps.
        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        
        // Increase the depth of the frame queue to ensure high fps at the expense of increasing
        // the memory footprint of WindowServer.
        streamConfig.queueDepth = 5
        streamConfig.pixelFormat = kCVPixelFormatType_32BGRA
        streamConfig.colorSpaceName = CGColorSpace.sRGB
        return streamConfig
    }
    
    func monitorAvailableContent() async {
        await refreshAvailableContent()
    }
    
    func videoFileLocation() -> URL {
        let fileManager = FileManager.default
        let documentsPath = NSSearchPathForDirectoriesInDomains(.moviesDirectory, .userDomainMask, true)[0] as NSString
        let swiftCastFolderPath = (documentsPath.appendingPathComponent("SwiftCast") as NSString).expandingTildeInPath
        let videoOutputUrl = URL(fileURLWithPath: swiftCastFolderPath).appendingPathComponent("\(currentStreamId)").appendingPathExtension("mp4")

        do {
            if !fileManager.fileExists(atPath: swiftCastFolderPath) {
                try fileManager.createDirectory(atPath: swiftCastFolderPath, withIntermediateDirectories: true, attributes: nil)
                print("ScreenRecordManager: Created 'SwiftCast' Folder.")
            }

            if fileManager.fileExists(atPath: videoOutputUrl.path) {
                try fileManager.removeItem(at: videoOutputUrl)
                print("ScreenRecordManager: Deleted existing file with the same path.")
            }
        } catch {
            print("ScreenRecordManager: \(error.localizedDescription)")
        }

        return videoOutputUrl
    }
    
    func bitVideoFileLocation() -> URL {
        let fileManager = FileManager.default
        let documentsPath = NSSearchPathForDirectoriesInDomains(.moviesDirectory, .userDomainMask, true)[0] as NSString
        let swiftCastFolderPath = (documentsPath.appendingPathComponent(SwiftCastFileManagerFolder.screenQueue.rawValue) as NSString).expandingTildeInPath
        let videoOutputUrl = URL(fileURLWithPath: swiftCastFolderPath).appendingPathComponent("\(currentStreamId)-bit-\(bitVideoCount)").appendingPathExtension("mp4")
        
        do {
            if !fileManager.fileExists(atPath: swiftCastFolderPath) {
                try fileManager.createDirectory(atPath: swiftCastFolderPath, withIntermediateDirectories: true, attributes: nil)
                print("ScreenRecordManager: Created 'SwiftCast' Folder.")
            }
            
            if fileManager.fileExists(atPath: videoOutputUrl.path) {
                try fileManager.removeItem(at: videoOutputUrl)
                print("ScreenRecordManager: Deleted existing file with the same path.")
            }
        } catch {
            print("ScreenRecordManager: \(error.localizedDescription)")
        }
        
        return videoOutputUrl
    }
    
    // AVAssetWriterInput supports maximum resolution of 4096x2304 for H.264
    private func downsizedVideoSize(source: CGSize, scaleFactor: Int) -> (width: Int, height: Int) {
        let maxSize = CGSize(width: 4096, height: 2304)
        
        let w = source.width * Double(scaleFactor)
        let h = source.height * Double(scaleFactor)
        let r = max(w / maxSize.width, h / maxSize.height)
        
        return r > 1
        ? (width: Int(w / r), height: Int(h / r))
        : (width: Int(w), height: Int(h))
    }
    
    private func setup() async {
        Task {
            // MARK: AVAssetWriter setup
            guard let displayID = selectedDisplay?.displayID else { return }
            
            let displaySize = CGDisplayBounds(displayID).size
            
            // The number of physical pixels that represent a logic point on screen, currently 2 for MacBook Pro retina displays
            let displayScaleFactor: Int
            if let mode = CGDisplayCopyDisplayMode(displayID) {
                displayScaleFactor = mode.pixelWidth / mode.width
            } else {
                displayScaleFactor = 1
            }
            
            // AVAssetWriterInput supports maximum resolution of 4096x2304 for H.264
            // Downsize to fit a larger display back into in 4K
            let videoSize = downsizedVideoSize(source: displaySize, scaleFactor: displayScaleFactor)
            
            // This preset is the maximum H.264 preset, at the time of writing this code
            // Make this as large as possible, size will be reduced to screen size by computed videoSize
            guard let assistant = AVOutputSettingsAssistant(preset: .preset3840x2160) else {
                return
            }
            do {
                assistant.sourceVideoFormat = try CMVideoFormatDescription(videoCodecType: .h264, width: videoSize.width, height: videoSize.height)
            } catch {
                print("\(error.localizedDescription)")
            }
            
    //            let compressionProperties = [
    //                AVVideoAverageBitRateKey : averageBitrate
    //            ]
            
            guard var outputSettings = assistant.videoSettings else {
                return
            }
            
            outputSettings[AVVideoWidthKey] = videoSize.width
            outputSettings[AVVideoHeightKey] = videoSize.height
    //            outputSettings[AVVideoCompressionPropertiesKey] = compressionProperties
            
            // Start the stream and await new video frames.
            stream = SCStream(filter: contentFilter, configuration: streamConfiguration, delegate: self)
            try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: screenQueue)
            try await stream?.startCapture()
            
            videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
            videoWriterInput.expectsMediaDataInRealTime = true
            
            if isChunked {
                bitVideoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
                bitVideoWriterInput.expectsMediaDataInRealTime = true
            }
            
            // Create AVAssetWriter for a QuickTime movie file
            assetWriter = try AVAssetWriter(url: videoFileLocation(), fileType: .mp4)
            
            if assetWriter.canAdd(videoWriterInput) {
                assetWriter.add(videoWriterInput)
            }

            assetWriter.startWriting()
            currentSampleTime = .zero
            bitVideoCount = 0
            
            if isChunked {
                repeat {
                    bitVideoCount += 1
                    bitAssetWriter = try AVAssetWriter(url: bitVideoFileLocation(), fileType: .mp4)
                    if bitAssetWriter.canAdd(bitVideoWriterInput) {
                        bitAssetWriter.add(bitVideoWriterInput)
                    }
                    bitAssetWriter.startWriting()
                    print("Screen Chunk - Start")
                    try? await Task.sleep(nanoseconds: 1000000000)
                    // Finish writing
                    print("Screen Chunk - Will End")
                    bitVideoWriterInput.markAsFinished()
                    await bitAssetWriter.finishWriting()
                    print("Screen Chunk - Did End")
                } while isRecording
            }
        }
    }
    
    /// Starts capturing screen content.
    public func startRecording(with streamId: String) async {
        guard !isRecording else { return }
        currentStreamId = streamId
        await setup()
        isRecording = true
    }
    
    /// Stops capturing screen content.
    public func stopRecording() async {
        do {
            guard isRecording else { return }
            try await stream?.stopCapture()
            await assetWriter.finishWriting()
            currentStreamId = ""
            isRecording = false
        } catch {
            print(error.localizedDescription)
        }
    }
    
    public func selectDisplay(display: SCDisplay) {
        selectedDisplay = display
    }
    
    /// - Tag: UpdateCaptureConfig
    private func updateEngine() {
        guard isRecording else { return }
        stream?.updateConfiguration(streamConfiguration)
        stream?.updateContentFilter(contentFilter)
    }
    
    /// - Tag: GetAvailableContent
    private func refreshAvailableContent() async {
        do {
            // Retrieve the available screen content to capture.
            let availableContent = try await SCShareableContent.excludingDesktopWindows(false,
                                                                                        onScreenWindowsOnly: true)
            availableDisplays = availableContent.displays
            
////            let windows = filterWindows(availableContent.windows)
//            if windows != availableWindows {
//                availableWindows = windows
//            }
            availableApps = availableContent.applications
            
            if selectedDisplay == nil {
                selectedDisplay = availableDisplays.first
            }
//            if selectedWindow == nil {
//                selectedWindow = availableWindows.first
//            }
        } catch {
            print("ScreenRecordManager: \(error.localizedDescription)")
        }
    }
    
    private func filterWindows(_ windows: [SCWindow]) -> [SCWindow] {
        windows
        // Sort the windows by app name.
            .sorted { $0.owningApplication?.applicationName ?? "" < $1.owningApplication?.applicationName ?? "" }
        // Remove windows that don't have an associated .app bundle.
            .filter { $0.owningApplication != nil && $0.owningApplication?.applicationName != "" }
        // Remove this app's window from the list.
            .filter { $0.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier }
    }
}

extension ScreenRecordManager: SCStreamOutput, SCStreamDelegate {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sampleBuffer.isValid else { return }
        
        // Return early if the sample buffer is invalid
        guard sampleBuffer.isValid else { return }
        
        // Retrieve the array of metadata attachments from the sample buffer
        guard let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let attachments = attachmentsArray.first
        else { return }
        
        // Validate the status of the frame. If it isn't `.complete`, return
        guard let statusRawValue = attachments[SCStreamFrameInfo.status] as? Int,
              let status = SCFrameStatus(rawValue: statusRawValue),
              status == .complete
        else { return }
        
        let sourceTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        currentSampleTime = sourceTime
        
        switch type {
        case .screen:
            screenQueue.async { [self] in
                if videoWriterInput.isReadyForMoreMediaData && isRecording {
                    assetWriter.startSession(atSourceTime: sourceTime)
                    videoWriterInput.append(sampleBuffer)
                }

                if bitVideoWriterInput.isReadyForMoreMediaData && isRecording {
                    bitAssetWriter.startSession(atSourceTime: sourceTime)
                    bitVideoWriterInput.append(sampleBuffer)
                }
            }
        case .audio:
            break
        @unknown default:
            break
        }
    }
    
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print(error.localizedDescription)
    }
}

extension SCWindow {
    var displayName: String {
        switch (owningApplication, title) {
        case (.some(let application), .some(let title)):
            return "\(application.applicationName): \(title)"
        case (.none, .some(let title)):
            return title
        case (.some(let application), .none):
            return "\(application.applicationName): \(windowID)"
        default:
            return ""
        }
    }
}

extension SCDisplay {
    var displayName: String {
        "Display: \(width) x \(height)"
    }
}
