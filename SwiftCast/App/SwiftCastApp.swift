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
                .environmentObject(appDelegate.screenRecordManager)
                .environmentObject(appDelegate.cameraRecordManager)
                .environmentObject(appDelegate.appManager)
                .environmentObject(appDelegate)
        }
        .windowStyle(.hiddenTitleBar)
        .handlesExternalEvents(matching: ["swiftCast"]) // create new window if doesn't exist
    }
}
