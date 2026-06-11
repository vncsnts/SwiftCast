//
//  RecordingViewModel+Copy.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 6/11/26.
//

import Foundation

extension RecordingViewModel {
    enum Copy {
        static let appName = "SwiftCast"
        static let betaBadge = "BETA"
        static let recordingBadge = "REC"

        static let sourcesSectionTitle = "Sources"
        static let cameraSourceLabel = "Camera"
        static let microphoneSourceLabel = "Microphone"
        static let displaySourceLabel = "Display"
        static let noDisplaySelectedValue = "None"

        static let recordingFootnote = "Your screen and camera are recorded together and shared as links when you stop."

        static let startRecordingButtonTitle = "Start Recording"
        static let stopRecordingButtonTitle = "Stop Recording"

        static let alertTitle = "SwiftCast"
        static let alertOK = "OK"

        static let checkingDevicesMessage = "Checking Devices..."
        static let sendingStartMessage = "Sending Start Record to Server..."
        static let stoppingRecordingMessage = "Stop Recording..."
        static let wrappingUpChunksMessage = "Wrapping up remaining Recording Chunks..."
        static let convertingMessage = "Converting to mp4..."
        static let gettingScreenUrlMessage = "Getting Screen Stream URL..."
        static let gettingCameraUrlMessage = "Getting Camera Stream URL..."
    }
}
