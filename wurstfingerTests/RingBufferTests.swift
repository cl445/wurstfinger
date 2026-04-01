//
//  RingBufferTests.swift
//  WurstfingerTests
//
//  Tests for RingBuffer<T> circular buffer implementation.
//

import Foundation
import Testing
@testable import WurstfingerApp

struct RingBufferTests {
    // MARK: - Basic Operations

    @Test func emptyBufferIsEmpty() {
        let buffer = RingBuffer<Int>(capacity: 5)
        #expect(buffer.isEmpty)
        #expect(buffer.elements == [])
    }

    @Test func appendWithinCapacity() {
        var buffer = RingBuffer<Int>(capacity: 5)
        buffer.append(1)
        buffer.append(2)
        buffer.append(3)
        #expect(!buffer.isEmpty)
        #expect(buffer.elements == [1, 2, 3])
    }

    @Test func appendExactlyAtCapacity() {
        var buffer = RingBuffer<Int>(capacity: 3)
        buffer.append(10)
        buffer.append(20)
        buffer.append(30)
        #expect(buffer.elements == [10, 20, 30])
    }

    @Test func appendOverCapacityOverwritesOldest() {
        var buffer = RingBuffer<Int>(capacity: 3)
        buffer.append(1)
        buffer.append(2)
        buffer.append(3)
        buffer.append(4) // Overwrites 1
        #expect(buffer.elements == [2, 3, 4])
    }

    @Test func appendWellOverCapacity() {
        var buffer = RingBuffer<Int>(capacity: 3)
        for i in 1 ... 10 {
            buffer.append(i)
        }
        // Should contain the last 3 elements: 8, 9, 10
        #expect(buffer.elements == [8, 9, 10])
    }

    // MARK: - Element Ordering

    @Test func elementsOrderIsOldestToNewest() {
        var buffer = RingBuffer<Int>(capacity: 4)
        buffer.append(10)
        buffer.append(20)
        buffer.append(30)
        buffer.append(40)
        buffer.append(50) // Overwrites 10
        buffer.append(60) // Overwrites 20
        #expect(buffer.elements == [30, 40, 50, 60])
    }

    // MARK: - removeAll

    @Test func removeAllClearsBuffer() {
        var buffer = RingBuffer<Int>(capacity: 5)
        buffer.append(1)
        buffer.append(2)
        buffer.append(3)
        buffer.removeAll()
        #expect(buffer.isEmpty)
        #expect(buffer.elements == [])
    }

    @Test func appendAfterRemoveAll() {
        var buffer = RingBuffer<Int>(capacity: 3)
        buffer.append(1)
        buffer.append(2)
        buffer.removeAll()
        buffer.append(10)
        buffer.append(20)
        #expect(buffer.elements == [10, 20])
    }

    // MARK: - Edge Cases

    @Test func capacityOfOne() {
        var buffer = RingBuffer<Int>(capacity: 1)
        #expect(buffer.isEmpty)

        buffer.append(42)
        #expect(buffer.elements == [42])

        buffer.append(99)
        #expect(buffer.elements == [99])
    }

    @Test func worksWithCGPoints() {
        var buffer = RingBuffer<CGPoint>(capacity: 3)
        buffer.append(CGPoint(x: 1, y: 2))
        buffer.append(CGPoint(x: 3, y: 4))
        let elements = buffer.elements
        #expect(elements.count == 2)
        #expect(elements[0] == CGPoint(x: 1, y: 2))
        #expect(elements[1] == CGPoint(x: 3, y: 4))
    }
}
