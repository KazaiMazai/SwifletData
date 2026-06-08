//
//  File.swift
//
//
//  Created by Serge Kazakov on 02/03/2024.
//

import Foundation

struct EntitiesRepository {
    private var storages: [ObjectIdentifier: any EntityStorage] = [:]
}

protocol EntityStorage: Sendable { }

extension EntitiesRepository {
    struct Storage<Entity: EntityModelProtocol>: EntityStorage {
        var entities: [Entity.ID: Entity] = [:]
    }
}

// MARK: - Read

extension EntitiesRepository {
    private func storage<T: EntityModelProtocol>(_ type: T.Type) -> Storage<T>? {
        storages[ObjectIdentifier(T.self)] as? Storage<T>
    }

    func ids<T: EntityModelProtocol>(_ entityType: T.Type) -> [T.ID] {
        guard let storage = storage(T.self) else { return [] }
        return Array(storage.entities.keys)
    }

    func all<T: EntityModelProtocol>() -> [T] {
        guard let storage = storage(T.self) else { return [] }
        return Array(storage.entities.values)
    }

    func find<T: EntityModelProtocol>(_ id: T.ID) -> T? {
        storage(T.self)?.entities[id]
    }

    func findAll<T: EntityModelProtocol>(_ ids: [T.ID]) -> [T?] {
        guard let storage = storage(T.self) else { return ids.map { _ in nil } }
        return ids.map { storage.entities[$0] }
    }

    func findAllExisting<T: EntityModelProtocol>(_ ids: [T.ID]) -> [T] {
        guard let storage = storage(T.self) else { return [] }
        return ids.compactMap { storage.entities[$0] }
    }
}

// MARK: - Write

extension EntitiesRepository {
    /**
     Gives in-place mutable access to the typed storage box, removing it from the dictionary first
     so the box (and its entities) is uniquely referenced — avoiding a full copy-on-write of the
     storage. Unlike a reference type this preserves `Context` value semantics: a copied `Context`
     forks the storage on first write instead of sharing it.
    */
    private mutating func withStorage<T: EntityModelProtocol>(
        _ type: T.Type,
        _ body: (inout Storage<T>) -> Void
    ) {
        let key = ObjectIdentifier(T.self)
        var storage = storages.removeValue(forKey: key) as? Storage<T> ?? Storage<T>()
        body(&storage)
        storages[key] = storage
    }

    mutating func remove<T: EntityModelProtocol>(_ entityType: T.Type, id: T.ID) {
        guard storages[ObjectIdentifier(T.self)] != nil else { return }
        withStorage(T.self) { $0.entities[id] = nil }
    }

    mutating func removeAll<T: EntityModelProtocol>(_ entityType: T.Type, ids: [T.ID]) {
        guard storages[ObjectIdentifier(T.self)] != nil else { return }
        withStorage(T.self) { storage in
            ids.forEach { storage.entities[$0] = nil }
        }
    }

    mutating func insert<T: EntityModelProtocol>(_ entity: T, options: MergeStrategy<T>) {
        withStorage(T.self) { storage in
            if let existing = storage.entities[entity.id] {
                storage.entities[entity.id] = options.merge(existing, new: entity)
            } else {
                storage.entities[entity.id] = entity
            }
        }
    }

    mutating func insert<T: EntityModelProtocol>(_ entity: T?, options: MergeStrategy<T>) {
        guard let entity else {
            return
        }

        insert(entity, options: options)
    }

    mutating func insert<T: EntityModelProtocol>(_ entities: [T], options: MergeStrategy<T>) {
        guard !entities.isEmpty else {
            return
        }

        withStorage(T.self) { storage in
            for entity in entities {
                if let existing = storage.entities[entity.id] {
                    storage.entities[entity.id] = options.merge(existing, new: entity)
                } else {
                    storage.entities[entity.id] = entity
                }
            }
        }
    }
}

// MARK: - In-place mutation

extension EntitiesRepository {
    /**
     Mutates a stored entity in place, creating it from `makeDefault` if absent.

     Removing the entity from its storage before mutating makes it uniquely referenced, so the
     mutation happens in place rather than copying the whole value (the O(n) copy-on-write that
     the resolve → mutate → save round-trip incurs).
    */
    mutating func mutate<T: EntityModelProtocol>(
        _ id: T.ID,
        default makeDefault: () -> T,
        _ body: (inout T) -> Void
    ) {
        withStorage(T.self) { storage in
            var value = storage.entities.removeValue(forKey: id) ?? makeDefault()
            body(&value)
            storage.entities[id] = value
        }
    }

    /**
     Mutates a stored entity in place; a no-op if it does not exist.
    */
    mutating func mutateIfPresent<T: EntityModelProtocol>(
        _ id: T.ID,
        _ body: (inout T) -> Void
    ) {
        guard storages[ObjectIdentifier(T.self)] != nil else {
            return
        }

        withStorage(T.self) { storage in
            guard var value = storage.entities.removeValue(forKey: id) else {
                return
            }
            body(&value)
            storage.entities[id] = value
        }
    }
}
