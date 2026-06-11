//
//  CameraRecordManager.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 6/12/26.
//

import AVFoundation
import CoreGraphics

/// Captures camera video and microphone audio for a recording session,
/// including device selection and pause/resume control.
@MainActor
protocol CameraRecordManager {
    /// The latest camera frame, for live preview.
    var frame: CGImage? { get }

    /// The camera devices available for capture.
    var cameraOptions: [AVCaptureDevice] { get }

    /// The audio devices available for capture.
    var audioOptions: [AVCaptureDevice] { get }

    /// The camera currently feeding the capture session.
    var selectedCamera: SelectedDevice { get }

    /// The microphone currently feeding the capture session.
    var selectedAudio: SelectedDevice { get }

    /// Whether a recording session is currently active.
    var isRecording: Bool { get }

    /// Whether the active session is paused. No frames are written while paused.
    var isPaused: Bool { get }

    /// Whether the session also produces short chunk files for upload.
    var isChunked: Bool { get set }

    /// Starts the capture session so the live preview begins.
    func startCapture()

    /// Starts writing camera and audio output for the given stream.
    func startRecording(with streamId: String) async

    /// Stops recording and finalizes the output file.
    func stopRecording() async

    /// Pauses or resumes capture without ending the session.
    func setPaused(_ paused: Bool)

    /// Selects the camera to capture from.
    func selectCamera(device: AVCaptureDevice)

    /// Selects the microphone to capture from.
    func selectAudio(device: AVCaptureDevice)
}
