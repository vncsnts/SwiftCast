//
//  RecordingView.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 6/29/23.
//

import SwiftUI

struct RecordingView: View {
    @Environment(\.appTheme) private var t
    @EnvironmentObject var screenRecordManager: DefaultScreenRecordManager
    @EnvironmentObject var cameraManager: DefaultCameraRecordManager
    @EnvironmentObject var appManager: DefaultAppManager
    @EnvironmentObject var statusBarManager: DefaultStatusBarManager
    @EnvironmentObject var appDelegate: AppDelegate

    @StateObject var viewModel = RecordingViewModel()

    var body: some View {
        VStack(spacing: t.spacing.large) {
            header
            preview
            sources
            Spacer(minLength: 0)
            SwiftCastButton(action: {
                if screenRecordManager.isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            }, title: screenRecordManager.isRecording ? RecordingViewModel.Copy.stopRecordingButtonTitle : RecordingViewModel.Copy.startRecordingButtonTitle,
               systemImage: screenRecordManager.isRecording ? "stop.fill" : "record.circle",
               tint: screenRecordManager.isRecording ? t.color.status.recording : nil,
               withCountdown: !screenRecordManager.isRecording)
        }
        .padding(t.padding.xl)
        .onAppear {
            Task {
                viewModel.loadingMessage = RecordingViewModel.Copy.checkingDevicesMessage
                viewModel.isLoading = true
                do {
                    try await DefaultAPIRequestService.shared.initializeService()
                    await screenRecordManager.monitorAvailableContent()
                    cameraManager.startCapture()
                    viewModel.isLoading = false
                } catch {
                    viewModel.isLoading = false
                    viewModel.alertMessage = error.localizedDescription
                    viewModel.isOnAlert = true
                }
                
            }
        }
        .frame(width: appManager.fixedFrame.width, height: appManager.fixedFrame.height, alignment: .center)
        .loadingView(isLoading: $viewModel.isLoading, message: $viewModel.loadingMessage)
        .alert(RecordingViewModel.Copy.alertTitle, isPresented: $viewModel.isOnAlert) {
            Button {

            } label: {
                Text(RecordingViewModel.Copy.alertOK)
            }

        } message: {
            Text(viewModel.alertMessage)
        }
        .sheet(isPresented: $viewModel.presentSuccess) {
            SuccessRecordingView(screenUrl: viewModel.screenPublicUrl, cameraUrl: viewModel.cameraPublicUrl)
        }
    }

    @ViewBuilder private var header: some View {
        HStack(spacing: t.spacing.small) {
            Image(systemName: "camera.filters")
                .font(t.font.pillValue)
                .foregroundColor(t.color.foreground.accent)
            Text(RecordingViewModel.Copy.appName)
                .font(t.font.pillValue)
                .foregroundColor(t.color.foreground.default)
            Spacer()
        }
    }

    @ViewBuilder private var recordingPill: some View {
        HStack(spacing: t.spacing.xs) {
            Circle()
                .fill(screenRecordManager.isPaused ? t.color.status.paused : t.color.status.recording)
                .frame(width: 7, height: 7)
            Text(screenRecordManager.isPaused ? RecordingViewModel.Copy.pausedBadge : RecordingViewModel.Copy.recordingBadge)
                .font(t.font.pillLabel)
                .foregroundColor(t.color.foreground.default)
        }
        .padding(.horizontal, t.padding.small)
        .padding(.vertical, t.padding.xs)
        .glassCapsule()
    }

