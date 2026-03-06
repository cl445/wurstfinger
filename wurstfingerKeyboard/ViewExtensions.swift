//
//  ViewExtensions.swift
//  Wurstfinger
//
//  Helper extensions for SwiftUI Views
//

import SwiftUI

extension NumberFormatter {
    static var decimalFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 1
        return formatter
    }
}
