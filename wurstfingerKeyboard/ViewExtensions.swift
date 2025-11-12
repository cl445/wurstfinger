//
//  ViewExtensions.swift
//  Wurstfinger
//
//  Helper extensions for SwiftUI Views
//

import SwiftUI

/// Helper extension for conditional view modifiers
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
