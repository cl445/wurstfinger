//
//  KeyboardLayout.swift
//  Wurstfinger
//
//  Created by Claas Flint on 24.10.25.
//

import CoreGraphics
import Foundation

enum KeyboardLayer: Equatable {
    case lower
    case upper
    case numbers
    case symbols
}

enum NumpadStyle: String, CaseIterable {
    case phone  // 1-2-3 / 4-5-6 / 7-8-9 (default, like phone keypad)
    case classic  // 7-8-9 / 4-5-6 / 1-2-3 (like calculator)
}

enum MessagEaseOutput {
    case text(String)
    case toggleShift(on: Bool)
    case toggleSymbols
    case capitalizeWord(uppercased: Bool)
    case compose(trigger: String, display: String?)
    case cycleAccents
}

enum KeyboardDirection: CaseIterable {
    case center
    case up
    case down
    case left
    case right
    case upLeft
    case upRight
    case downLeft
    case downRight

    static func direction(for translation: CGSize, tolerance: CGFloat, aspectRatio: CGFloat = 1.0) -> KeyboardDirection {
        let dx = Double(translation.width)
        let dy = Double(translation.height)
        let threshold = Double(tolerance)

        // Compensate for non-square keys: divide horizontal movement by aspect ratio
        // If aspectRatio > 1 (wider than tall), reduce dx to make horizontal swipes harder to trigger
        // If aspectRatio < 1 (taller than wide), increase dx to make horizontal swipes easier to trigger
        let dxCorrected = dx / Double(aspectRatio)
        let swipeLength = sqrt(dxCorrected * dxCorrected + dy * dy)

        if swipeLength <= threshold {
            return .center
        }

        let angleDir = atan2(dxCorrected, dy) / .pi * 180.0
        let angle = angleDir < 0 ? 360 + angleDir : angleDir

        switch angle {
        case 22.5...67.5:
            return .downRight
        case 67.5...112.5:
            return .right
        case 112.5...157.5:
            return .upRight
        case 157.5...202.5:
            return .up
        case 202.5...247.5:
            return .upLeft
        case 247.5...292.5:
            return .left
        case 292.5...337.5:
            return .downLeft
        default:
            return .down
        }
    }
}

enum KeyboardCircularDirection {
    case clockwise
    case counterclockwise
}

struct KeyboardGestureRecognizer {
    static func circularDirection(
        positions: [CGPoint],
        circleCompletionTolerance: CGFloat,
        minSwipeLength: CGFloat
    ) -> KeyboardCircularDirection? {
        guard positions.count > 2, let last = positions.last else { return nil }

        var filtered: [CGPoint] = []
        var dropping = true

        for (index, point) in positions.enumerated() {
            if dropping {
                if index == 0 { continue }
                let previous = positions[index - 1]
                if point.distance(to: last) <= previous.distance(to: last) {
                    continue
                } else {
                    dropping = false
                    filtered.append(point)
                }
            } else {
                filtered.append(point)
            }
        }

        if filtered.isEmpty {
            filtered = positions
        }

        let count = CGFloat(filtered.count)
        let summed = filtered.reduce(CGPoint.zero) { partial, point in
            CGPoint(x: partial.x + point.x, y: partial.y + point.y)
        }
        let center = CGPoint(x: summed.x / count, y: summed.y / count)

        let radii = filtered.map { $0.distance(to: center) }
        guard let maxRadius = radii.max(), let minRadius = radii.min() else { return nil }
        let minSwipeHalf = minSwipeLength / 2
        guard minRadius > minSwipeHalf else { return nil }

        let vectors = filtered.map { CGPoint(x: $0.x - center.x, y: $0.y - center.y) }
        var spannedAngle: CGFloat = 0

        for index in 1..<vectors.count {
            let a = vectors[index - 1]
            let b = vectors[index]
            let cross = a.x * b.y - a.y * b.x
            let dot = a.x * b.x + a.y * b.y
            spannedAngle += atan2(cross, dot)
        }

        let averageRadius = (minRadius + maxRadius) / 2
        let angleThreshold = 2 * .pi * (1 - circleCompletionTolerance / averageRadius)

        if spannedAngle >= angleThreshold {
            return .clockwise
        } else if spannedAngle <= -angleThreshold {
            return .counterclockwise
        } else {
            return nil
        }
    }
}

