//
//  File.swift
//
//
//  Created by Serge Kazakov on 02/03/2024.
//

import Foundation
import Collections

public struct Context: Sendable {
    private var entitiesRepository = EntitiesRepository()

    public init() { }
}

public extension Context {
    func ids<T: EntityModelProtocol>(_ entityType: T.Type) -> [T.ID] {
        entitiesRepository.ids(T.self)
    }

    func all<T: EntityModelProtocol>() -> [T] {
        entitiesRepository.all()
    }

    func find<T: EntityModelProtocol>(_ id: T.ID) -> T? {
        entitiesRepository.find(id)
    }

    func findAll<T: EntityModelProtocol>(_ ids: [T.ID]) -> [T?] {
        entitiesRepository.findAll(ids)
    }

    func findAllExisting<T: EntityModelProtocol>(_ ids: [T.ID]) -> [T] {
        entitiesRepository.findAllExisting(ids)
    }
}

public extension Context {

    mutating func remove<T: EntityModelProtocol>(_ entityType: T.Type, id: T.ID) {
        entitiesRepository.remove(T.self, id: id)
    }

    mutating func removeAll<T: EntityModelProtocol>(_ entityType: T.Type, ids: [T.ID]) {
        entitiesRepository.removeAll(T.self, ids: ids)
    }

    mutating func insert<T: EntityModelProtocol>(_ entity: T,
                                                 options: MergeStrategy<T> = .replace) {

        entitiesRepository.insert(entity, options: options)
    }

    mutating func insert<T: EntityModelProtocol>(_ entity: T?,
                                                 options: MergeStrategy<T> = .replace) {

        entitiesRepository.insert(entity, options: options)
    }

    mutating func insert<T: EntityModelProtocol>(_ entities: [T],
                                                 options: MergeStrategy<T> = .replace) {

        entitiesRepository.insert(entities, options: options)
    }
}

extension Context {
    mutating func mutate<T: EntityModelProtocol>(
        _ id: T.ID,
        default makeDefault: () -> T,
        _ body: (inout T) -> Void
    ) {
        entitiesRepository.mutate(id, default: makeDefault, body)
    }

    mutating func mutateIfPresent<T: EntityModelProtocol>(
        _ id: T.ID,
        _ body: (inout T) -> Void
    ) {
        entitiesRepository.mutateIfPresent(id, body)
    }
}

extension Context {
    func query<Entity: EntityModelProtocol>(_ id: Entity.ID) -> Query<Entity> {
        Query(id: id)
    }

    func query<Entity: EntityModelProtocol>(_ ids: [Entity.ID]) -> QueryList<Entity> {
        QueryList { context in
            ids.map { context.query($0) }
        }
    }

    func queryAll<Entity: EntityModelProtocol>() -> QueryList<Entity> {
        QueryList { context in
            context
                .ids(Entity.self)
                .map { context.query($0) }
        }
    }
}
