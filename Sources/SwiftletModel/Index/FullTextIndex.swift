//
//  FullTextIndex.swift
//  SwiftletModel
//
//  Created by Serge Kazakov on 08/03/2025.
//

import Foundation

@propertyWrapper
public struct FullTextIndex<Entity: EntityModelProtocol>: Sendable, OmittableFromCoding, OmittableFromHashing {
    public var wrappedValue: Never.Type? { nil }

    public init(wrappedValue: Never.Type?) { }

    public init(_ keypaths: KeyPath<Entity, String>...) { }
}
