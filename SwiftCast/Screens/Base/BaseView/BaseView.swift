//
//  BaseView.swift
//  RecordMe
//
//  Created by Vince Carlo Santos on 6/10/23.
//

import SwiftUI

struct BaseView: View {
    @EnvironmentObject var screenRecordManager: DefaultScreenRecordManager
    @EnvironmentObject var cameraManager: DefaultCameraRecordManager

    @StateObject var viewModel = BaseViewModel()
    
    var body: some View {
        RecordingView()
            .alert(BaseViewModel.Copy.alertTitle, isPresented: $viewModel.isOnAlert) {

            } message: {
                Text(viewModel.alertMessage)
            }
    }
}

struct BaseView_Previews: PreviewProvider {
    static var previews: some View {
        BaseView()
    }
}
