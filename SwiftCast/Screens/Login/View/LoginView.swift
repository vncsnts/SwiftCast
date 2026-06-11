//
//  LoginView.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 6/29/23.
//

import SwiftUI

struct LoginView: View {
    @Environment(\.appTheme) private var t
    @EnvironmentObject var appManager: AppManager

    @StateObject var viewModel = LoginViewModel()

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: t.spacing.large) {
                ZStack {
                    Circle()
                        .fill(t.color.background.accent.gradient)
                        .frame(width: 72, height: 72)
                    Image(systemName: "camera.filters")
                        .font(t.font.heading)
                        .foregroundColor(t.color.foreground.onAccent)
                }
                VStack(spacing: t.spacing.xs) {
                    Text(LoginViewModel.Copy.appName)
                        .font(t.font.heading)
                        .foregroundColor(t.color.foreground.default)
                    Text(LoginViewModel.Copy.tagline)
                        .font(t.font.body)
                        .foregroundColor(t.color.foreground.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()

            VStack(spacing: t.spacing.medium) {
                SwiftCastButton(action: {
//                if let url = URL(string: "") {
//                    NSWorkspace.shared.open(url)
//                }
                }, title: LoginViewModel.Copy.logInButtonTitle)
                SwiftCastButton(title: LoginViewModel.Copy.createAccountButtonTitle, isProminent: false)
            }
            .padding(.horizontal, t.padding.xl)
            .padding(.bottom, t.padding.xl)
        }
        .frame(width: appManager.fixedFrame.width, height: appManager.fixedFrame.height, alignment: .center)
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
