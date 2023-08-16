//
//  SwiftCastCacheManager.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 8/8/23.
//

import Foundation

final class SwiftCastCacheManager {
    static let shared = SwiftCastCacheManager()
    var screenPublicUrls: [String] {
        get {
            return UserDefaults.standard.stringArray(forKey: SwiftCastCacheType.screenPublicUrls.rawValue) ?? [String]()
        }
        
        set {
            UserDefaults.standard.set(newValue, forKey:SwiftCastCacheType.screenPublicUrls.rawValue)
        }
    }
    var cameraPublicUrls: [String] {
        get {
            return UserDefaults.standard.stringArray(forKey: SwiftCastCacheType.cameraPublicUrls.rawValue) ?? [String]()
        }
        
        set {
            UserDefaults.standard.set(newValue, forKey: SwiftCastCacheType.cameraPublicUrls.rawValue)
        }
    }
}

enum SwiftCastCacheType: String {
    case screenPublicUrls = "com.swiftCast.cache.screenPublicUrls"
    case cameraPublicUrls = "com.swiftCast.cache.cameraPublicUrls"
}
