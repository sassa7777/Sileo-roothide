//  Created by Andromeda on 07/09/2021.
//  Copyright © 2021 Amy While. All rights reserved.
//

import Foundation

// MARK: SafeArray
final public class SafeArray<Element> {
    private var array: [Element]
    private let queue: DispatchQueue
    private let key: DispatchSpecificKey<Int>
    private let context: Int
    
    public var isOnQueue: Bool {
        DispatchQueue.getSpecific(key: key) == context
    }
    
    public init(_ array: [Element] = [], queue: DispatchQueue, key: DispatchSpecificKey<Int>, context: Int) {
        self.array = array
        self.queue = queue
        self.key = key
        self.context = context
    }
    
    public subscript(index: Int) -> Element {
        get {
            if !isOnQueue {
                var result: Element?
                queue.sync { result = self.array[index] }
                return result!
            } else {
                return array[index]
            }
        }
        set {
            if !isOnQueue {
                queue.async(flags: .barrier) {
                    self.array[index] = newValue
                }
            } else {
                array[index] = newValue
            }
        }
    }
    
    public func first(where predicate: (Element) -> Bool) -> Element? {
        if !isOnQueue {
            var result: Element?
            queue.sync { result = self.array.first(where: predicate) }
            return result
        } else {
            return array.first(where: predicate)
        }
    }
    
    public func last(where predicate: (Element) -> Bool) -> Element? {
        if !isOnQueue {
            var result: Element?
            queue.sync { result = self.array.last(where: predicate) }
            return result
        } else {
            return array.last(where: predicate)
        }
    }
    
    public func firstIndex(where predicate: (Element) -> Bool) -> Int? {
        if !isOnQueue {
            var result: Int?
            queue.sync { result = self.array.firstIndex(where: predicate) }
            return result
        } else {
            return array.firstIndex(where: predicate)
        }
    }
    
    public func lastIndex(where predicate: (Element) -> Bool) -> Int? {
        if !isOnQueue {
            var result: Int?
            queue.sync { result = self.array.lastIndex(where: predicate) }
            return result
        } else {
            return array.lastIndex(where: predicate)
        }
    }
    
    public var count: Int {
        if !isOnQueue {
            var result = 0
            queue.sync { result = self.array.count }
            return result
        }
        return array.count
    }
    
    public var isEmpty: Bool {
        if !isOnQueue {
            var result = false
            queue.sync { result = self.array.isEmpty }
            return result
        }
        return array.isEmpty
    }
    
    public var raw: [Element] {
        if !isOnQueue {
            var result = [Element]()
            queue.sync { result = self.array }
            return result
        }
        return array
    }
    
    public func contains(where element: (Element) -> Bool) -> Bool {
        if !isOnQueue {
            var result = false
            queue.sync { result = self.array.contains(where: element) }
            return result
        }
        return array.contains(where: element)
    }
    
    public func setTo(_ element: [Element]) {
        if !isOnQueue {
            queue.async(flags: .barrier) {
                self.array = element
            }
        } else {
            self.array = element
        }
    }
    
    public func enumerated() -> EnumeratedSequence<[Element]> {
        raw.enumerated()
    }
    
    public var first: Element? {
        if !isOnQueue {
            var first: Element? = nil
            queue.sync { first = self.array.first }
            return first
        } else {
            return array.first
        }
    }
    
    public var last: Element? {
        if !isOnQueue {
            var last: Element? = nil
            queue.sync { last = self.array.last }
            return last
        } else {
            return array.last
        }
    }
    
    public func append(_ element: Element) {
        if !isOnQueue {
            queue.async(flags: .barrier) {
                self.array.append(element)
            }
        } else {
            self.array.append(element)
        }
    }
    
    public func appendGroup(_ element: [Element]) {
        if !isOnQueue {
            queue.async(flags: .barrier) {
                self.array += element
            }
        } else {
            self.array += element
        }
    }
    
    public func removeAll() {
        if !isOnQueue {
            queue.async(flags: .barrier) {
                self.array.removeAll()
            }
        } else {
            self.array.removeAll()
        }
    }
    
