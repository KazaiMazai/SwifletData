//
//  Unique.ComparableValueIndex.swift
//  SwiftletModel
//
//  Created by Serge Kazakov on 12/03/2025.
//
import Foundation

extension Index {
    @EntityRefModel
    final class HashableValue<Value: Hashable & Sendable>: @unchecked Sendable {
        typealias `Self` = Index.HashableValue<Value>
        var id: String { name }

        let name: String
        private let lock = NSLock()
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

        let index = Query(id: indexName).resolve(in: context) ?? Self(name: indexName)
        index.update(entity, value: value)
        try index.save(to: &context)
    }

    static func removeFromIndex(indexName: String,
                                _ entity: Entity,
                                in context: inout Context) throws {

        guard let index = Query<Self>(id: indexName).resolve(in: context) else {
            return
        }

        index.remove(entity)
        try index.save(to: &context)
    }

    func find(_ value: Value) -> Set<Entity.ID> {
        lock.withLock {
            index[value] ?? []
        }
    }
}

private extension Index.HashableValue {
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

private extension Index.HashableValue {
    func _update(_ entity: Entity, value: Value) {
        let existingValue = indexedValues[entity.id]

        guard existingValue != value else {
            return
        }

        if let existingValue, index[existingValue] != nil {
            _remove(entity)
        }

        var entities = index[value] ?? []
        entities.insert(entity.id)
        index[value] = entities
        indexedValues[entity.id] = value
    }

    func _remove(_ entity: Entity) {
        guard let value = indexedValues[entity.id],
              var ids = index[value]
        else {
            return
        }

        indexedValues[entity.id] = nil
        ids.remove(entity.id)
        index[value] = ids.isEmpty ? nil : ids
    }
}
