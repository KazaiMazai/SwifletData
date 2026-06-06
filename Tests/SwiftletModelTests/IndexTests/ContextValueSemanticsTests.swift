//
//  ContextValueSemanticsTests.swift
//  SwiftletModel
//
//  Created by Serge Kazakov on 06/06/2026.
//

import SwiftletModel
import Foundation
import Testing

/**
 Indexes are value types, so copying a `Context` must produce independent index state:
 mutating one copy must never leak into the other. (A reference-typed index would share the
 instance and silently corrupt the original — these tests guard against that regression.)
*/
@Suite("Context Value Semantics", .tags(.index))
struct ContextValueSemanticsTests {

    @Test("Copying a Context keeps hash-index state independent")
    func whenContextCopied_HashIndexDoesNotLeak() throws {
        var original = Context()
        try IndexCostHash(id: "1", category: "A", value: 1).save(to: &original)

        var copy = original
        /** migrate A→B in the copy only */
        try IndexCostHash(id: "1", category: "B", value: 1).save(to: &copy)

        /** The original is untouched: entity 1 is still in bucket A there. */
        #expect(Set(IndexCostHash.filter(\.category == "A").resolve(in: original).map(\.id)) == ["1"])
        #expect(IndexCostHash.filter(\.category == "A").resolve(in: copy).isEmpty)
        #expect(Set(IndexCostHash.filter(\.category == "B").resolve(in: copy).map(\.id)) == ["1"])
    }

    @Test("Copying a Context keeps sort-index state independent")
    func whenContextCopied_SortIndexDoesNotLeak() throws {
        var original = Context()
        try IndexCostBTree(id: "1", category: "A", value: 1).save(to: &original)

        var copy = original
        /** migrate value 1→2 in the copy only */
        try IndexCostBTree(id: "1", category: "A", value: 2).save(to: &copy)

        #expect(Set(IndexCostBTree.filter(\.value == 1).resolve(in: original).map(\.id)) == ["1"])
        #expect(IndexCostBTree.filter(\.value == 1).resolve(in: copy).isEmpty)
        #expect(Set(IndexCostBTree.filter(\.value == 2).resolve(in: copy).map(\.id)) == ["1"])
    }
}
