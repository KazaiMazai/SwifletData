//
//  OmittableCoding.swift
//  SwiftletModel
//
//  Created by Serge Kazakov on 12/03/2025.
//

import Foundation

public typealias OmittableFromCoding = OmittableFromEncoding & OmittableFromDecoding

public protocol OmittableFromEncoding: Encodable { }

extension KeyedDecodingContainer {
    public func decode<T>(_ type: T.Type, forKey key: KeyedDecodingContainer<K>.Key) throws -> T where T: OmittableFromDecoding {
        return try decodeIfPresent(T.self, forKey: key) ?? T(wrappedValue: nil)
    }
}


extension KeyedEncodingContainer {
    public mutating func encode<T>(_ value: T, forKey key: KeyedEncodingContainer<K>.Key) throws where T: OmittableFromEncoding {
        return
    }
}

extension OmittableFromEncoding {
    public func encode(to encoder: Encoder) throws { }
}


public protocol OmittableFromDecoding: Decodable {
    associatedtype WrappedType: ExpressibleByNilLiteral
    init(wrappedValue: WrappedType)
}

extension OmittableFromDecoding {
    public init(from decoder: Decoder) throws {
        self.init(wrappedValue: nil)
    }
}
