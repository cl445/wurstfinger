# Frequently Asked Questions

## Why is there a bar below the keyboard with globe and microphone buttons?

The bar at the bottom of the keyboard is a system-controlled area that iOS displays below all third-party keyboard extensions. It sits within the device's **Safe Area** and contains the globe button (to switch keyboards) and the microphone button (for dictation).

This area is managed entirely by iOS — keyboard extensions are placed *above* it and cannot remove, resize, or draw into this space. Third-party keyboards can only draw within the primary view of their `UIInputViewController`.

> *References:*
> - *[Positioning content relative to the safe area](https://developer.apple.com/documentation/uikit/positioning-content-relative-to-the-safe-area) — Apple Developer Documentation*
> - *[Custom Keyboard Programming Guide](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html) — "a custom keyboard can draw only within the primary view of its UIInputViewController object"*

## Why can't I select text with the keyboard?

**Text selection is controlled by the app**, not the keyboard. Keyboard extensions cannot programmatically select text — they can only move the cursor and read nearby text. To select text, use the standard iOS gestures (long-press, double-tap) directly in the text field.

Wurstfinger supports **Copy, Cut, and Paste** via swipe gestures on the symbols toggle key (123/ABC): swipe up to copy, up-right to cut, and down to paste. Full Access must be enabled.

> *Reference: [Custom Keyboard Programming Guide](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html) — "a custom keyboard cannot select text"*