struct MessagEaseKey: Identifiable {
    let id: String
    let center: String
    let swipeOutputs: [KeyboardDirection: MessagEaseOutput]
    let swipeReturnOutputs: [KeyboardDirection: MessagEaseOutput]
    let circularOutputs: [KeyboardCircularDirection: MessagEaseOutput]

    init(
        id: String = UUID().uuidString,
        center: String,
        swipeOutputs: [KeyboardDirection: MessagEaseOutput] = [:],
        swipeReturnOutputs: [KeyboardDirection: MessagEaseOutput] = [:],
        circularOutputs: [KeyboardCircularDirection: MessagEaseOutput] = [:]
    ) {
        self.id = id
        self.center = center
        self.swipeOutputs = swipeOutputs
        self.swipeReturnOutputs = swipeReturnOutputs
        self.circularOutputs = circularOutputs
    }

    func output(for direction: KeyboardDirection, returning: Bool = false) -> MessagEaseOutput? {
        let map = returning ? swipeReturnOutputs : swipeOutputs
        return map[direction]
    }

    func circularOutput(for direction: KeyboardCircularDirection) -> MessagEaseOutput? {
        // Try requested direction first
        if let output = circularOutputs[direction] {
            return output
        }

        // Fallback to opposite direction
        let oppositeDirection: KeyboardCircularDirection = direction == .clockwise ? .counterclockwise : .clockwise
        return circularOutputs[oppositeDirection]
    }

    func character(for direction: KeyboardDirection, on layer: KeyboardLayer) -> String? {
        switch (direction, layer) {
        case (.center, .lower):
            return center.lowercased()
        case (.center, .upper):
            return center.uppercased()
        case (.center, .numbers):
            return center
        case (.center, .symbols):
            return center
        default:
            if case let .text(value)? = output(for: direction) {
                return value
            }
            return nil
        }
    }
}

struct KeyboardLayout {
    private let layers: [KeyboardLayer: [[MessagEaseKey]]]

    init(layers: [KeyboardLayer: [[MessagEaseKey]]]) {
        self.layers = layers
    }

    func rows(for layer: KeyboardLayer) -> [[MessagEaseKey]] {
        layers[layer] ?? []
    }

    /// Creates a keyboard layout for the specified language configuration
    static func layout(for config: LanguageConfig, numpadStyle: NumpadStyle = .phone) -> KeyboardLayout {
        let lowerRows = Self.createLetterRows(for: config)
        let numberRows = Self.createNumberRows(for: config, numpadStyle: numpadStyle)
        let symbolRows = lowerRows

        return KeyboardLayout(
            layers: [
                .lower: lowerRows,
                .upper: lowerRows,
                .numbers: numberRows,
                .symbols: symbolRows
            ]
        )
    }

    static let germanDefault: KeyboardLayout = {
        layout(for: .german)
    }()
}

extension CGPoint {
    func magnitude() -> CGFloat {
        sqrt(x * x + y * y)
    }

    func distance(to other: CGPoint) -> CGFloat {
        CGPoint(x: other.x - x, y: other.y - y).magnitude()
    }
}

private extension KeyboardLayout {
    private static let composeTriggers: Set<String> = [
        "¨", "'", "`", "^", "~", "°", "˘", "$", "゛", "*", "ˇ"
    ]

