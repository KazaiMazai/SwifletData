//
//  Map+Sendable.swift
//  SwiftletModel
//
//  Created by Serge Kazakov on 06/06/2026.
//

import BTree

/**
 BTree's `Map` isn't declared Sendable (its internal nodes are reference types), but it's a value
 type with copy-on-write semantics: a copy is independent, so transferring one across threads is
 safe as long as its contents are. `@unchecked` because the compiler can't verify the
 reference-typed internals; the `where` clause keeps the claim scoped to genuinely-safe contents.
*/
extension Map: @retroactive @unchecked Sendable where Key: Sendable, Value: Sendable { }
