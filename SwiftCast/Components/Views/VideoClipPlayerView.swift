//
//  VideoClipPlayerView.swift
//  SwiftCast
//

import SwiftUI
import AVKit

/// A bare video playback surface with no player controls — used inside the editor canvas.
struct VideoClipPlayerView: NSViewRepresentable {
    let player: AVPlayer
    var gravity: AVLayerVideoGravity = .resizeAspect

    func makeNSView(context: Context) -> PlayerLayerHostView {
        let view = PlayerLayerHostView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = gravity
        return view
    }

    func updateNSView(_ nsView: PlayerLayerHostView, context: Context) {
        if nsView.playerLayer.player !== player {
            nsView.playerLayer.player = player
        }
        if nsView.playerLayer.videoGravity != gravity {
            nsView.playerLayer.videoGravity = gravity
        }
    }
}

/// Hosts a bare AVPlayerLayer as the view's backing layer. Unlike AVPlayerView — which
/// re-lays-out its internal view tree asynchronously and can visibly lag or wobble when
/// its frame moves — a backing layer tracks geometry synchronously with no implicit
/// animation, so face-track panning can move the surface every frame without jitter.
final class PlayerLayerHostView: NSView {
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    init() {
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func makeBackingLayer() -> CALayer {
        AVPlayerLayer()
    }
}
