//
//  AppManager.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 6/29/23.
//

import Foundation

@MainActor
final class AppManager: ObservableObject {
    @Published var appViewState: AppViewState = .login
    public var fixedFrame = CGSize(width: 400, height: 600)
}

enum AppViewState {
    case login
    case startRecord
}
