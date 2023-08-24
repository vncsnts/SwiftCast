//
//  LoginView.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 6/29/23.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appManager: AppManager
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "camera.filters")
                Spacer()
            }
            .padding([.leading, .trailing, .bottom])
            
            Spacer()
            
            SwiftCastButton(title: "Sign Up")
            SwiftCastButton(action: {
//                if let url = URL(string: "") {
//                    NSWorkspace.shared.open(url)
//                }
            }, title: "Login")

            Spacer()
        }
        .background(.background)
        .frame(width: appManager.fixedFrame.width, height: appManager.fixedFrame.height, alignment: .center)
        .preferredColorScheme(.light)
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
