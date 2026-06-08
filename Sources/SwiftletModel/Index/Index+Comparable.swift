//
//  Index.ComparableValue.swift
//  SwiftletModel
//
//  Created by Serge Kazakov on 12/03/2025.
//

import Foundation
import BTree
import Collections

extension Index {
    @EntityModel
    struct ComparableValue<Value: Comparable & Sendable>: Sendable {
        var id: String { name }

        let name: String
        private var index: Map<Value, OrderedSet<Entity.ID>> = [:]
        private var indexedValues: [Entity.ID: Value] = [:]

        init(name: String) {
            self.name = name
        }

        func asDeleted(in context: Context) -> Deleted<Self>? { nil }

        func saveMetadata(to context: inout Context) throws { }

        func deleteMetadata(from context: inout Context) throws { }
    }
}

extension Index.ComparableValue {
    static func updateIndex(indexName: String,
                            _ entity: Entity,
                            value: Value,
                            in context: inout Context) throws {

        context.mutate(indexName, default: { Self(name: indexName) }) { index in
            index.update(entity, value: value)
        }
    }

    static func removeFromIndex(indexName: String,
                                _ entity: Entity,
                                in context: inout Context) throws {

        context.mutateIfPresent(indexName) { (index: inout Self) in
            index.remove(entity)
        }
    }
}

extension Index.ComparableValue {
    var sorted: [Entity.ID] {
        index.flatMap { $0.1.elements }
    }

    func valueFor(_ id: Entity.ID) -> Value? {
        indexedValues[id]
    }

    var lastValue: Value? {
        index.last?.0
    }
}

extension Index.ComparableValue {

    func filter(_ predicate: Predicate<Entity, Value>) -> [Entity.ID] {
        switch predicate.method {
        case .equal:
            return index[predicate.value]?.elements ?? []
        case .lessThan:
            guard let first = index.keys.first,
                    first <= predicate.value
            else {
                return []
            }

            return index
                .submap(from: first, to: predicate.value)
                .flatMap { $1.elements }
        case .lessThanOrEqual:
            guard let first = index.keys.first,
                    first <= predicate.value
            else {
                return []
            }

            return index
                .submap(from: first, through: predicate.value)
                .flatMap { $1.elements }
        case .greaterThan:
            guard let last = index.keys.last,
                  predicate.value <= last
            else {
                return []
            }

            return index
                .submap(from: predicate.value, through: last)
                .excluding(SortedSet(arrayLiteral: predicate.value))
                .flatMap { $1.elements }
        case .greaterThanOrEqual:
            guard let last = index.keys.last,
                  predicate.value <= last
            else {
                return []
            }

            return index
                .submap(from: predicate.value, through: last)
                .flatMap { $1.elements }
        case .notEqual:
            return index
                .excluding(SortedSet(arrayLiteral: predicate.value))
                .flatMap { $1.elements }
        }
    }

    func filter(range: Range<Value>) -> [Entity.ID] {
        index
            .submap(from: range.lowerBound, to: range.upperBound)
            .map { $1.elements }
            .flatMap { $0 }
    }

    func filter(range: ClosedRange<Value>) -> [Entity.ID] {
        index
            .submap(from: range.lowerBound, through: range.upperBound)
            .map { $1.elements }
            .flatMap { $0 }
    }

    func contains(id: Entity.ID?, in range: ClosedRange<Value>) -> Bool {
        guard let id, let value = indexedValues[id] else {
            return false
        }

        return range.contains(value)
    }

    func grouped() -> [Value: [Entity.ID]] where Value: Hashable {
        Dictionary(index.map { ($0, $1.elements) },
                   uniquingKeysWith: { $1 })
    }
}

private extension Index.ComparableValue {
    mutating func update(_ entity: Entity, value: Value) {
        let existingValue = indexedValues[entity.id]

        guard existingValue != value else {
            return
        }

        if let existingValue, var ids = index[existingValue] {
            ids.remove(entity.id)
            index[existingValue] = ids.isEmpty ? nil : ids
        }

        guard var ids = index[value] else {
            index[value] = OrderedSet(arrayLiteral: entity.id)
            indexedValues[entity.id] = value
            return
        }

        ids.append(entity.id)
        index[value] = ids
        indexedValues[entity.id] = value
    }

    mutating func remove(_ entity: Entity) {
        guard let value = indexedValues[entity.id],
              var ids = index[value]
        else {
            return
        }

        indexedValues[entity.id] = nil
        ids.remove(entity.id)
        index[value] = ids
    }
}
