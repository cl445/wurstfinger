# Frequently Asked Questions

## Why is there a bar below the keyboard with globe and microphone buttons?

The bar at the bottom of the keyboard is the **UIKeyboardDockView**, a system-controlled area that iOS displays below all third-party keyboard extensions. It contains the globe button (to switch keyboards) and the microphone button (for dictation).

This area is managed entirely by iOS — keyboard extensions are placed *above* it and cannot remove, resize, or draw into this space. This is a fundamental limitation of the iOS keyboard extension architecture.

> *Reference: [App Extension Programming Guide: Custom Keyboard](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html) — "a custom keyboard can draw only within the primary view of its UIInputViewController object"*

## Why can't I select text with the keyboard?

**Text selection is controlled by the app**, not the keyboard. Keyboard extensions cannot programmatically select text — they can only move the cursor and read nearby text. To select text, use the standard iOS gestures (long-press, double-tap) directly in the text field.

Wurstfinger supports **Copy, Cut, and Paste** via swipe gestures on the return key (requires Full Access to be enabled).

> *Reference: [App Extension Programming Guide: Custom Keyboard](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html) — "a custom keyboard cannot select text"*