    /// Creates the 3x3 letter grid rows using the language configuration
    private static func createLetterRows(for config: LanguageConfig) -> [[MessagEaseKey]] {
        let centers = config.centerCharacters
        guard centers.count == 3 else {
            fatalError("LanguageConfig must have exactly 3 rows")
        }

        return [
            // Row 0
            [
                Self.makeKey(
                    center: centers[0][0],
                    locale: config.locale,
                    textMap: [
                        .right: "-",
                        .downRight: config.specialCharacters["0_0_downRight"] ?? "v",
                        .down: config.specialCharacters["0_0_down"] ?? "",
                        .downLeft: "$"
                    ],
                    additionalOutputs: [
                        .upLeft: .cycleAccents
                    ],
                    returnOverrides: [
                        .upLeft: .cycleAccents,
                        .right: .text("÷"),
                        .downRight: .text((config.specialCharacters["0_0_downRight"] ?? "v").uppercased(with: config.locale)),
                        .down: .text((config.specialCharacters["0_0_down"] ?? "").uppercased(with: config.locale)),
                        .downLeft: .text("¥")
                    ]
                ),
                Self.makeKey(
                    center: centers[0][1],
                    locale: config.locale,
                    textMap: [
                        .right: "!",
                        .downRight: "\\",
                        .down: config.specialCharacters["0_1_down"] ?? "l",
                        .downLeft: "/",
                        .left: "+"
                    ],
                    composeMap: [
                        .upLeft: (display: "`", trigger: "`"),
                        .up: (display: "^", trigger: "^"),
                        .upRight: (display: "´", trigger: "'")
                    ],
                    returnOverrides: [
                        .upLeft: .text("'"),
                        .up: .text("ˆ"),
                        .upRight: .text("'"),
                        .right: .text("¡"),
                        .downRight: .text("—"),
                        .down: .text((config.specialCharacters["0_1_down"] ?? "l").uppercased(with: config.locale)),
                        .downLeft: .text("–"),
                        .left: .text("×")
                    ]
                ),
                Self.makeKey(
                    center: centers[0][2],
                    locale: config.locale,
                    textMap: [
                        .upRight: "\n",
                        .downRight: "€",
                        .down: "=",
                        .downLeft: "x",
                        .left: "?"
                    ],
                    returnOverrides: [
                        .upRight: .text("\n"),
                        .downRight: .text("£"),
                        .down: .text("±"),
                        .downLeft: .text("X"),
                        .left: .text("¿")
                    ]
                )
            ],
            // Row 1
            [
                Self.makeKey(
                    center: centers[1][0],
                    locale: config.locale,
                    textMap: [
                        .upLeft: "{",
                        .up: config.specialCharacters["1_0_up"] ?? "",
                        .upRight: "%",
                        .right: config.specialCharacters["1_0_right"] ?? "k",
                        .downRight: "_",
                        .down: config.specialCharacters["1_0_down"] ?? "",
                        .downLeft: "[",
                        .left: "("
                    ],
                    returnOverrides: [
                        .upLeft: .text("}"),
                        .up: .text((config.specialCharacters["1_0_up"] ?? "u").uppercased(with: config.locale)),
                        .upRight: .text("‰"),
                        .right: .text("K"),
                        .downRight: .text("¬"),
                        .down: .text((config.specialCharacters["1_0_down"] ?? "o").uppercased(with: config.locale)),
                        .downLeft: .text("]"),
                        .left: .text(")")
                    ]
                ),
                Self.makeKey(
                    center: centers[1][1],
                    locale: config.locale,
                    textMap: [
                        .upLeft: config.specialCharacters["1_1_upLeft"] ?? "q",
                        .up: config.specialCharacters["1_1_up"] ?? "u",
                        .upRight: config.specialCharacters["1_1_upRight"] ?? "p",
                        .right: config.specialCharacters["1_1_right"] ?? "b",
                        .downRight: config.specialCharacters["1_1_downRight"] ?? "j",
                        .down: config.specialCharacters["1_1_down"] ?? "d",
                        .downLeft: config.specialCharacters["1_1_downLeft"] ?? "g",
                        .left: config.specialCharacters["1_1_left"] ?? "c"
                    ],
                    returnOverrides: [
                        .upLeft: .text("Q"),
                        .up: .text("U"),
                        .upRight: .text("P"),
                        .right: .text("B"),
                        .downRight: .text("J"),
                        .down: .text((config.specialCharacters["1_1_down"] ?? "o").uppercased(with: config.locale)),
                        .downLeft: .text("G"),
                        .left: .text("C")
                    ]
                ),
                Self.makeKey(
                    center: centers[1][2],
                    locale: config.locale,
                    textMap: [
                        .upLeft: "|",
                        .upRight: "}",
                        .right: ")",
                        .downRight: "]",
                        .downLeft: "@",
                        .left: config.specialCharacters["1_2_left"] ?? "m"
                    ],
                    additionalOutputs: [
                        .up: .toggleShift(on: true),
                        .down: .toggleShift(on: false)
                    ],
                    returnOverrides: [
                        .upLeft: .text("¶"),
                        .up: .capitalizeWord(uppercased: true),
                        .upRight: .text("{"),
                        .right: .text("("),
                        .downRight: .text("["),
                        .downLeft: .text("ª"),
                        .left: .text("M")
                    ]
                )
            ],
            // Row 2
            [
                Self.makeKey(
                    center: centers[2][0],
                    locale: config.locale,
                    textMap: [
                        .upLeft: "~",
                        .up: config.specialCharacters["2_0_up"] ?? "",
                        .upRight: config.specialCharacters["2_0_upRight"] ?? "y",
                        .right: "*",
                        .downRight: "\t",
                        .down: config.specialCharacters["2_0_down"] ?? "",
                        .left: "<"
                    ],
                    composeMap: [
                        .up: (display: "¨", trigger: "¨")
                    ],
                    returnOverrides: [
                        .upLeft: .text("˜"),
                        .up: .text("˝"),
                        .upRight: .text("Y"),
                        .right: .text("†"),
                        .downRight: .text("\t"),
                        .down: .text((config.specialCharacters["2_0_down"] ?? "").uppercased(with: config.locale)),
                        .left: .text("‹")
                    ]
                ),
                Self.makeKey(
                    center: centers[2][1],
                    locale: config.locale,
                    textMap: [
                        .upLeft: "\"",
                        .up: config.specialCharacters["2_1_up"] ?? "w",
                        .right: config.specialCharacters["2_1_right"] ?? "z",
                        .downRight: ":",
                        .down: ".",
                        .downLeft: ","
                    ],
                    returnOverrides: [
                        .upLeft: .text("\u{201C}"),
                        .up: .text("W"),
                        .upRight: .text("\u{201D}"),
                        .right: .text("Z"),
                        .downRight: .text("„"),
                        .down: .text("…"),
                        .downLeft: .text(",")
                    ]
                ),
                Self.makeKey(
                    center: centers[2][2],
                    locale: config.locale,
                    textMap: [
                        .upLeft: config.specialCharacters["2_2_upLeft"] ?? "f",
                        .up: "&",
                        .upRight: "°",
                        .right: ">",
                        .downRight: " ",
                        .downLeft: ";",
                        .left: "#"
                    ],
                    returnOverrides: [
                        .upLeft: .text("F"),
                        .up: .text("§"),
                        .upRight: .text("º"),
                        .right: .text("›"),
                        .downRight: .text(" "),
                        .downLeft: .text(";"),
                        .left: .text("£")
                    ]
                )
            ]
        ]
    }

