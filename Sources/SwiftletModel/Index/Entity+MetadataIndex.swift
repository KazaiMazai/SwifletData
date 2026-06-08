//
//  File.swift
//  SwiftletModel
//
//  Created by Serge Kazakov on 21/04/2025.
//

import Foundation

public extension EntityModelProtocol {
    private static func updatedAtIndex(in context: Context) -> SortIndex<Self>.ComparableValue<Date>? {
        SortIndex<Self>.ComparableValue<Date>
            .query(Metadata.updatedAt.indexName)
            .resolve(in: context)
    }
 
    func updatedAt(in context: Context) -> Date? {
        Self.updatedAtIndex(in: context)?.valueFor(id)
    }
    
    func updatedAt<E: EntityModelProtocol>(_ keypath: KeyPath<Self, E?>, in context: Context, withNested: Bool) -> Date? {
        self[keyPath: keypath]?.updatedAt(in: context, withNested: withNested)
    }
    
    func updatedAt<E: EntityModelProtocol>(_ keypath: KeyPath<Self, [E]?>, in context: Context, withNested: Bool) -> Date? {
        self[keyPath: keypath]?.compactMap { $0.updatedAt(in: context, withNested: withNested) }.max()
    }
}

public extension EntityModelProtocol {
    func updateMetadata<Value>(
        _ metadata: Metadata,
        value: Value,
        in context: inout Context) throws
    where
    Value: Comparable & Sendable {

        try Index.ComparableValue.updateIndex(
            indexName: metadata.indexName,
            self,
            value: value,
            in: &context
        )
    }
}

public extension EntityModelProtocol {
    func removeFromMetadata<Value>(
        _ metadata: Metadata,
        valueType: Value.Type,
        in context: inout Context) throws
    where
    Value: Comparable & Sendable {

        try Index.ComparableValue<Value>.removeFromIndex(
            indexName: metadata.indexName,
            self, in: &context)
    }
}
