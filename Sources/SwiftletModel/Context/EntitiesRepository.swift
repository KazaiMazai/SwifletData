//
//  File.swift
//
//
//  Created by Serge Kazakov on 02/03/2024.
//

import Foundation

struct EntitiesRepository {
    typealias EntityID = String
    typealias EntityName = String

    private var storages: [EntityName: [EntityID: any EntityModelProtocol]] = [:]
}

extension EntitiesRepository {
    func ids<T: EntityModelProtocol>(_ entityType: T.Type) -> [T.ID] {
        let entityName = String(reflecting: T.self)
        return storages[entityName]?.keys.compactMap { T.ID($0) } ?? []
    }

    func all<T: EntityModelProtocol>() -> [T] {
        let entityName = String(reflecting: T.self)
        return storages[entityName]?.compactMap { $0.value as? T } ?? []
    }

    func find<T: EntityModelProtocol>(_ id: T.ID) -> T? {
        let entityName = EntityName(reflecting: T.self)
        let storage = storages[entityName] ?? [:]
        return storage[id.description] as? T
    }

    func findAll<T: EntityModelProtocol>(_ ids: [T.ID]) -> [T?] {
        ids.map { find($0) }
    }

    func findAllExisting<T: EntityModelProtocol>(_ ids: [T.ID]) -> [T] {
        findAll(ids).compactMap { $0 }
    }
}

extension EntitiesRepository {
    mutating func remove<T: EntityModelProtocol>(_ entityType: T.Type, id: T.ID) {
        let key = EntityName(reflecting: T.self)
        /**
         In-place mutation via optional-chaining keeps the inner dictionary uniquely
         referenced during the modify, avoiding a full O(n) copy-on-write of the storage.
        */
        storages[key]?.removeValue(forKey: id.description)
    }

    mutating func removeAll<T: EntityModelProtocol>(_ entityType: T.Type, ids: [T.ID]) {
        ids.forEach { remove(T.self, id: $0) }
    }

    mutating func insert<T: EntityModelProtocol>(_ entity: T, options: MergeStrategy<T>) {
        let key = String(reflecting: T.self)
        guard let existing: T = find(entity.id) else {
            storages[key, default: [:]][entity.id.description] = entity
            return
        }

        let merged = options.merge(existing, new: entity)
        storages[key, default: [:]][entity.id.description] = merged
    }

    mutating func insert<T: EntityModelProtocol>(_ entity: T?, options: MergeStrategy<T>) {
        guard let entity else {
            return
        }

        insert(entity, options: options)
    }

    mutating func insert<T: EntityModelProtocol>(_ entities: [T], options: MergeStrategy<T>) {
        entities.forEach { insert($0, options: options) }
    }
}

extension EntitiesRepository {
    /**
     Mutates a stored entity in place, creating it from `makeDefault` if absent.

     Removing the value from storage before mutating makes it uniquely referenced, so the
     mutation happens in place rather than copying the whole value (the O(n) copy-on-write that
     the resolve → mutate → save round-trip incurs). Unlike a reference type, this preserves
     `Context` value semantics: a copied `Context` forks the value on first write instead of
     sharing it.
    */
    mutating func mutate<T: EntityModelProtocol>(
        _ id: T.ID,
        default makeDefault: () -> T,
        _ body: (inout T) -> Void
    ) {
        let key = String(reflecting: T.self)
        var value = storages[key]?.removeValue(forKey: id.description) as? T ?? makeDefault()
        body(&value)
        storages[key, default: [:]][id.description] = value
    }

    /**
     Mutates a stored entity in place; a no-op if it does not exist.
    */
    mutating func mutateIfPresent<T: EntityModelProtocol>(
        _ id: T.ID,
        _ body: (inout T) -> Void
    ) {
        let key = String(reflecting: T.self)
        guard var value = storages[key]?.removeValue(forKey: id.description) as? T else {
            return
        }
        body(&value)
        storages[key, default: [:]][id.description] = value
    }
}
