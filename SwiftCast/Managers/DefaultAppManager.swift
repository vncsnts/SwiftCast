//
//  DefaultAppManager.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 6/29/23.
//

import AppKit

@MainActor
final class DefaultAppManager: ObservableObject, AppManager {
    public var fixedFrame = CGSize(width: 400, height: 600)

    /// Hides the main window while a recording session lives in the menu bar.
    public func hideMainWindow() {
        guard let window = mainWindow() else {
            print("AppManager: hideMainWindow - no window titled 'main' found. Titles: \(NSApplication.shared.windows.map(\.title))")
            return
        }
        window.orderOut(nil)
    }

    /// Brings the main window back to front when a session ends.
    public func showMainWindow() {
        mainWindow()?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func mainWindow() -> NSWindow? {
        NSApplication.shared.windows.first(where: { $0.title == "main" })
    }
}
