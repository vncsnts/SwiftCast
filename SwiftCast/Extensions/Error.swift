//
//  Error.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 8/17/23.
//

import Foundation

struct SwiftCastError: Error, LocalizedError {
    var errorDescription: String? {
        return debugDescription
    }
    
    var debugDescription: String
    
    init(_ debugDescription: String) {
        self.debugDescription = debugDescription
    }
}
