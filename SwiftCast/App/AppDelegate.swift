//
//  AppDelegate.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 6/30/23.
//

import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @ObservedObject var screenRecordManager = ScreenRecordManager()
    @ObservedObject var cameraRecordManager = CameraRecordManager()
    @ObservedObject var appManager = AppManager()

//    var statusBar: StatusBarController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
//        statusBar = StatusBarController(screenRecordManager: screenRecordManager, cameraRecordManager: cameraRecordManager)
//        statusBar?.setButton(isHidden: true)
        guard let mainWindow = NSApplication.shared.windows.first(where: {$0.title == "main"}) else { return }
        mainWindow.level = .floating
    }
}
