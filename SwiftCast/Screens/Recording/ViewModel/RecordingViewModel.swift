//
//  RecordingViewModel.swift
//  swiftCastFolderPath
//
//  Created by Vince Carlo Santos on 7/13/23.
//

import Foundation

@MainActor
final class RecordingViewModel: ObservableObject {
    @Published var isOnAlert = false
    @Published var alertMessage = ""
    @Published var isLoading = false
    @Published var loadingMessage = ""
    @Published var isUploading = false
    @Published var screenPublicUrl = ""
    @Published var cameraPublicUrl = ""
    @Published var presentSuccess = false
    private var currentID = ""
    
    func setCurrentStreamId(streamId: String) {
        currentID = streamId
    }
    
    func getCurrentStreamId() -> String {
        return currentID
    }
    
    func getCurrentScreenStreamId() -> String {
        return currentID + "-screen"
    }
    
    func getCurrentCameraStreamId() -> String {
        return currentID + "-camera"
    }
}
