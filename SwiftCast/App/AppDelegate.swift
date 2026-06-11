//
//  AppDelegate.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 6/30/23.
//

import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @ObservedObject var screenRecordManager = DefaultScreenRecordManager()
    @ObservedObject var cameraRecordManager = DefaultCameraRecordManager()
    @ObservedObject var appManager = DefaultAppManager()
    let statusBarManager = DefaultStatusBarManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let mainWindow = NSApplication.shared.windows.first(where: {$0.title == "main"}) else { return }
        mainWindow.level = .floating
    }
}
