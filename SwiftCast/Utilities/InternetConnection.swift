//
//  InternetConnection.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 6/16/23.
//

import Foundation
import SystemConfiguration

@objcMembers
class InternetConnection: NSObject {
    static func check() -> Bool {
        guard let reachability = SCNetworkReachabilityCreateWithName(nil, "www.google.com") else { return false }
        var flags = SCNetworkReachabilityFlags()
        SCNetworkReachabilityGetFlags(reachability, &flags)
        return flags.contains(.reachable)
    }
}
