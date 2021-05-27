//
//  Dictionary+KeyPath.swift
//  wv-inject
//
//  Created by Sergey Ryazanov on 27.05.2021.
//

import Foundation

// MARK: - KeyPath

struct KeyPath {
    var segments: [String]

    var isEmpty: Bool {
        return self.segments.isEmpty
    }

    var path: String {
        return self.segments.joined(separator: ".")
    }

    func headAndTail() -> (head: String, tail: KeyPath)? {
        guard !self.isEmpty else {
            return nil
        }

        var tail = self.segments
        let head = tail.removeFirst()

        return (head, KeyPath(segments: tail))
    }
}

extension KeyPath {
    init(_ string: String) {
        self.segments = string.components(separatedBy: ".")
    }
}

extension KeyPath: ExpressibleByStringLiteral {

    init(stringLiteral value: String) {
        self.init(value)
    }
    init(unicodeScalarLiteral value: String) {
        self.init(value)
    }
    init(extendedGraphemeClusterLiteral value: String) {
        self.init(value)
    }
}

// MARK: - String

protocol StringProtocol {
    init(string s: String)
}

extension String: StringProtocol {
    init(string s: String) {
        self = s
    }
}

// MARK: - Dictionary

extension Dictionary where Key: StringProtocol {
    subscript(keyPath keyPath: KeyPath) -> Any? {
        get {
            switch keyPath.headAndTail() {
            case nil:
                // key path is empty.
                return nil
            case let (head, remainingKeyPath)? where remainingKeyPath.isEmpty:
                // Reached the end of the key path.
                let key = Key(string: head)
                return self[key]
            case let (head, remainingKeyPath)?:
                // Key path has a tail we need to traverse.
                let key = Key(string: head)
                switch self[key] {
                case let nestedDict as [Key: Any]:
                    // Next nest level is a dictionary.
                    // Start over with remaining key path.
                    return nestedDict[keyPath: remainingKeyPath]
                default:
                    // Next nest level isn't a dictionary.
                    // Invalid key path, abort.
                    return nil
                }
            }
        }
        set {
            switch keyPath.headAndTail() {
            case nil:
                // key path is empty.
                return
            case let (head, remainingKeyPath)? where remainingKeyPath.isEmpty:
                // Reached the end of the key path.
                let key = Key(string: head)
                self[key] = newValue as? Value
            case let (head, remainingKeyPath)?:
                let key = Key(string: head)
                let value = self[key]
                switch value {
                case var nestedDict as [Key: Any]:
                    // Key path has a tail we need to traverse
                    nestedDict[keyPath: remainingKeyPath] = newValue
                    self[key] = nestedDict as? Value
                default:
                    // Invalid keyPath
                    return
                }
            }
        }
    }
}

extension Dictionary where Key: StringProtocol {
    subscript(string keyPath: KeyPath) -> String? {
        get { return self[keyPath: keyPath] as? String }
        set { self[keyPath: keyPath] = newValue }
    }

    subscript(dict keyPath: KeyPath) -> [Key: Any]? {
        get { return self[keyPath: keyPath] as? [Key: Any] }
        set { self[keyPath: keyPath] = newValue }
    }
}

