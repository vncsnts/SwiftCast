//
//  VideoClipPlayerView.swift
//  SwiftCast
//

import SwiftUI
import AVKit

/// A bare video playback surface with no player controls — used inside the editor canvas.
struct VideoClipPlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }
}
