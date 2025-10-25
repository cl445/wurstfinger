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

enum MessagEaseOutput {
    case text(String)
    case toggleShift(on: Bool)
    case toggleSymbols
    case capitalizeWord(uppercased: Bool)
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

    static func direction(for translation: CGSize, tolerance: CGFloat) -> KeyboardDirection {
        let dx = Double(translation.width)
        let dy = Double(translation.height)
        let threshold = Double(tolerance)
        let swipeLength = sqrt(dx * dx + dy * dy)

        if swipeLength <= threshold {
            return .center
        }

        let angleDir = atan2(dx, dy) / .pi * 180.0
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

    init(
        id: String = UUID().uuidString,
        center: String,
        swipeOutputs: [KeyboardDirection: MessagEaseOutput] = [:],
        swipeReturnOutputs: [KeyboardDirection: MessagEaseOutput] = [:]
    ) {
        self.id = id
        self.center = center
        self.swipeOutputs = swipeOutputs
        self.swipeReturnOutputs = swipeReturnOutputs
    }

    func output(for direction: KeyboardDirection, returning: Bool = false) -> MessagEaseOutput? {
        let map = returning ? swipeReturnOutputs : swipeOutputs
        return map[direction]
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

    static let germanDefault: KeyboardLayout = {
        let lowerRows: [[MessagEaseKey]] = [
            [
                Self.makeKey(
                    center: "a",
                    textMap: [
                        .downLeft: "$",
                        .down: "ä",
                        .downRight: "v",
                        .right: "-",
                        .upRight: "¿¡"
                    ]
                ),
                Self.makeKey(
                    center: "n",
                    textMap: [
                        .upLeft: "`",
                        .up: "^",
                        .upRight: "´",
                        .down: "l",
                        .downRight: "\\",
                        .downLeft: "/",
                        .left: "+",
                        .right: "!"
                    ]
                ),
                Self.makeKey(
                    center: "i",
                    textMap: [
                        .up: "˘",
                        .downLeft: "x",
                        .left: "?",
                        .down: "=",
                        .downRight: "€"
                    ]
                )
            ],
            [
                Self.makeKey(
                    center: "h",
                    textMap: [
                        .up: "ü",
                        .down: "ö",
                        .upLeft: "{",
                        .left: "(",
                        .right: "k",
                        .upRight: "%",
                        .downLeft: "[",
                        .downRight: "_"
                    ]
                ),
                Self.makeKey(
                    center: "d",
                    textMap: [
                        .upLeft: "q",
                        .up: "u",
                        .upRight: "p",
                        .right: "b",
                        .downRight: "j",
                        .down: "o",
                        .downLeft: "g",
                        .left: "c"
                    ]
                ),
                Self.makeKey(
                    center: "r",
                    textMap: [
                        .upLeft: "|",
                        .left: "m",
                        .downLeft: "@",
                        .right: ")",
                        .upRight: "}",
                        .downRight: "]"
                    ],
                    additionalOutputs: [
                        .up: .toggleShift(on: true),
                        .down: .toggleShift(on: false)
                    ],
                    returnOverrides: [
                        .up: .capitalizeWord(uppercased: true),
                        .down: .capitalizeWord(uppercased: false)
                    ]
                )
            ],
            [
                Self.makeKey(
                    center: "t",
                    textMap: [
                        .upLeft: "~",
                        .upRight: "y",
                        .left: "<",
                        .down: "ß",
                        .right: "*"
                    ]
                ),
                makeKey(
                    center: "e",
                    textMap: [
                        .upLeft: "\"",
                        .up: "w",
                        .upRight: "'",
                        .right: "z",
                        .downLeft: ",",
                        .down: ".",
                        .downRight: ":"
                    ]
                ),
                makeKey(
                    center: "s",
                    textMap: [
                        .upLeft: "f",
                        .up: "&",
                        .upRight: "°",
                        .downLeft: ";",
                        .left: "#",
                        .right: ">"
                    ]
                )
            ]
        ]

        let numberRows: [[MessagEaseKey]] = [
            [
                Self.makeKey(
                    center: "7",
                    textMap: [
                        .downLeft: "$",
                        .right: "-",
                        .downRight: "€"
                    ]
                ),
                Self.makeKey(
                    center: "8",
                    textMap: [
                        .upLeft: "`",
                        .up: "^",
                        .upRight: "´",
                        .right: "!",
                        .downRight: "\\",
                        .downLeft: "/",
                        .left: "+"
                    ]
                ),
                Self.makeKey(
                    center: "9",
                    textMap: [
                        .left: "?",
                        .downRight: "€",
                        .downLeft: "£",
                        .down: "="
                    ]
                )
            ],
            [
                Self.makeKey(
                    center: "4",
                    textMap: [
                        .upLeft: "{",
                        .upRight: "%",
                        .downRight: "_",
                        .downLeft: "[",
                        .left: "("
                    ]
                ),
                Self.makeKey(
                    center: "5",
                    textMap: [
                        .up: "¬"
                    ]
                ),
                Self.makeKey(
                    center: "6",
                    textMap: [
                        .upLeft: "|",
                        .upRight: "}",
                        .right: ")",
                        .downRight: "]",
                        .downLeft: "@"
                    ]
                )
            ],
            [
                Self.makeKey(
                    center: "1",
                    textMap: [
                        .upLeft: "~",
                        .left: "<",
                        .right: "*",
                        .downRight: "\t"
                    ]
                ),
                Self.makeKey(
                    center: "2",
                    textMap: [
                        .upLeft: "\"",
                        .upRight: "'",
                        .downRight: ":",
                        .down: ".",
                        .downLeft: ","
                    ]
                ),
                Self.makeKey(
                    center: "3",
                    textMap: [
                        .up: "&",
                        .upRight: "°",
                        .right: ">",
                        .downLeft: ";",
                        .left: "#"
                    ]
                )
            ],
            [
                Self.makeKey(center: "0", textMap: [:])
            ]
        ]

        let symbolRows: [[MessagEaseKey]] = lowerRows

        return KeyboardLayout(
            layers: [
                .lower: lowerRows,
                .upper: lowerRows,
                .numbers: numberRows,
                .symbols: symbolRows
            ]
        )
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
    private static func makeKey(
        center: String,
        textMap: [KeyboardDirection: String],
        additionalOutputs: [KeyboardDirection: MessagEaseOutput] = [:],
        returnOverrides: [KeyboardDirection: MessagEaseOutput] = [:]
    ) -> MessagEaseKey {
        var outputs: [KeyboardDirection: MessagEaseOutput] = additionalOutputs
        var returnOutputs: [KeyboardDirection: MessagEaseOutput] = [:]

        for (direction, text) in textMap {
            outputs[direction] = .text(text)
            if text.containsLetter {
                returnOutputs[direction] = .text(uppercaseGerman(text))
            }
        }

        for (direction, override) in returnOverrides {
            returnOutputs[direction] = override
        }

        return MessagEaseKey(center: center, swipeOutputs: outputs, swipeReturnOutputs: returnOutputs)
    }
}

private extension String {
    var containsLetter: Bool {
        rangeOfCharacter(from: .letters) != nil
    }
}

private func uppercaseGerman(_ value: String) -> String {
    value.uppercased(with: Locale(identifier: "de_DE"))
}

extension MessagEaseKey {
    func primaryLabel(for direction: KeyboardDirection) -> String? {
        label(for: direction, returning: false)
    }

    func returnLabel(for direction: KeyboardDirection) -> String? {
        label(for: direction, returning: true)
    }

    private func label(for direction: KeyboardDirection, returning: Bool) -> String? {
        guard let output = output(for: direction, returning: returning) else { return nil }
        switch output {
        case .text(let value):
            return value
        case .toggleShift(let on):
            return on ? "⇧" : "⇩"
        case .toggleSymbols:
            return "123"
        case .capitalizeWord(let uppercased):
            return uppercased ? "W↑" : "W↓"
        }
    }
}
