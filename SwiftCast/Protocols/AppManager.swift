//
//  AppManager.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 6/12/26.
//

import CoreGraphics

/// Manages the main window's fixed size and visibility.
@MainActor
protocol AppManager {
    /// The fixed size of the main window.
    var fixedFrame: CGSize { get }

    /// Hides the main window while a recording session lives in the menu bar.
    func hideMainWindow()

    /// Brings the main window back to front when a session ends.
    func showMainWindow()
}
