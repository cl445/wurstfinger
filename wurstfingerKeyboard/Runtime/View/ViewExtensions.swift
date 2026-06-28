//
//  ViewExtensions.swift
//  Wurstfinger
//
//  Helper extensions for SwiftUI Views
//

import SwiftUI

extension View {
    /// Conditionally applies a modifier only when the optional value is non-nil.
    @ViewBuilder
    func ifLet<T>(_ value: T?, transform: (Self, T) -> some View) -> some View {
        if let value {
            transform(self, value)
        } else {
            self
        }
    }
}

extension NumberFormatter {
    /// Decimal formatter bounded to `[minimum, maximum]`. Out-of-range text is
    /// rejected (the field reverts to the last valid value) instead of being
    /// written straight to the shared store, where only the extension clamps it.
    static func decimalFormatter(minimum: Double, maximum: Double) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 1
        formatter.minimum = NSNumber(value: minimum)
        formatter.maximum = NSNumber(value: maximum)
        return formatter
    }
}
