//
//  ViewExtensions.swift
//  Wurstfinger
//
//  Helper extensions for the settings views.
//

import Foundation

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
