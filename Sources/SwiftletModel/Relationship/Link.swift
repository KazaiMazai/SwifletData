//
//  StoredRelationships.swift
//  SwiftletModel
//
//  Created by Sergey Kazakov on 12/06/2025.
//

import Foundation
import Collections

@EntityModel
struct Link<Parent, Child>: Sendable
where
Parent: EntityModelProtocol,
Child: EntityModelProtocol {

    var id: String { "\(parent)-\(name)" }

    private let parent: Parent.ID
    private(set) var children: OrderedSet<Child.ID>
    private let name: String

    init<Value>( _ parent: Parent.ID, _ children: [Child.ID], keyPath: KeyPath<Parent, Value>) {
        self.parent = parent
        self.name = keyPath.name
        self.children = OrderedSet(children)
    }

    func asDeleted(in context: Context) -> Deleted<Self>? { nil }

    func saveMetadata(to context: inout Context) throws { }

    func deleteMetadata(from context: inout Context) throws { }

    static var defaultMergeStrategy: MergeStrategy<Self> { Self.replace }

    static var fragmentMergeStrategy: MergeStrategy<Self> { Self.append }
}

extension Link {
    enum UpdateOption {
        case append
        case replace
        case remove

        var merge: MergeStrategy<Link<Parent, Child>> {
            switch self {
            case .append:
                return Link<Parent, Child>.append
            case .replace:
                return Link<Parent, Child>.replace
            case .remove:
                return Link<Parent, Child>.remove
            }
        }
    }
}

extension Link {
    static var append: MergeStrategy<Self> {
        MergeStrategy { old, new in
            var old = old
            old.children.append(contentsOf: new.children)
            return old
        }
    }

    static var replace: MergeStrategy<Self> {
        MergeStrategy { _, new in new }
    }

    static var remove: MergeStrategy<Self> {
        MergeStrategy { old, new in
            var old = old
            old.children.subtract(new.children)
            return old
        }
    }
}

extension Link {
    static func findChildrenOf<Directionality, Cardinality, Constraint>(
        _ parent: Parent.ID,
        with keyPath: KeyPath<Parent, Relation<Child, Directionality, Cardinality, Constraint>>,
        in context: Context) -> [Child.ID] {
            query("\(parent)-\(keyPath.name)")
                .resolve(in: context)?
                .children.elements ?? []
        }

    static func update<Cardinality, Constraint>(
        _ parent: Parent.ID,
        _ children: [Child.ID],
        keyPath: KeyPath<Parent, OneWayRelation<Child, Cardinality, Constraint>>,
        in context: inout Context,
        options: UpdateOption
    ) throws {

        switch options {
        case .replace, .remove:
            try Link<Parent, Child>.updateOneWayLink(
                parent, children,
                keyPath: keyPath,
                in: &context,
                merge: options.merge
            )
        case.append where !children.isEmpty:
            try Link<Parent, Child>.updateOneWayLink(
                parent, children,
                keyPath: keyPath,
                in: &context,
                merge: options.merge
            )
        case .append:
            break
        }
    }

    // swiftlint:disable:next function_parameter_count
    static func update<Cardinality, Constraint, InverseRelation, InverseConstraint>(
        _ parent: Parent.ID,
        _ children: [Child.ID],
        keyPath: KeyPath<Parent, MutualRelation<Child, Cardinality, Constraint>>,
        inverse: KeyPath<Child, MutualRelation<Parent, InverseRelation, InverseConstraint>>,
        in context: inout Context,
        options: UpdateOption) throws {

            switch options {
            case .remove where !children.isEmpty:
                try Link<Parent, Child>.updateMutualLink(
                    parent, children,
                    keyPath: keyPath,
                    inverse: inverse,
                    in: &context,
                    directMerge: Link<Parent, Child>.remove,
                    inverseMerge: Link<Child, Parent>.remove
                )
            case .remove:
                break
            case .append where !children.isEmpty:
                try Link<Parent, Child>.updateMutualLink(
                    parent, children,
                    keyPath: keyPath,
                    inverse: inverse,
                    in: &context,
                    directMerge: Link<Parent, Child>.append,
                    inverseMerge: inverse.valueType.inverseUpdateOption().merge
                )
            case .append:
                break
            case .replace:
                let childrenSet = Set(children)
                let oddChildren = Link<Parent, Child>
                    .findChildrenOf(parent, with: keyPath, in: context)
                    .filter { !childrenSet.contains($0) }

                if !oddChildren.isEmpty {
                    try Link<Parent, Child>.updateMutualLink(
                        parent, oddChildren,
                        keyPath: keyPath,
                        inverse: inverse,
                        in: &context,
                        directMerge: Link<Parent, Child>.remove,
                        inverseMerge: Link<Child, Parent>.remove
                    )
                }

                try Link<Parent, Child>.updateMutualLink(
                    parent, children,
                    keyPath: keyPath,
                    inverse: inverse,
                    in: &context,
                    directMerge: Link<Parent, Child>.replace,
                    inverseMerge: inverse.valueType.inverseUpdateOption().merge
                )
            }
        }
}

private extension Link {
    // swiftlint:disable:next function_parameter_count
    static func updateMutualLink<Cardinality, Constraint, InverseRelation, InverseConstraint>(
        _ parent: Parent.ID,
        _ children: [Child.ID],
        keyPath: KeyPath<Parent, MutualRelation<Child, Cardinality, Constraint>>,
        inverse: KeyPath<Child, MutualRelation<Parent, InverseRelation, InverseConstraint>>,
        in context: inout Context,
        directMerge: MergeStrategy<Link<Parent, Child>>,
        inverseMerge: MergeStrategy<Link<Child, Parent>>) throws {

            let directLink = Link(
                parent, children,
                keyPath: keyPath
            )
            try directLink.save(to: &context, options: directMerge)
            try children.forEach {
                let inverseLink = Link<Child, Parent>(
                    $0, [parent],
                    keyPath: inverse
                )

                try inverseLink.save(
                    to: &context,
                    options: inverseMerge
                )
            }
        }

    static func updateOneWayLink<Cardinality, Constraint>(
        _ parent: Parent.ID,
        _ children: [Child.ID],
        keyPath: KeyPath<Parent, OneWayRelation<Child, Cardinality, Constraint>>,
        in context: inout Context,
        merge: MergeStrategy<Link<Parent, Child>>) throws {

            let directLink = Link(
                parent, children,
                keyPath: keyPath
            )
            try directLink.save(to: &context, options: merge)
        }
}
