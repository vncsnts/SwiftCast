//
//  RecordingViewModel.swift
//  SwiftCast
//

import Foundation

@MainActor
final class RecordingViewModel: ObservableObject {
    // MARK: - Published State

    @Published var isOnAlert = false
    @Published var alertMessage = ""
    @Published var isLoading = false
    @Published var loadingMessage = ""
    @Published var isUploading = false
    @Published var screenPublicUrl = ""
    @Published var cameraPublicUrl = ""
    @Published var presentSuccess = false
    @Published var showLibrary = false

    // MARK: - Dependencies

    private let serviceFactory: any ServiceFactory
    private let cacheManager: any SwiftCastCacheManager

    // Managers arrive via setup(...) from .onAppear because @StateObject is initialized
    // before @EnvironmentObject is resolved.
    private var screenRecordManager: (any ScreenRecordManager)?
    private var cameraRecordManager: (any CameraRecordManager)?
    private var statusBarManager: (any StatusBarManager)?
    private var appManager: (any AppManager)?

    private var currentID = ""

    init(
        serviceFactory: any ServiceFactory = DefaultServiceFactory.shared,
        cacheManager: any SwiftCastCacheManager = DefaultSwiftCastCacheManager.shared
    ) {
        self.serviceFactory = serviceFactory
        self.cacheManager = cacheManager
    }

    func setup(
        screen: any ScreenRecordManager,
        camera: any CameraRecordManager,
        statusBar: any StatusBarManager,
        app: any AppManager
    ) {
        screenRecordManager = screen
        cameraRecordManager = camera
        statusBarManager = statusBar
        appManager = app
    }

    // MARK: - Lifecycle

    /// Prepares the API service and capture devices when the screen appears.
    func initializeDevices() async {
        loadingMessage = Copy.checkingDevicesMessage
        isLoading = true
        do {
            try await serviceFactory.apiRequestService.initializeService()
            await screenRecordManager?.monitorAvailableContent()
            cameraRecordManager?.startCapture()
            isLoading = false
        } catch {
            isLoading = false
            alertMessage = error.localizedDescription
            isOnAlert = true
        }
    }

    // MARK: - Recording Flow

    func toggleRecording() {
        if screenRecordManager?.isRecording == true {
            stopRecording()
        } else {
            startRecording()
        }
    }

    func startRecording() {
        guard let screenRecordManager, let cameraRecordManager,
              let statusBarManager, let appManager else { return }
        loadingMessage = Copy.sendingStartMessage
        isLoading = true
        currentID = RecordingSession.makeSessionId()
        // Both screen and camera clips share the same session folder ID.
        let sessionID = currentID

        Task {
            isLoading = false
            await serviceFactory.apiQueueService.deleteAllChunks()
            await screenRecordManager.startRecording(with: sessionID)
            await cameraRecordManager.startRecording(with: sessionID)
            Task { await serviceFactory.apiQueueService.startCameraQueueChecker() }
            Task { await serviceFactory.apiQueueService.startScreenQueueChecker() }

            statusBarManager.showRecordingItem(onPauseToggle: { paused in
                screenRecordManager.setPaused(paused)
                cameraRecordManager.setPaused(paused)
            }, onStop: { [weak self] in
                self?.stopRecording()
            })
            appManager.hideMainWindow()
        }
    }

    func stopRecording() {
        guard let screenRecordManager, let cameraRecordManager,
              let statusBarManager, let appManager else { return }
        statusBarManager.hideRecordingItem()
        appManager.showMainWindow()

        Task {
            loadingMessage = Copy.stoppingRecordingMessage
            isLoading = true
            await screenRecordManager.stopRecording()
            await cameraRecordManager.stopRecording()
            guard cameraRecordManager.isChunked || screenRecordManager.isChunked else {
                isLoading = false
                return
            }
            isUploading = true
            loadingMessage = Copy.wrappingUpChunksMessage
            repeat {
                try? await Task.sleep(nanoseconds: 1.convertToNanoSeconds())
                guard let screenQueue = await serviceFactory.fileManager.getFolderFiles(folder: .screenQueue),
                      let cameraQueue = await serviceFactory.fileManager.getFolderFiles(folder: .cameraQueue) else { return }
                if screenQueue.isEmpty && cameraQueue.isEmpty {
                    loadingMessage = Copy.convertingMessage
                    isUploading = false
                    await finalizeRecordings()
                }
            } while isUploading
        }
    }

    /// Exchanges the uploaded chunk URLs for the final public URLs of both clips.
    private func finalizeRecordings() async {
        do {
            loadingMessage = Copy.gettingScreenUrlMessage
            let screenUrl = try await serviceFactory.apiRequestService.finalizeRecordings(
                chunkUrls: serviceFactory.apiQueueService.getScreenChunkUrls()
            )
            screenPublicUrl = screenUrl
            cacheManager.screenPublicUrls.append(screenUrl)

            loadingMessage = Copy.gettingCameraUrlMessage
            let cameraUrl = try await serviceFactory.apiRequestService.finalizeRecordings(
                chunkUrls: serviceFactory.apiQueueService.getCameraChunkUrls()
            )
            cameraPublicUrl = cameraUrl
            cacheManager.cameraPublicUrls.append(cameraUrl)

            await serviceFactory.apiQueueService.removeAllUrls()
            isLoading = false
            presentSuccess = true
        } catch {
            isLoading = false
            alertMessage = error.localizedDescription
            isOnAlert = true
        }
    }
}
