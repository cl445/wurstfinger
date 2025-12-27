//
//  RingBuffer.swift
//  Wurstfinger
//
//  A fixed-size circular buffer for efficient O(1) appending.
//

import Foundation

struct RingBuffer<T> {
    private var array: [T?]
    private var writeIndex = 0
    private var count = 0
    
    let capacity: Int
    
    init(capacity: Int) {
        self.capacity = capacity
        self.array = Array(repeating: nil, count: capacity)
    }
    
    mutating func append(_ element: T) {
        array[writeIndex] = element
        writeIndex = (writeIndex + 1) % capacity
        if count < capacity {
            count += 1
        }
    }
    
    mutating func removeAll() {
        writeIndex = 0
        count = 0
        // No need to actually clear the array, just resetting indices is enough
        // for value types. For reference types, we might want to nil them out
        // to avoid leaks, but CGPoint is a value type.
    }
    
    var isEmpty: Bool {
        return count == 0
    }
    
    /// Returns the elements in order, from oldest to newest.
    /// This is O(N) where N is the number of elements.
    var elements: [T] {
        if count < capacity {
            return Array(array[0..<count].compactMap { $0 })
        } else {
            // Buffer is full, start from writeIndex (oldest)
            // Example: Cap 5, Write 2. [3, 4, 0, 1, 2]
            // Indices: 2, 3, 4, 0, 1
            var result = [T]()
            result.reserveCapacity(capacity)
            
            for i in 0..<capacity {
                let index = (writeIndex + i) % capacity
                if let element = array[index] {
                    result.append(element)
                }
            }
            return result
        }
    }
}
