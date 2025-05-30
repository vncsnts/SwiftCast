//
//  BaseViewModel.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 7/18/23.
//

import Foundation

@MainActor
class BaseViewModel: ObservableObject {
    @Published var isOnAlert = false
    @Published var alertMessage = ""
}
