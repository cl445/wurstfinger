//
//  KeyboardButtonComponents.swift
//  Wurstfinger
//
//  Shared components for keyboard button rendering and configuration
//

import SwiftUI

/// Touch area extension beyond each key's visual bounds.
/// Must be at least as large as the biggest padding/spacing gap so that
/// every pixel on the keyboard surface is covered by at least one key.
enum KeyboardTouchArea {
    static let padding: CGFloat = max(
        KeyboardConstants.Layout.horizontalPadding,
        KeyboardConstants.Layout.verticalPaddingBottom,
        KeyboardConstants.Layout.gridHorizontalSpacing / 2 + 1,
        KeyboardConstants.Layout.gridVerticalSpacing / 2 + 1
    )
}
