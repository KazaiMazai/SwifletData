//
//  Unique.ComparableValueIndex 2.swift
//  SwiftletModel
//
//  Created by Serge Kazakov on 12/03/2025.
//

import Foundation

extension Unique {
    @EntityModel
    struct HashableValue<Value: Hashable & Sendable> {
        var id: String { name }

        let name: String

        private var index: [Value: Entity.ID] = [:]
        private var indexedValues: [Entity.ID: Value] = [:]

        init(name: String) {
            self.name = name
        }

        func asDeleted(in context: Context) -> Deleted<Self>? { nil }

        func saveMetadata(to context: inout Context) throws { }

        func deleteMetadata(from context: inout Context) throws { }
    }
}

extension Unique.HashableValue {
    enum Errors: Error {
        case uniqueValueViolation(Entity.ID, Value)
    }
}

extension Unique.HashableValue {
    static func updateIndex(indexName: String,
                            _ entity: Entity,
                            value: Value,
                            in context: inout Context,
                            resolveCollisions resolver: CollisionResolver<Entity>) throws {

        /**
         Resolve a read-only copy to check for collisions first: the resolver may re-entrantly
         mutate the context (and this very index). Then apply the update in place, which re-reads
         the (possibly resolver-updated) index from storage — replacing the old re-resolve dance.
        */
        try Query<Self>(id: indexName).resolve(in: context)?
            .checkForCollisions(entity, value: value, in: &context, resolveCollisions: resolver)

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

private extension Unique.HashableValue {
    func checkForCollisions(_ entity: Entity,
                            value: Value,
                            in context: inout Context,
                            resolveCollisions resolver: CollisionResolver<Entity>) throws {
        guard let existingId = index[value], existingId != entity.id else {
            return
        }

        try resolver.resolveCollision(existing: existingId, new: entity, indexName: name, in: &context)
    }

    mutating func update(_ entity: Entity,
                         value: Value) {
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

    mutating func remove(_ entity: Entity) {
        guard let value = indexedValues[entity.id],
              index[value] != nil
        else {
            return
        }

        indexedValues[entity.id] = nil
        index[value] = nil
    }
}
