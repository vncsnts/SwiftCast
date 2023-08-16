//
//  RecordingView.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 6/29/23.
//

import SwiftUI

struct RecordingView: View {
    @EnvironmentObject var screenRecordManager: ScreenRecordManager
    @EnvironmentObject var cameraManager: CameraRecordManager
    @EnvironmentObject var appManager: AppManager
    @EnvironmentObject var appDelegate: AppDelegate
    
    @StateObject var viewModel = RecordingViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image("swiftCast_logo")
                    .resizable()
                    .colorInvert()
                    .frame(width: 35, height: 25, alignment: .center)
                Spacer()
                HeaderBadge(title: screenRecordManager.isRecording ? "REC" : "BETA")
            }
            .padding([.leading, .trailing, .bottom])
            .background(Color("secondaryColor"))
            
            CameraView(image: cameraManager.frame)
                .animation(.easeInOut, value: cameraManager.selectedCamera.uniqueId)
            Spacer()
            MenuView(content: {
                ForEach(cameraManager.cameraOptions, id: \.uniqueID) { device in
                    Button {
                        cameraManager.selectCamera(device: device)
                    } label: {
                        Text("\(device.localizedName)")
                    }
                }
            }, title: cameraManager.selectedCamera.localizedName, isDisabled: screenRecordManager.isRecording)

            MenuView(content: {
                ForEach(cameraManager.audioOptions, id: \.uniqueID) { device in
                    Button {
                        cameraManager.selectAudio(device: device)
                    } label: {
                        Text("\(device.localizedName)")
                    }
                }
            }, title: cameraManager.selectedAudio.localizedName, isDisabled: screenRecordManager.isRecording)
            
            MenuView(content: {
                ForEach(screenRecordManager.availableDisplays, id: \.displayID) { display in
                    Button {
                        screenRecordManager.selectDisplay(display: display)
                    } label: {
                        Text("\(display.displayName)")
                    }
                }
            }, title: screenRecordManager.selectedDisplay?.displayName ?? "", isDisabled: screenRecordManager.isRecording)
            
            SwiftCastButton(action: {
                if screenRecordManager.isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            }, title: screenRecordManager.isRecording ? "Stop Recording" : "Start Recording", withCountdown: !screenRecordManager.isRecording)
        }
        .onAppear {
            Task {
                viewModel.loadingMessage = "Checking Devices..."
                viewModel.isLoading = true
                do {
                    try await APIRequestService.shared.initializeService()
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
        .background(.background)
        .frame(width: appManager.fixedFrame.width, height: appManager.fixedFrame.height, alignment: .center)
        .preferredColorScheme(.light)
        .loadingView(isLoading: $viewModel.isLoading, message: $viewModel.loadingMessage)
        .alert("SwiftCast", isPresented: $viewModel.isOnAlert) {
            Button {
                
            } label: {
                Text("OK")
            }

        } message: {
            Text(viewModel.alertMessage)
        }
        .sheet(isPresented: $viewModel.presentSuccess) {
            SuccessRecordingView(screenUrl: viewModel.screenPublicUrl, cameraUrl: viewModel.cameraPublicUrl)
        }
    }
}

extension RecordingView {
    func startRecording() {
        viewModel.loadingMessage = "Sending Start Record to Server..."
        viewModel.isLoading = true
        viewModel.setCurrentStreamId(streamId: UUID().uuidString)
        let cameraUUID =  viewModel.getCurrentCameraStreamId()
        let screenUUID = viewModel.getCurrentScreenStreamId()
    
        Task {
            viewModel.isLoading = false
            await APIQueueService.shared.deleteAllChunks()
            await screenRecordManager.startRecording(with: screenUUID)
            await cameraManager.startRecording(with: cameraUUID)
            Task {
                await APIQueueService.shared.startCameraQueueChecker()
            }
            
            Task {
                await APIQueueService.shared.startScreenQueueChecker()
            }
        }
    }
    
    func stopRecording() {
        Task {
            viewModel.loadingMessage = "Stop Recording..."
            viewModel.isLoading = true
            await screenRecordManager.stopRecording()
            await cameraManager.stopRecording()
            viewModel.isUploading = true
            viewModel.loadingMessage = "Wrapping up remaining Recording Chunks..."
            repeat {
                try? await Task.sleep(nanoseconds: 1.convertToNanoSeconds())
                guard let screenQueue = await SwiftCastFileManager.shared.getFolderFiles(folder: .screenQueue), let cameraQueue = await SwiftCastFileManager.shared.getFolderFiles(folder: .cameraQueue) else { return }
                if screenQueue.isEmpty && cameraQueue.isEmpty {
                    viewModel.loadingMessage = "Converting to mp4..."
                    viewModel.isUploading = false
                    viewModel.loadingMessage = "Getting Screen Stream URL..."
                    do {
                        let screenPublicUrl = try await APIRequestService.shared.finalizeRecordings(chunkUrls: APIQueueService.shared.getScreenChunkUrls())
                        viewModel.screenPublicUrl = screenPublicUrl
                        SwiftCastCacheManager.shared.screenPublicUrls.append(screenPublicUrl)
                        viewModel.loadingMessage = "Getting Camera Stream URL..."
                        let cameraPublicUrl = try await APIRequestService.shared.finalizeRecordings(chunkUrls: APIQueueService.shared.getCameraChunkUrls())
                        viewModel.cameraPublicUrl = cameraPublicUrl
                        SwiftCastCacheManager.shared.cameraPublicUrls.append(screenPublicUrl)
                        await APIQueueService.shared.removeAllUrls()
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
        }
    }
}

struct RecordingView_Previews: PreviewProvider {
    static var previews: some View {
        RecordingView()
    }
}