    @ViewBuilder private var preview: some View {
        CameraView(image: cameraManager.frame, stretch: true)
            .frame(maxWidth: .infinity)
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: t.cornerRadius.medium, style: .continuous))
            .overlay(alignment: .topLeading) {
                if screenRecordManager.isRecording {
                    recordingPill
                        .padding(t.padding.small)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .animation(.easeInOut, value: cameraManager.selectedCamera.uniqueId)
            .animation(.easeInOut, value: screenRecordManager.isRecording)
    }

    @ViewBuilder private var sources: some View {
        VStack(alignment: .leading, spacing: t.spacing.small) {
            SectionCaption(title: RecordingViewModel.Copy.sourcesSectionTitle)
            VStack(spacing: 0) {
                MenuView(content: {
                    ForEach(cameraManager.cameraOptions, id: \.uniqueID) { device in
                        Button {
                            cameraManager.selectCamera(device: device)
                        } label: {
                            Text("\(device.localizedName)")
                        }
                    }
                }, label: RecordingViewModel.Copy.cameraSourceLabel, systemImage: "video.fill", value: cameraManager.selectedCamera.localizedName, isDisabled: screenRecordManager.isRecording)

                rowDivider

                MenuView(content: {
                    ForEach(cameraManager.audioOptions, id: \.uniqueID) { device in
                        Button {
                            cameraManager.selectAudio(device: device)
                        } label: {
                            Text("\(device.localizedName)")
                        }
                    }
                }, label: RecordingViewModel.Copy.microphoneSourceLabel, systemImage: "mic.fill", value: cameraManager.selectedAudio.localizedName, isDisabled: screenRecordManager.isRecording)

                rowDivider

                MenuView(content: {
                    ForEach(screenRecordManager.availableDisplays, id: \.displayID) { display in
                        Button {
                            screenRecordManager.selectDisplay(display: display)
                        } label: {
                            Text("\(display.displayName)")
                        }
                    }
                }, label: RecordingViewModel.Copy.displaySourceLabel, systemImage: "display", value: screenRecordManager.selectedDisplay?.displayName ?? RecordingViewModel.Copy.noDisplaySelectedValue, isDisabled: screenRecordManager.isRecording)
            }
            .clipShape(RoundedRectangle(cornerRadius: t.cornerRadius.medium, style: .continuous))
            .glassCard(cornerRadius: t.cornerRadius.medium)

            Text(RecordingViewModel.Copy.recordingFootnote)
                .font(t.font.helper)
                .foregroundColor(t.color.foreground.tertiary)
                .padding(.horizontal, t.padding.medium)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var rowDivider: some View {
        Rectangle()
            .fill(t.color.border.default)
            .frame(height: 1)
            .padding(.leading, t.padding.medium + 20 + t.padding.medium)
    }
}

extension RecordingView {
    func startRecording() {
        viewModel.loadingMessage = RecordingViewModel.Copy.sendingStartMessage
        viewModel.isLoading = true
        viewModel.setCurrentStreamId(streamId: UUID().uuidString)
        let cameraUUID =  viewModel.getCurrentCameraStreamId()
        let screenUUID = viewModel.getCurrentScreenStreamId()
    
        Task {
            viewModel.isLoading = false
            await DefaultAPIQueueService.shared.deleteAllChunks()
            await screenRecordManager.startRecording(with: screenUUID)
            await cameraManager.startRecording(with: cameraUUID)
            Task {
                await DefaultAPIQueueService.shared.startCameraQueueChecker()
            }

            Task {
                await DefaultAPIQueueService.shared.startScreenQueueChecker()
            }

            let screen = screenRecordManager
            let camera = cameraManager
            statusBarManager.showRecordingItem(onPauseToggle: { paused in
                screen.setPaused(paused)
                camera.setPaused(paused)
            }, onStop: {
                stopRecording()
            })
            appManager.hideMainWindow()
        }
    }
    
    func stopRecording() {
        statusBarManager.hideRecordingItem()
        appManager.showMainWindow()
        Task {
            viewModel.loadingMessage = RecordingViewModel.Copy.stoppingRecordingMessage
            viewModel.isLoading = true
            await screenRecordManager.stopRecording()
            await cameraManager.stopRecording()
            if cameraManager.isChunked || screenRecordManager.isChunked {
                viewModel.isUploading = true
                viewModel.loadingMessage = RecordingViewModel.Copy.wrappingUpChunksMessage
                repeat {
                    try? await Task.sleep(nanoseconds: 1.convertToNanoSeconds())
                    guard let screenQueue = await DefaultSwiftCastFileManager.shared.getFolderFiles(folder: .screenQueue), let cameraQueue = await DefaultSwiftCastFileManager.shared.getFolderFiles(folder: .cameraQueue) else { return }
                    if screenQueue.isEmpty && cameraQueue.isEmpty {
                        viewModel.loadingMessage = RecordingViewModel.Copy.convertingMessage
                        viewModel.isUploading = false
                        viewModel.loadingMessage = RecordingViewModel.Copy.gettingScreenUrlMessage
                        do {
                            let screenPublicUrl = try await DefaultAPIRequestService.shared.finalizeRecordings(chunkUrls: DefaultAPIQueueService.shared.getScreenChunkUrls())
                            viewModel.screenPublicUrl = screenPublicUrl
                            DefaultSwiftCastCacheManager.shared.screenPublicUrls.append(screenPublicUrl)
                            viewModel.loadingMessage = RecordingViewModel.Copy.gettingCameraUrlMessage
                            let cameraPublicUrl = try await DefaultAPIRequestService.shared.finalizeRecordings(chunkUrls: DefaultAPIQueueService.shared.getCameraChunkUrls())
                            viewModel.cameraPublicUrl = cameraPublicUrl
                            DefaultSwiftCastCacheManager.shared.cameraPublicUrls.append(screenPublicUrl)
                            await DefaultAPIQueueService.shared.removeAllUrls()
                            viewModel.isUploading = false
                            viewModel.isLoading = false
                            viewModel.presentSuccess = true
                        } catch(let error) {
                            viewModel.isLoading = false
                            viewModel.alertMessage = error.localizedDescription
                            viewModel.isOnAlert = true
                        }
                    }
                } while viewModel.isUploading
            } else {
                viewModel.isLoading = false
            }
        }
    }
}

struct RecordingView_Previews: PreviewProvider {
    static var previews: some View {
        RecordingView()
    }
}
