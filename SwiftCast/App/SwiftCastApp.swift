//
//  SwiftCastApp.swift
//  SwiftCastApp
//
//  Created by Vince Carlo Santos on 6/10/23.
//

import SwiftUI

@main
struct SwiftCastApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("main") {
            BaseView()
                .theme(SwiftCastTheme())
                .windowGlassBackground()
                .environmentObject(appDelegate.screenRecordManager)
                .environmentObject(appDelegate.cameraRecordManager)
                .environmentObject(appDelegate.appManager)
                .environmentObject(appDelegate)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .handlesExternalEvents(matching: ["swiftCast"]) // create new window if doesn't exist
    }
}
