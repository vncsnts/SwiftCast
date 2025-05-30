//
//  Int.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 7/18/23.
//

import Foundation

/// Extension for Int to provide time conversion utilities.
extension Int {
    /// Converts seconds to nanoseconds.
    /// - Returns: The nanosecond value as UInt64.
    func convertToNanoSeconds() -> UInt64 {
        return UInt64(self * 1000000000)
    }
}
