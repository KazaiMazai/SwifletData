//
//  IndexCostSavePerformanceTests.swift
//  SwiftletModel
//
//  Created by Serge Kazakov on 06/06/2026.
//

import SwiftletModel
import Foundation
import XCTest

/**
 Relation-free entities with IDENTICAL stored fields, differing only in index annotations.
 Saving the same data into a fresh context isolates the raw write cost of each index kind.
*/

@EntityModel
struct IndexCostPlain: Sendable {
    let id: String
    let category: String
    let value: Int
}

@EntityModel
struct IndexCostHash: Sendable {
    @HashIndex<Self>(\.category) private var categoryIndex

    let id: String
    let category: String
    let value: Int
}

@EntityModel
struct IndexCostBTree: Sendable {
    @Index<Self>(\.value) private var valueIndex

    let id: String
    let category: String
    let value: Int
}

@EntityModel
struct IndexCostHashAndBTree: Sendable {
    @HashIndex<Self>(\.category) private var categoryIndex
    @Index<Self>(\.value) private var valueIndex

    let id: String
    let category: String
    let value: Int
}

@EntityModel
struct IndexCostUnique: Sendable {
    @Unique<Self>(\.value, collisions: .throw) private var valueUnique

    let id: String
    let category: String
    let value: Int
}

/**
 Full-text index. Shared common tokens (large per-token sets) + a unique token per doc.
*/
@EntityModel
struct IndexCostFullText: Sendable {
    @FullTextIndex<Self>(\.text) private var textIndex

    let id: String
    let text: String
}

final class IndexCostSavePerformanceTests: XCTestCase {
    var count: Int { ProcessInfo.processInfo.environment["IDX_COUNT"].flatMap(Int.init) ?? 5000 }

    /**
     Distinct ids and values (B-tree keys all unique); category cycles through 10 buckets.
    */
    lazy var plain: [IndexCostPlain] = (0..<count).map {
        IndexCostPlain(id: "\($0)", category: "cat\($0 % 10)", value: $0)
    }.shuffled()

    lazy var hashed: [IndexCostHash] = (0..<count).map {
        IndexCostHash(id: "\($0)", category: "cat\($0 % 10)", value: $0)
    }.shuffled()

    lazy var btree: [IndexCostBTree] = (0..<count).map {
        IndexCostBTree(id: "\($0)", category: "cat\($0 % 10)", value: $0)
    }.shuffled()

    lazy var hashAndBtree: [IndexCostHashAndBTree] = (0..<count).map {
        IndexCostHashAndBTree(id: "\($0)", category: "cat\($0 % 10)", value: $0)
    }.shuffled()

    lazy var unique: [IndexCostUnique] = (0..<count).map {
        IndexCostUnique(id: "\($0)", category: "cat\($0 % 10)", value: $0)
    }.shuffled()

    lazy var fullText: [IndexCostFullText] = (0..<count).map {
        IndexCostFullText(id: "\($0)", text: "common shared lorem ipsum entity unique\($0)")
    }.shuffled()

    func test_Plain_NoIndex_SavePerformance() throws {
        let models = plain
        measure {
            var context = Context()
            try! models.forEach { try $0.save(to: &context) }
        }
    }

    func test_HashIndex_SavePerformance() throws {
        let models = hashed
        measure {
            var context = Context()
            try! models.forEach { try $0.save(to: &context) }
        }
    }

    func test_BTreeIndex_SavePerformance() throws {
        let models = btree
        measure {
            var context = Context()
            try! models.forEach { try $0.save(to: &context) }
        }
    }

    func test_HashAndBTreeIndex_SavePerformance() throws {
        let models = hashAndBtree
        measure {
            var context = Context()
            try! models.forEach { try $0.save(to: &context) }
        }
    }

    func test_UniqueIndex_SavePerformance() throws {
        let models = unique
        measure {
            var context = Context()
            try! models.forEach { try $0.save(to: &context) }
        }
    }

    func test_FullTextIndex_SavePerformance() throws {
        let models = fullText
        measure {
            var context = Context()
            try! models.forEach { try $0.save(to: &context) }
        }
    }
}
