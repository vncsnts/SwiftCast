//
//  SuccessRecordingView.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 8/8/23.
//

import SwiftUI

struct SuccessRecordingView: View {
    @Environment(\.dismiss) var dismiss
    @State var screenUrl: String
    @State var cameraUrl: String
    
    var body: some View {
        VStack {
            Text("Done!")
            Button {
                if let url = URL(string: "https://frontend-component-git-mon-1254-impor-ccffb5-swiftCast-interactive.vercel.app/importscreenrecording?url=\(screenUrl)&overlayURL=\(cameraUrl)") {
                    NSWorkspace.shared.open(url)
                    dismiss()
                }
            } label: {
                Text("Send to SwiftCast Project")
            }
            .buttonStyle(.borderedProminent)

        }
        .padding()
    }
}
