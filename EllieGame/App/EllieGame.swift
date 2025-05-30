//
//  EllieGame.swift
//  EllieGame
//
//  Created by Vince Carlo Santos on 6/10/23.
//

import SwiftUI

@main
struct EllieGame: App {
    @ObservedObject var cameraRecordManager = CameraRecordManager()
    @ObservedObject var appManager = AppManager()
    @ObservedObject var soundManager = SoundEffectsManager()
    
    var body: some Scene {
        WindowGroup {
            CameraGameView(cameraManager: cameraRecordManager)
                .environmentObject(cameraRecordManager)
                .environmentObject(appManager)
                .environmentObject(soundManager)
        }
    }
}