    /// Creates the number layer rows using the language configuration
    private static func createNumberRows(for config: LanguageConfig, numpadStyle: NumpadStyle = .phone) -> [[MessagEaseKey]] {
        let classicRows = [
            [
                Self.makeKey(
                    center: "7",
                    locale: config.locale,
                    textMap: [
                        .left: "≤",
                        .right: "-",
                        .downLeft: "$"
                    ],
                    additionalOutputs: [
                        .upLeft: .cycleAccents
                    ],
                    returnOverrides: [
                        .upLeft: .cycleAccents,
                        .right: .text("÷"),
                        .downLeft: .text("¥")
                    ],
                    circularOverrides: [
                        .clockwise: .text("∫"),
                        .counterclockwise: .text("∫")
                    ]
                ),
                Self.makeKey(
                    center: "8",
                    locale: config.locale,
                    textMap: [
                        .right: "!",
                        .downRight: "\\",
                        .downLeft: "/",
                        .left: "+"
                    ],
                    composeMap: [
                        .upLeft: (display: "`", trigger: "`"),
                        .up: (display: "^", trigger: "^"),
                        .upRight: (display: "´", trigger: "'")
                    ],
                    returnOverrides: [
                        .upLeft: .text("'"),
                        .up: .text("ˆ"),
                        .upRight: .text("'"),
                        .right: .text("¡"),
                        .downRight: .text("—"),
                        .downLeft: .text("–"),
                        .left: .text("×")
                    ],
                    circularOverrides: [
                        .clockwise: .text("∏"),
                        .counterclockwise: .text("∏")
                    ]
                ),
                Self.makeKey(
                    center: "9",
                    locale: config.locale,
                    textMap: [
                        .upRight: "\n",
                        .right: "≥",
                        .downRight: "€",
                        .down: "=",
                        .left: "?"
                    ],
                    returnOverrides: [
                        .upRight: .text("\n"),
                        .downRight: .text("£"),
                        .down: .text("±"),
                        .left: .text("¿")
                    ],
                    circularOverrides: [
                        .clockwise: .text("∑"),
                        .counterclockwise: .text("∑")
                    ]
                )
            ],
            [
                Self.makeKey(
                    center: "4",
                    locale: config.locale,
                    textMap: [
                        .upLeft: "{",
                        .upRight: "%",
                        .downRight: "_",
                        .downLeft: "[",
                        .left: "("
                    ],
                    returnOverrides: [
                        .upLeft: .text("}"),
                        .upRight: .text("‰"),
                        .downRight: .text("¬"),
                        .downLeft: .text("]"),
                        .left: .text(")")
                    ],
                    circularOverrides: [
                        .clockwise: .text("¼"),
                        .counterclockwise: .text("¼")
                    ]
                ),
                Self.makeKey(
                    center: "5",
                    locale: config.locale,
                    textMap: [:],
                    circularOverrides: [
                        .clockwise: .text("a"),
                        .counterclockwise: .text("a")
                    ]
                ),
                Self.makeKey(
                    center: "6",
                    locale: config.locale,
                    textMap: [
                        .upLeft: "|",
                        .upRight: "}",
                        .right: ")",
                        .downRight: "]",
                        .downLeft: "@"
                    ],
                    additionalOutputs: [
                        .up: .toggleShift(on: true),
                        .down: .toggleShift(on: false)
                    ],
                    returnOverrides: [
                        .upLeft: .text("¶"),
                        .up: .capitalizeWord(uppercased: true),
                        .upRight: .text("{"),
                        .right: .text("("),
                        .downRight: .text("["),
                        .downLeft: .text("ª")
                    ],
                    circularOverrides: [
                        .clockwise: .text("ⁿ"),
                        .counterclockwise: .text("ⁿ")
                    ]
                )
            ],
            [
                Self.makeKey(
                    center: "1",
                    locale: config.locale,
                    textMap: [
                        .upLeft: "~",
                        .right: "*",
                        .downRight: "\t",
                        .left: "<"
                    ],
                    composeMap: [
                        .up: (display: "¨", trigger: "¨")
                    ],
                    returnOverrides: [
                        .upLeft: .text("˜"),
                        .up: .text("˝"),
                        .right: .text("†"),
                        .downRight: .text("\t"),
                        .left: .text("‹")
                    ],
                    circularOverrides: [
                        .clockwise: .text("¹"),
                        .counterclockwise: .text("¹")
                    ]
                ),
                Self.makeKey(
                    center: "2",
                    locale: config.locale,
                    textMap: [
                        .upLeft: "\"",
                        .downRight: ":",
                        .down: ".",
                        .downLeft: ","
                    ],
                    returnOverrides: [
                        .upLeft: .text("\u{201C}"),
                        .upRight: .text("\u{201D}"),
                        .downRight: .text("„"),
                        .down: .text("…"),
                        .downLeft: .text(",")
                    ],
                    circularOverrides: [
                        .clockwise: .text("²"),
                        .counterclockwise: .text("²")
                    ]
                ),
                Self.makeKey(
                    center: "3",
                    locale: config.locale,
                    textMap: [
                        .up: "&",
                        .upRight: "°",
                        .right: ">",
                        .downRight: " ",
                        .downLeft: ";",
                        .left: "#"
                    ],
                    returnOverrides: [
                        .up: .text("§"),
                        .upRight: .text("º"),
                        .right: .text("›"),
                        .downRight: .text(" "),
                        .downLeft: .text(";"),
                        .left: .text("£")
                    ],
                    circularOverrides: [
                        .clockwise: .text("³"),
                        .counterclockwise: .text("³")
                    ]
                )
            ],
            [
                Self.makeKey(
                    center: "0",
                    locale: config.locale,
                    textMap: [:]
                )
            ]
        ]

        // For phone layout, swap center numbers and circular gestures while keeping swipe gestures in their physical positions
        if numpadStyle == .phone {
            // Map from classic center to phone center at each position
            // Position (0,0): 7 → 1 (with circular from 1), Position (0,1): 8 → 2 (with circular from 2), Position (0,2): 9 → 3 (with circular from 3)
            // Position (1,0): 4 → 4, Position (1,1): 5 → 5, Position (1,2): 6 → 6 (unchanged)
            // Position (2,0): 1 → 7 (with circular from 7), Position (2,1): 2 → 8 (with circular from 8), Position (2,2): 3 → 9 (with circular from 9)
            return [
                // Row 0: swap 7→1, 8→2, 9→3 (with circular gestures from row 2)
                [
                    Self.swapCenterAndCircular(classicRows[0][0], newCenter: "1", newCircular: classicRows[2][0].circularOutputs),
                    Self.swapCenterAndCircular(classicRows[0][1], newCenter: "2", newCircular: classicRows[2][1].circularOutputs),
                    Self.swapCenterAndCircular(classicRows[0][2], newCenter: "3", newCircular: classicRows[2][2].circularOutputs)
                ],
                // Row 1: keep 4, 5, 6 unchanged
                classicRows[1],
                // Row 2: swap 1→7, 2→8, 3→9 (with circular gestures from row 0)
                [
                    Self.swapCenterAndCircular(classicRows[2][0], newCenter: "7", newCircular: classicRows[0][0].circularOutputs),
                    Self.swapCenterAndCircular(classicRows[2][1], newCenter: "8", newCircular: classicRows[0][1].circularOutputs),
                    Self.swapCenterAndCircular(classicRows[2][2], newCenter: "9", newCircular: classicRows[0][2].circularOutputs)
                ],
                // Row 3: 0 unchanged
                classicRows[3]
            ]
        } else {
            // Classic calculator layout: 7-8-9 / 4-5-6 / 1-2-3 / 0
            return classicRows
        }
    }

