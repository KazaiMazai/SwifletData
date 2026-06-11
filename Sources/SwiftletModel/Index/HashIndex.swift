//
//  HashIndex.swift
//  SwiftletModel
//
//  Created by Serge Kazakov on 08/03/2025.
//

import Foundation

@propertyWrapper
public struct HashIndex<Entity: EntityModelProtocol>: Sendable, Omitable {
    public var wrappedValue: Never.Type? { nil }

    public init(wrappedValue: Never.Type?) { }

    public init<T0>(_ kp0: KeyPath<Entity, T0>)
    where T0: Hashable { }

    public init<T0, T1>(
        _ kp0: KeyPath<Entity, T0>,
        _ kp1: KeyPath<Entity, T1>)
    where T0: Hashable, T1: Hashable { }

    public init<T0, T1, T2>(
        _ kp0: KeyPath<Entity, T0>,
        _ kp1: KeyPath<Entity, T1>,
        _ kp2: KeyPath<Entity, T2>)
    where T0: Hashable, T1: Hashable, T2: Hashable { }

    public init<T0, T1, T2, T3>(
        _ kp0: KeyPath<Entity, T0>,
        _ kp1: KeyPath<Entity, T1>,
        _ kp2: KeyPath<Entity, T2>,
        _ kp3: KeyPath<Entity, T3>)
    where T0: Hashable, T1: Hashable, T2: Hashable, T3: Hashable { }
}
