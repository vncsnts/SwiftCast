//
//  BaseView.swift
//  RecordMe
//
//  Created by Vince Carlo Santos on 6/10/23.
//

import SwiftUI

struct BaseView: View {
    @EnvironmentObject var screenRecordManager: ScreenRecordManager
    @EnvironmentObject var cameraManager: CameraRecordManager
    @EnvironmentObject var appManager: AppManager
    
    @StateObject var viewModel = BaseViewModel()
    
    var body: some View {
        Group {
            switch appManager.appViewState {
            case .login:
                LoginView()
            case .startRecord:
                RecordingView()
            }
        }
        .onAppear {
            Task {
                appManager.appViewState = .startRecord
            }
        }
        .handlesExternalEvents(preferring: ["swiftCast"], allowing: ["*"]) // activate existing window if exists
        .onOpenURL { incomingURL in
            handleIncomingURL(incomingURL)
        }
        .alert("SwiftCast", isPresented: $viewModel.isOnAlert) {
            
        } message: {
            Text(viewModel.alertMessage)
        }

    }
    
    /// Handles the incoming URL and performs validations before acknowledging.
    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "swiftCast" else {
            return
        }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            print("Invalid URL")
            return
        }
        
        guard let action = components.host, action == "login" else {
            print("Unknown URL, we can't handle this one!")
            return
        }
        
        guard let token = components.queryItems?.first(where: { $0.name == "token" })?.value else {
            print("Token not found")
            return
        }
        
        Task {
            await APIRequestService.shared.setAccessToken(token: token)
            appManager.appViewState = .startRecord
        }
    }
}

struct BaseView_Previews: PreviewProvider {
    static var previews: some View {
        BaseView()
    }
}