    /// Helper to create a new key with swapped center and circular gestures, keeping swipe outputs at physical position
    private static func swapCenterAndCircular(_ key: MessagEaseKey, newCenter: String, newCircular: [KeyboardCircularDirection: MessagEaseOutput]) -> MessagEaseKey {
        return MessagEaseKey(
            center: newCenter,
            swipeOutputs: key.swipeOutputs,
            swipeReturnOutputs: key.swipeReturnOutputs,
            circularOutputs: newCircular
        )
    }

    private static func makeKey(
        center: String,
        locale: Locale,
        textMap: [KeyboardDirection: String],
        composeMap: [KeyboardDirection: (display: String?, trigger: String)] = [:],
        additionalOutputs: [KeyboardDirection: MessagEaseOutput] = [:],
        returnOverrides: [KeyboardDirection: MessagEaseOutput] = [:],
        circularOverrides: [KeyboardCircularDirection: MessagEaseOutput] = [:]
    ) -> MessagEaseKey {
        var outputs: [KeyboardDirection: MessagEaseOutput] = additionalOutputs
        var returnOutputs: [KeyboardDirection: MessagEaseOutput] = [:]
        var circularOutputs: [KeyboardCircularDirection: MessagEaseOutput] = circularOverrides

        // Default circular gesture: uppercase for letters
        if circularOutputs.isEmpty && center.containsLetter {
            let uppercased = center.uppercased(with: locale)
            circularOutputs[.clockwise] = .text(uppercased)
            circularOutputs[.counterclockwise] = .text(uppercased)
        }

        for (direction, compose) in composeMap {
            let output = MessagEaseOutput.compose(trigger: compose.trigger, display: compose.display)
            outputs[direction] = output
            returnOutputs[direction] = output
        }

        for (direction, text) in textMap {
            if composeMap[direction] != nil {
                continue
            }
            if composeTriggers.contains(text) {
                let output = MessagEaseOutput.compose(trigger: text, display: text)
                outputs[direction] = output
                returnOutputs[direction] = output
            } else {
                outputs[direction] = .text(text)
                // No automatic uppercase fallback - only explicit returnOverrides
            }
        }

        for (direction, override) in returnOverrides {
            returnOutputs[direction] = override
        }

        return MessagEaseKey(
            center: center,
            swipeOutputs: outputs,
            swipeReturnOutputs: returnOutputs,
            circularOutputs: circularOutputs
        )
    }
}