    public func remove(at index: Int)  {
        if !isOnQueue {
            queue.async(flags: .barrier) { self.array.remove(at: index) }
        } else {
            array.remove(at: index)
        }
    }
    
    public func removeFirst() -> Element {
        if !isOnQueue {
            var element: Element?
            queue.sync { element = self.array.removeFirst() }
            return element!
        } else {
            return self.array.removeFirst()
        }
    }
    
    public func removeAll(_ element: @escaping (Element) -> Bool) {
        if !isOnQueue {
            queue.async(flags: .barrier) {
                while let index = self.array.firstIndex(where: element) {
                    self.array.remove(at: index)
                }
            }
        } else {
            while let index = self.array.firstIndex(where: element) {
                self.array.remove(at: index)
            }
        }
    }
    
    public func map<ElementOfResult>(_ transform: @escaping (Element) -> ElementOfResult) -> [ElementOfResult] {
        if !isOnQueue {
            var result = [ElementOfResult]()
            queue.sync { result = self.array.map(transform) }
            return result
        } else {
            return array.map(transform)
        }
    }

    public func removeAll(where shouldBeRemoved: (Element) throws -> Bool) rethrows {
        if !isOnQueue {
            queue.sync { [self] in try? array.removeAll(where: shouldBeRemoved) }
        } else {
            try array.removeAll(where: shouldBeRemoved)
        }
    }
    
    public func filter(_ isIncluded: (Element) throws -> Bool) rethrows -> [Element] {
        try raw.filter(isIncluded)
    }
}

public extension SafeArray where Element: Equatable {
    func contains(_ element: Element) -> Bool {
        if !isOnQueue {
            var result = false
            queue.sync { result = self.array.contains(element) }
            return result
        }
        return self.array.contains(element)
    }
}

// MARK: SafeContiguousArray
final public class SafeContiguousArray<Element> {
    private var array: ContiguousArray<Element>
    private let queue: DispatchQueue
    private let key: DispatchSpecificKey<Int>
    private let context: Int
    
    public var isOnQueue: Bool {
        DispatchQueue.getSpecific(key: key) == context
    }
    
    public init(_ array: ContiguousArray<Element> = [], queue: DispatchQueue, key: DispatchSpecificKey<Int>, context: Int) {
        self.array = array
        self.queue = queue
        self.key = key
        self.context = context
    }
    
    public subscript(index: Int) -> Element {
        get {
            if !isOnQueue {
                var result: Element?
                queue.sync { result = self.array[index] }
                return result!
            } else {
                return array[index]
            }
        }
        set {
            if !isOnQueue {
                queue.async(flags: .barrier) {
                    self.array[index] = newValue
                }
            } else {
                array[index] = newValue
            }
        }
    }
    
    public var count: Int {
        if !isOnQueue {
            var result = 0
            queue.sync { result = self.array.count }
            return result
        }
        return array.count
    }
    
    public var isEmpty: Bool {
        if !isOnQueue {
            var result = false
            queue.sync { result = self.array.isEmpty }
            return result
        }
        return array.isEmpty
    }
    
    public var raw: ContiguousArray<Element> {
        if !isOnQueue {
            var result = ContiguousArray<Element>()
            queue.sync { result = self.array }
            return result
        }
        return array
    }
    
    public func contains(where element: (Element) -> Bool) -> Bool {
        if !isOnQueue {
            var result = false
            queue.sync { result = self.array.contains(where: element) }
            return result
        }
        return array.contains(where: element)
    }
    
    public func first(where predicate: (Element) -> Bool) -> Element? {
        if !isOnQueue {
            var result: Element?
            queue.sync { result = self.array.first(where: predicate) }
            return result
        } else {
            return array.first(where: predicate)
        }
    }
    
    public func last(where predicate: (Element) -> Bool) -> Element? {
        if !isOnQueue {
            var result: Element?
            queue.sync { result = self.array.last(where: predicate) }
            return result
        } else {
            return array.last(where: predicate)
        }
    }
    
    public func firstIndex(where predicate: (Element) -> Bool) -> Int? {
        if !isOnQueue {
            var result: Int?
            queue.sync { result = self.array.firstIndex(where: predicate) }
            return result
        } else {
            return array.firstIndex(where: predicate)
        }
    }
    
