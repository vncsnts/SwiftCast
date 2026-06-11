//
//  CameraView.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 6/13/23.
//

import SwiftUI

struct CameraView: View {
    @Environment(\.appTheme) private var t
    var image: CGImage?
    var stretch = false
    private let label = Text("frame")

    var body: some View {
        if let image = image {
            if stretch {
                Image(image, scale: 1.0, orientation: .upMirrored, label: label)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(image, scale: 1.0, orientation: .upMirrored, label: label)
                    .resizable()
                    .scaledToFit()
            }
        } else {
            ZStack {
                Color.black
                VStack(spacing: t.spacing.small) {
                    Image(systemName: "video.slash.fill")
                        .font(t.font.heading)
                    Text("Camera is off")
                        .font(t.font.helper)
                }
                .foregroundColor(t.color.foreground.onAccent.opacity(0.55))
            }
        }
    }
}

struct FrameView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView()
    }
}
