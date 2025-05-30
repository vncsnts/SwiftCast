//
//  RecordingView.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 6/29/23.
//

import SwiftUI

struct RecordingView: View {
    @EnvironmentObject var cameraManager: CameraRecordManager
    @EnvironmentObject var appManager: AppManager
    
    @StateObject var viewModel = RecordingViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            CameraView(image: cameraManager.frame)
                .animation(.easeInOut, value: cameraManager.selectedCamera.uniqueId)
            MenuView(content: {
                ForEach(cameraManager.cameraOptions, id: \.uniqueID) { device in
                    Button {
                        cameraManager.selectCamera(device: device)
                    } label: {
                        Text("\(device.localizedName)")
                    }
                }
            }, title: cameraManager.selectedCamera.localizedName, isDisabled: false)

            MenuView(content: {
                ForEach(cameraManager.audioOptions, id: \.uniqueID) { device in
                    Button {
                        cameraManager.selectAudio(device: device)
                    } label: {
                        Text("\(device.localizedName)")
                    }
                }
            }, title: cameraManager.selectedAudio.localizedName, isDisabled: false)
        }
        .task {
            cameraManager.startCapture()
        }
    }
}

struct RecordingView_Previews: PreviewProvider {
    static var previews: some View {
        RecordingView()
    }
}
