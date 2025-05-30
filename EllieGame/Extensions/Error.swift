//
//  Error.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 8/17/23.
//

import Foundation

/// Custom error type for SwiftCast errors.
struct SwiftCastError: Error, LocalizedError {
    /// A localized message describing what error occurred.
    var errorDescription: String? {
        return debugDescription
    }
    /// A debug description of the error.
    var debugDescription: String
    /// Initializes a new SwiftCastError with a debug description.
    /// - Parameter debugDescription: The debug description for the error.
    init(_ debugDescription: String) {
        self.debugDescription = debugDescription
    }
}