    public func lastIndex(where predicate: (Element) -> Bool) -> Int? {
        if !isOnQueue {
            var result: Int?
            queue.sync { result = self.array.lastIndex(where: predicate) }
            return result
        } else {
            return array.lastIndex(where: predicate)
        }
    }
    
    public var first: Element? {
        if !isOnQueue {
            var first: Element? = nil
            queue.sync { first = self.array.first }
            return first
        } else {
            return array.first
        }
    }
    
    public var last: Element? {
        if !isOnQueue {
            var last: Element? = nil
            queue.sync { last = self.array.last }
            return last
        } else {
            return array.last
        }
    }
    
    public func setTo(_ element: ContiguousArray<Element>) {
        if !isOnQueue {
            queue.async(flags: .barrier) {
                self.array = element
            }
        } else {
            self.array = element
        }
    }
    
    public func enumerated() -> EnumeratedSequence<ContiguousArray<Element>> {
        raw.enumerated()
    }
    
    public func setTo(_ element: [Element]) {
        if !isOnQueue {
            queue.async(flags: .barrier) {
                self.array = ContiguousArray<Element>(element)
            }
        } else {
            self.array = ContiguousArray<Element>(element)
        }
    }
    
    public func append(_ element: Element) {
        if !isOnQueue {
            queue.async(flags: .barrier) {
                self.array.append(element)
            }
        } else {
            self.array.append(element)
        }
    }
    
    public func removeAll() {
        if !isOnQueue {
            queue.async(flags: .barrier) {
                self.array.removeAll()
            }
        } else {
            self.array.removeAll()
        }
    }
    
    public func removeAll(_ element: @escaping (Element) -> Bool) {
        if !isOnQueue {
            queue.async(flags: .barrier) {
                while let index = self.array.firstIndex(where: element) {
                    self.array.remove(at: index)
                }
            }
        } else {
            while let index = self.array.firstIndex(where: element) {
                self.array.remove(at: index)
            }
        }
    }
    
    public func map<ElementOfResult>(_ transform: @escaping (Element) -> ElementOfResult) -> [ElementOfResult] {
        if !isOnQueue {
            var result = [ElementOfResult]()
            queue.sync { result = self.array.map(transform) }
            return result
        } else {
            return array.map(transform)
        }
    }
    
    public func remove(at index: Int) {
        if !isOnQueue {
            queue.async(flags: .barrier) { self.array.remove(at: index) }
        } else {
            array.remove(at: index)
        }
    }
    
    public func removeAll(where shouldBeRemoved: (Element) throws -> Bool) rethrows {
        if !isOnQueue {
            queue.sync { [self] in try? array.removeAll(where: shouldBeRemoved) }
        } else {
            try array.removeAll(where: shouldBeRemoved)
        }
    }
    
    public func filter(_ isIncluded: (Element) throws -> Bool) rethrows -> ContiguousArray<Element> {
        try raw.filter(isIncluded)
    }

}

public extension SafeContiguousArray where Element: Equatable {
    func contains(_ element: Element) -> Bool {
        if !isOnQueue {
            var result = false
            queue.sync { result = self.array.contains(element) }
            return result
        }
        return self.array.contains(element)
    }
}

final public class SafeSet<Element: Hashable> {
    
    private var set: Set<Element>
    private let queue: DispatchQueue
    private let key: DispatchSpecificKey<Int>
    private let context: Int
    
    public var isOnQueue: Bool {
        DispatchQueue.getSpecific(key: key) == context
    }
    
    public init(_ set: Set<Element> = [], queue: DispatchQueue, key: DispatchSpecificKey<Int>, context: Int) {
        self.set = set
        self.queue = queue
        self.key = key
        self.context = context
    }
    
    subscript(position: Set<Element>.Index) -> Element {
        get {
            if !isOnQueue {
                var result: Element?
                queue.sync { result = self.set[position] }
                return result!
            }
            return set[position]
        }
    }
    
    public func insert(_ newMember: Element) {
        if !isOnQueue {
            queue.async(flags: .barrier) { self.set.insert(newMember) }
        } else {
            set.insert(newMember)
        }
    }
    
