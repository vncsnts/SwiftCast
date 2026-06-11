//
//  DefaultStatusBarManager.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 6/11/26.
//

import AppKit

/// Owns the NSStatusItem that represents an active recording session in the
/// macOS menu bar. The item appears when recording starts and offers
/// Pause/Resume and Stop; it disappears when the session ends.
@MainActor
final class DefaultStatusBarManager: NSObject, ObservableObject, StatusBarManager {
    @Published private(set) var isPaused = false

    private var statusItem: NSStatusItem?
    private var onPauseToggle: ((Bool) -> Void)?
    private var onStop: (() -> Void)?

    private enum Copy {
        static let pause = "Pause Recording"
        static let resume = "Resume Recording"
        static let stop = "Stop Recording"
        static let itemDescription = "SwiftCast Recording"
    }

    func showRecordingItem(onPauseToggle: @escaping (Bool) -> Void, onStop: @escaping () -> Void) {
        self.onPauseToggle = onPauseToggle
        self.onStop = onStop
        isPaused = false
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        }
        statusItem?.isVisible = true
        refreshItem()
        print("StatusBarManager: showRecordingItem - item created: \(statusItem != nil), visible: \(statusItem?.isVisible ?? false), button image: \(statusItem?.button?.image != nil)")
    }

    func hideRecordingItem() {
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
        onPauseToggle = nil
        onStop = nil
        isPaused = false
    }

    private func refreshItem() {
        guard let statusItem else { return }
        let symbol = isPaused ? "pause.circle.fill" : "record.circle.fill"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: Copy.itemDescription)
        image?.isTemplate = true
        statusItem.button?.image = image

        let menu = NSMenu()
        let pauseItem = NSMenuItem(title: isPaused ? Copy.resume : Copy.pause, action: #selector(togglePause), keyEquivalent: "")
        pauseItem.target = self
        menu.addItem(pauseItem)
        menu.addItem(.separator())
        let stopItem = NSMenuItem(title: Copy.stop, action: #selector(stopTapped), keyEquivalent: "")
        stopItem.target = self
        menu.addItem(stopItem)
        statusItem.menu = menu
    }

    @objc private func togglePause() {
        isPaused.toggle()
        onPauseToggle?(isPaused)
        refreshItem()
    }

    @objc private func stopTapped() {
        onStop?()
    }
}
