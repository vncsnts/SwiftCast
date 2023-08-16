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
                Image("swiftCast_logo")
                    .resizable()
                    .colorInvert()
                    .frame(width: 35, height: 25, alignment: .center)
                Spacer()
                
                HeaderBadge(title: "BETA")
            }
            .padding([.leading, .trailing, .bottom])
            .background(Color("secondaryColor"))
            
            Spacer()
            
            SwiftCastButton(title: "Sign Up")
            SwiftCastButton(action: {
                if let url = URL(string: "https://frontend-component-6y3kus7ek-swiftCast-interactive.vercel.app/desktoplogin") {
                    NSWorkspace.shared.open(url)
                }
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
