//
//  CameraView.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 6/13/23.
//

import SwiftUI

struct CameraView: View {
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
            Color.black
        }
    }
}

struct FrameView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView()
    }
}