private extension String {
    var containsLetter: Bool {
        rangeOfCharacter(from: .letters) != nil
    }
}

extension MessagEaseKey {
    func primaryLabel(for direction: KeyboardDirection, isCapsLock: Bool = false) -> String? {
        label(for: direction, returning: false, isCapsLock: isCapsLock)
    }

    func returnLabel(for direction: KeyboardDirection, isCapsLock: Bool = false) -> String? {
        label(for: direction, returning: true, isCapsLock: isCapsLock)
    }

    private func label(for direction: KeyboardDirection, returning: Bool, isCapsLock: Bool) -> String? {
        guard let output = output(for: direction, returning: returning) else { return nil }
        switch output {
        case .text(let value):
            // Special labels for whitespace characters
            if value == "\t" {
                return "⇥"
            }
            return value
        case .toggleShift(let on):
            if on && isCapsLock {
                return "⇪"  // Caps-lock icon
            }
            return on ? "⇧" : "⇩"
        case .toggleSymbols:
            return "123"
        case .capitalizeWord(let uppercased):
            return uppercased ? "W↑" : "W↓"
        case .compose(let trigger, let display):
            return display ?? trigger
        case .cycleAccents:
            return "\u{1F152}"
        }
    }
}

// MARK: - Keyboard Constants

