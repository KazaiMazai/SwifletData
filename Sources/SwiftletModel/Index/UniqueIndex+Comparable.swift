//
//  File.swift
//  SwiftletModel
//
//  Created by Serge Kazakov on 10/03/2025.
//

import Foundation
import BTree

extension Unique {
    @EntityRefModel
    final class ComparableValue<Value: Comparable & Sendable>: @unchecked Sendable {
        typealias `Self` = Unique.ComparableValue<Value>
        var id: String { name }

        let name: String
        private let lock = NSLock()
        private var index: Map<Value, Entity.ID> = [:]
        private var indexedValues: [Entity.ID: Value] = [:]

        init(name: String) {
            self.name = name
        }

        func asDeleted(in context: Context) -> Deleted<Self>? { nil }

        func saveMetadata(to context: inout Context) throws { }

        func deleteMetadata(from context: inout Context) throws { }
    }
}

extension Unique.ComparableValue {
    enum Errors: Error {
        case uniqueValueViolation(Entity.ID, Value)
    }
}

extension Unique.ComparableValue {
    static func updateIndex(indexName: String,
                            _ entity: Entity,
                            value: Value,
                            in context: inout Context,
                            resolveCollisions resolver: CollisionResolver<Entity>) throws {

        var index = Query(id: indexName).resolve(in: context) ?? Self(name: indexName)
        try index.checkForCollisions(entity, value: value, in: &context, resolveCollisions: resolver)
        index = index.query().resolve(in: context) ?? index
        index.update(entity, value: value)
        try index.save(to: &context)
    }

    static func removeFromIndex(indexName: String,
                                _ entity: Entity,
                                in context: inout Context) throws {

        let index = Query<Self>(id: indexName).resolve(in: context)
        index?.remove(entity)
        try index?.save(to: &context)
    }
}

private extension Unique.ComparableValue {
    func checkForCollisions(_ entity: Entity,
                            value: Value,
                            in context: inout Context,
                            resolveCollisions resolver: CollisionResolver<Entity>) throws {
        // Read under the lock, but call the resolver outside it: the resolver can re-enter
        // (e.g. save another entity → updateIndex on this same instance), and NSLock isn't recursive.
        let existingId = lock.withLock { index[value] }
        guard let existingId, existingId != entity.id else {
            return
        }

        try resolver.resolveCollision(existing: existingId, new: entity, indexName: name, in: &context)
    }

    func update(_ entity: Entity, value: Value) {
        lock.withLock {
            _update(entity, value: value)
        }
    }

    func remove(_ entity: Entity) {
        lock.withLock {
            _remove(entity)
        }
    }
}

private extension Unique.ComparableValue {
    func _update(_ entity: Entity, value: Value) {
        let existingValue = indexedValues[entity.id]

        guard existingValue != value else {
            return
        }

        if let existingValue, index[existingValue] != nil {
            index[existingValue] = nil
        }

        index[value] = entity.id
        indexedValues[entity.id] = value
    }

    func _remove(_ entity: Entity) {
        guard let value = indexedValues[entity.id],
              index[value] != nil
        else {
            return
        }

        indexedValues[entity.id] = nil
        index[value] = nil
    }
}
