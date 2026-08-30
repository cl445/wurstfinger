//
//  KeyboardBackdropTests.swift
//  WurstfingerTests
//
//  Pins the nib workaround for the UIInputView leak, and its expiry date.
//

import Testing
import UIKit
@testable import WurstfingerApp

/// Guards the backdrop workaround described in
/// `KeyboardViewController.installBackdropIfNeeded()`.
///
/// The workaround exists only because a programmatically created
/// `UIInputView` never deallocates (Apple Developer Forums 807619 / 781520).
/// That is someone else's bug, so this suite is written to notice when it goes
/// away: `programmaticInputViewStillLeaks` asserts the *bug*, not the fix, and
/// turns red the day Apple ships a correction — which is the signal to delete
/// the nib, this suite, and the detour in the view controller.
@Suite(.serialized)
struct KeyboardBackdropTests {
    /// Fails once Apple fixes the leak. That failure is the point: it is the
    /// scheduled review of the workaround, not a regression in this codebase.
    ///
    /// When it fails, verify on a real device too, then replace
    /// `KeyboardViewController.makeBackdrop()` with
    /// `UIInputView(frame: .zero, inputViewStyle: .keyboard)`, delete
    /// `KeyboardBackdrop.xib` and delete this suite.
    ///
    /// Last confirmed present: 2026-08-30, Xcode 26.1 / iOS 26.6 simulator.
    @Test func programmaticInputViewStillLeaks() {
        weak var weakView: UIInputView?
        autoreleasepool {
            weakView = UIInputView(frame: .zero, inputViewStyle: .keyboard)
        }
        #expect(
            weakView != nil,
            """
            A programmatically created UIInputView now deallocates — the UIKit bug \
            behind the backdrop nib appears to be fixed. Re-verify on device, then \
            remove the workaround (see KeyboardViewController.installBackdropIfNeeded).
            """
        )
    }

    /// The reason the workaround is worth its complexity: the decoded view is
    /// released, so a backdrop no longer outlives every host app the keyboard
    /// was used in.
    @Test func nibBackdropDeallocates() {
        weak var weakView: UIInputView?
        autoreleasepool {
            weakView = KeyboardViewController.makeBackdrop()
        }
        #expect(weakView == nil, "The backdrop from the nib leaked — the workaround is not working.")
    }

    /// Decoding alone is not enough: `inputViewStyle` is `readonly`, so the nib
    /// sets it through a User Defined Runtime Attribute. Without that the
    /// backdrop would come back `.default` and quietly stop looking like the
    /// system keyboard — a silent visual regression rather than a build error.
    @Test func nibBackdropIsKeyboardStyled() {
        let backdrop = KeyboardViewController.makeBackdrop()
        #expect(backdrop.inputViewStyle == .keyboard)
    }

    /// `makeBackdrop()` falls back to the leaking initializer when the nib is
    /// missing, so that a lost resource degrades to a leak rather than to a
    /// keyboard that never appears. This asserts the fallback is not silently
    /// the everyday path — otherwise the two tests above would pass for the
    /// wrong reason.
    @Test func backdropNibIsBundled() {
        #expect(KeyboardViewController.backdropComesFromNib)
    }
}
