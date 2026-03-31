//
//  ViewExtensions.swift
//  Wurstfinger
//
//  Helper extensions for SwiftUI Views
//

import SwiftUI

/// Helper extensions for conditional view modifiers
extension View {
    /// Conditionally applies a modifier based on a boolean condition.
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// Conditionally applies a modifier only when the optional value is non-nil.
    @ViewBuilder
    func ifLet<T, ModifiedView: View>(_ value: T?, transform: (Self, T) -> ModifiedView) -> some View {
        if let value {
            transform(self, value)
        } else {
            self
        }
    }
}

extension NumberFormatter {
    static var decimalFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 1
        return formatter
    }
}
