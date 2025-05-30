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
            Text("Saved Recording.")
            Button {
//                if let url = URL(string: "") {
//                    NSWorkspace.shared.open(url)
//                    dismiss()
//                }
                dismiss()
            } label: {
                Text("Done")
            }
            .buttonStyle(.borderedProminent)

        }
        .padding()
    }
}
