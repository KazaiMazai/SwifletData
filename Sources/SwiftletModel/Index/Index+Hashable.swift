//
//  Unique.ComparableValueIndex.swift
//  SwiftletModel
//
//  Created by Serge Kazakov on 12/03/2025.
//
import Foundation

extension Index {
    @EntityModel
    struct HashableValue<Value: Hashable & Sendable> {
        var id: String { name }

        let name: String

        private var index: [Value: Set<Entity.ID>] = [:]
        private var indexedValues: [Entity.ID: Value] = [:]

        init(name: String) {
            self.name = name
        }

        func asDeleted(in context: Context) -> Deleted<Self>? { nil }

        func saveMetadata(to context: inout Context) throws { }

        func deleteMetadata(from context: inout Context) throws { }
    }
}

extension Index.HashableValue {
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

    func find(_ value: Value) -> Set<Entity.ID> {
        index[value] ?? []
    }
}

private extension Index.HashableValue {

    mutating func update(_ entity: Entity,
                         value: Value) {
        let existingValue = indexedValues[entity.id]

        guard existingValue != value else {
            return
        }

        if let existingValue, index[existingValue] != nil {
            remove(entity)
        }

        index[value, default: []].insert(entity.id)
        indexedValues[entity.id] = value
    }

    mutating func remove(_ entity: Entity) {
        guard let value = indexedValues[entity.id],
              index[value] != nil
        else {
            return
        }

        indexedValues[entity.id] = nil
        index[value]?.remove(entity.id)
        if index[value]?.isEmpty == true {
            index[value] = nil
        }
    }
}
