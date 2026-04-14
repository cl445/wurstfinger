//
//  ArrangementContext.swift
//  Wurstfinger
//
//  Determines which arrangement to use for which context.
//

import Foundation

/// Determines which arrangement to use for which context.
enum ArrangementContext: String, Codable, CaseIterable {
    case portrait // Portrait, utility right (default)
    case portraitUtilityLeft // Portrait, utility left
    case landscape // Landscape
    case landscapeUtilityLeft // Landscape, utility left
    // Extensible: .tablet, .oneHanded, .split, ...
}
