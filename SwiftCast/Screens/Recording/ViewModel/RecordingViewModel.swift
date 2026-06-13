//
//  RecordingViewModel.swift
//  SwiftCast
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
    @Published var showLibrary = false
    private var currentID = ""

    func setCurrentStreamId() {
        currentID = RecordingSession.makeSessionId()
    }

    func getCurrentStreamId() -> String {
        return currentID
    }

    // Both screen and camera clips share the same session folder ID.
    func getCurrentScreenStreamId() -> String {
        return currentID
    }

    func getCurrentCameraStreamId() -> String {
        return currentID
    }
}
