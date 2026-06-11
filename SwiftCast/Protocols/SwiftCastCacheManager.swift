//
//  SwiftCastCacheManager.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 6/12/26.
//

import Foundation

/// Persists the public URLs of uploaded recording chunks across launches.
protocol SwiftCastCacheManager: AnyObject {
    /// Public URLs of the uploaded screen recording chunks.
    var screenPublicUrls: [String] { get set }

    /// Public URLs of the uploaded camera recording chunks.
    var cameraPublicUrls: [String] { get set }
}
