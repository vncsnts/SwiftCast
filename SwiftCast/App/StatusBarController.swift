//
//  StatusBarController.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 6/30/23.
//

import AppKit
import SwiftUI

class StatusBarController {
    private var screenRecordManager: ScreenRecordManager
    private var cameraRecordManager: CameraRecordManager
    private var statusBar: NSStatusBar
    private (set) var statusItem: NSStatusItem
    
    init(screenRecordManager: ScreenRecordManager, cameraRecordManager: CameraRecordManager) {
        self.screenRecordManager = screenRecordManager
        self.cameraRecordManager = cameraRecordManager
        self.statusBar = .init()
        self.statusItem = self.statusBar.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "stop.circle.fill", accessibilityDescription: nil)
            button.action = #selector(stopRecording(sender:))
            button.target = self
        }
    }
    
    @objc func stopRecording(sender: AnyObject) {
        Task {
            await screenRecordManager.stopRecording()
            await cameraRecordManager.stopRecording()
            await MainActor.run {
                guard let mainWindow = NSApplication.shared.windows.first(where: {$0.title == "main"}) else { return }
                mainWindow.makeKeyAndOrderFront(nil)
                setButton(isHidden: true)
            }
        }
        
    }
    
    public func setButton(isHidden: Bool) {
        guard let button = statusItem.button else { return }
        button.isHidden = isHidden
    }
}