enum KeyboardConstants {
    // MARK: - Key Dimensions
    enum KeyDimensions {
        static let height: CGFloat = 54
        static let minWidth: CGFloat = 44
        static let cornerRadius: CGFloat = 8
        static let defaultAspectRatio: CGFloat = 1.5
        static let totalRows: Int = 4
    }

    // MARK: - Font Sizes
    enum FontSizes {
        static let keyLabel: CGFloat = 22
        static let defaultLabel: CGFloat = 18
        static let utilityLabel: CGFloat = 22
        static let hintEmphasis: CGFloat = 11
        static let hintNormal: CGFloat = 10

        // Main label scaling
        static let mainLabelBaseSize: CGFloat = 26
        static let mainLabelReferenceHeight: CGFloat = 54
        static let mainLabelMinSize: CGFloat = 20
        static let mainLabelMaxSize: CGFloat = 34

        // Hint label scaling
        static let hintBaseSize: CGFloat = 14
        static let hintReferenceHeight: CGFloat = 54
        static let hintMinSize: CGFloat = 10
        static let hintMaxSize: CGFloat = 22
        static let hintEmphasisMultiplier: CGFloat = 1.1
        static let hintReferenceFontSize: CGFloat = 10

        // Hint padding
        static let hintBaseHorizontalPadding: CGFloat = 2
        static let hintBaseVerticalPadding: CGFloat = 0.5
    }

    // MARK: - Layout Spacing
    enum Layout {
        static let gridHorizontalSpacing: CGFloat = 5
        static let gridVerticalSpacing: CGFloat = 5
        static let horizontalPadding: CGFloat = 12
        /// Top padding - minimal since keyboard sits directly below text input
        static let verticalPaddingTop: CGFloat = 4
        /// Bottom padding - accounts for home indicator safe area
        static let verticalPaddingBottom: CGFloat = 10
        static let hintMargin: CGFloat = 10
        static let hintMarginReturning: CGFloat = 22
    }

    // MARK: - Gesture Recognition
    enum Gesture {
        static let minSwipeLength: CGFloat = 30
        static let circleCompletionTolerance: CGFloat = 16
        static let finalOffsetMultiplier: CGFloat = 0.71
        static let positionBufferSize: Int = 60
    }

    // MARK: - Space Key Gestures
    enum SpaceGestures {
        static let dragActivationThreshold: CGFloat = 8
        static let selectionActivationThreshold: CGFloat = 24
        static let dragStep: CGFloat = 14
    }

    // MARK: - Delete Key Gestures
    enum DeleteGestures {
        static let dragActivationThreshold: CGFloat = 8
        static let slideActivationThreshold: CGFloat = 28
        static let wordSwipeThreshold: CGFloat = 40
        static let verticalTolerance: CGFloat = 28
        static let repeatInterval: TimeInterval = 0.08
        static let repeatDelay: TimeInterval = 0.35
    }

    // MARK: - Preview Settings
    enum Preview {
        static let minHeight: CGFloat = 100
        static let maxHeight: CGFloat = 400
    }

    // MARK: - Keyboard Calculations
    enum Calculations {
        /// Calculates the adjusted key height based on aspect ratio
        static func keyHeight(aspectRatio: CGFloat) -> CGFloat {
            KeyDimensions.height * (KeyDimensions.defaultAspectRatio / aspectRatio)
        }

        /// Calculates the total keyboard base height (without scaling)
        static func baseHeight(aspectRatio: CGFloat) -> CGFloat {
            let keyHeight = keyHeight(aspectRatio: aspectRatio)
            return (keyHeight * CGFloat(KeyDimensions.totalRows)) +
                   (Layout.gridVerticalSpacing * CGFloat(KeyDimensions.totalRows - 1)) +
                   Layout.verticalPaddingTop + Layout.verticalPaddingBottom
        }
    }
}