    public func filter(_ isIncluded: (Element) throws -> Bool) rethrows -> Set<Element> {
        if !isOnQueue {
            var result: Set<Element>?
            try queue.sync { result = try self.set.filter(isIncluded) }
            return result!
        }
        return try set.filter(isIncluded)
    }
    
    public var raw: Set<Element> {
        if !isOnQueue {
            var result = Set<Element>()
            queue.sync { result = self.set }
            return result
        }
        return set
    }
    
    public var count: Int {
        if !isOnQueue {
            var result = 0
            queue.sync { result = self.set.count }
            return result
        }
        return set.count
    }
    
    public var isEmpty: Bool {
        if !isOnQueue {
            var result = false
            queue.sync { result = self.set.isEmpty }
            return result
        }
        return set.isEmpty
    }
    
    public func contains(_ element: Element) -> Bool {
        if !isOnQueue {
            var result = false
            queue.sync { result = self.set.contains(element) }
            return result
        }
        return self.set.contains(element)
    }
    
    public func removeAll() {
        if !isOnQueue {
            queue.async(flags: .barrier) {
                self.set.removeAll()
            }
        } else {
            self.set.removeAll()
        }
    }
    
    public func formUnion<S>(_ other: S) where Element == S.Element, S : Sequence {
        if !isOnQueue {
            queue.async(flags: .barrier) {
                self.set.formUnion(other)
            }
        } else {
            self.set.formUnion(other)
        }
    }
    
    public func contains(where predicate: (Element) throws -> Bool) rethrows -> Bool {
        if !isOnQueue {
            var result = false
            try queue.sync { result = try self.set.contains(where: predicate) }
            return result
        }
        return try self.set.contains(where: predicate)
    }
    
    public func map<T>(_ transform: (Element) throws -> T) rethrows -> [T] {
        if !isOnQueue {
            var result = [T]()
            try queue.sync { result = try self.set.map(transform) }
            return result
        }
        return try self.set.map(transform)
    }
    
    public func remove(_ member: Element) {
        if !isOnQueue {
            queue.async(flags: .barrier) { self.set.remove(member) }
        } else {
            set.remove(member)
        }
    }
    
    public func remove(_ element: @escaping (Element) -> Bool) {
        if !isOnQueue {
            queue.async(flags: .barrier) {
                if let index = self.set.first(where: element) {
                    self.set.remove(index)
                }
            }
        } else {
            if let index = self.set.first(where: element) {
                self.set.remove(index)
            }
        }
    }
    
    public func setTo(_ element: Set<Element>) {
        if !isOnQueue {
            queue.async(flags: .barrier) {
                self.set = element
            }
        } else {
            self.set = element
        }
    }
    
}

// MARK: SafeDictionary
final public class SafeDictionary<Key: Hashable, Value> {
    public typealias Element = (key: Key, value: Value)
    
    // swiftlint:disable:next syntactic_sugar
    private var dict: Dictionary<Key, Value>
    private let queue: DispatchQueue
    private let key: DispatchSpecificKey<Int>
    private let context: Int
    
    public var isOnQueue: Bool {
        DispatchQueue.getSpecific(key: key) == context
    }
    
    // swiftlint:disable:next syntactic_sugar
    public init(_ dict: Dictionary<Key, Value> = [:], queue: DispatchQueue, key: DispatchSpecificKey<Int>, context: Int) {
        self.dict = dict
        self.queue = queue
        self.key = key
        self.context = context
    }
    
    public subscript(key: Key) -> Value? {
        get {
            if !isOnQueue {
                var result: Value?
                queue.sync { result = dict[key] }
                return result
            } else {
                return dict[key]
            }
        }
        set {
            if !isOnQueue {
                queue.async(flags: .barrier) { [self] in dict[key] = newValue }
            } else {
                dict[key] = newValue
            }
        }
    }
    
    public func removeValue(forKey key: Key) {
        if !isOnQueue {
            queue.async(flags: .barrier) { [self] in dict.removeValue(forKey: key) }
        } else {
            dict.removeValue(forKey: key)
        }
    }
}
