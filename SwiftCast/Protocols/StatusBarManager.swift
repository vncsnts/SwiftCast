//
//  StatusBarManager.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 6/11/26.
//

import Foundation

/// Controls the menu bar (status bar) item shown while a recording
/// session is active.
@MainActor
protocol StatusBarManager {
    /// Whether the active session is currently paused from the menu bar.
    var isPaused: Bool { get }

    /// Shows the recording item in the menu bar with Pause/Resume and Stop
    /// actions. Calling again while visible replaces the handlers.
    func showRecordingItem(onPauseToggle: @escaping (Bool) -> Void, onStop: @escaping () -> Void)

    /// Removes the recording item from the menu bar and clears handlers.
    func hideRecordingItem()
}
