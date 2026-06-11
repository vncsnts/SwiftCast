//
//  ScreenRecordManager.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 6/12/26.
//

import ScreenCaptureKit

/// Captures screen content for a recording session, including display
/// selection and pause/resume control.
@MainActor
protocol ScreenRecordManager {
    /// Whether a capture session is currently active.
    var isRecording: Bool { get }

    /// Whether the active session is paused. No frames are written while paused.
    var isPaused: Bool { get }

    /// Whether the session also produces short chunk files for upload.
    var isChunked: Bool { get set }

    /// The displays available for capture.
    var availableDisplays: [SCDisplay] { get }

    /// The display that will be captured, if any.
    var selectedDisplay: SCDisplay? { get }

    /// Whether the app has Screen Recording permission.
    var canRecord: Bool { get async }

    /// Refreshes the available displays and windows.
    func monitorAvailableContent() async

    /// Starts capturing screen content for the given stream.
    func startRecording(with streamId: String) async

    /// Stops capturing screen content and finalizes the output file.
    func stopRecording() async

    /// Pauses or resumes capture without ending the session.
    func setPaused(_ paused: Bool)

    /// Selects the display to capture.
    func selectDisplay(display: SCDisplay)
}
