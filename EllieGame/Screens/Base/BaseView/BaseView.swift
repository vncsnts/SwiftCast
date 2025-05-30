//
//  BaseView.swift
//  RecordMe
//
//  Created by Vince Carlo Santos on 6/10/23.
//

import SwiftUI

struct BaseView: View {
    @EnvironmentObject var cameraManager: CameraRecordManager
    @EnvironmentObject var appManager: AppManager
    
    @StateObject var viewModel = BaseViewModel()
    
    var body: some View {
        Group {
            switch appManager.appViewState {
            case .startRecord:
                RecordingView()
            }
        }
        .task {
            appManager.appViewState = .startRecord
        }
    }
}

struct BaseView_Previews: PreviewProvider {
    static var previews: some View {
        BaseView()
    }
}
