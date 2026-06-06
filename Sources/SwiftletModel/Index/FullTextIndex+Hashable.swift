//
//  File.swift
//  SwiftletModel
//
//  Created by Serge Kazakov on 04/04/2025.
//

import Foundation

extension FullTextIndex {
    @EntityModel
    struct HashableValue<Value: Hashable & Sendable> {
        // swiftlint:disable:next nesting
        typealias Token = String

        var id: String { name }

        let name: String

        private var index: [Token: Set<Entity.ID>] = [:]

        private var indexedValues: [Entity.ID: Value] = [:]
        private var tokensForEntities: [Entity.ID: Set<Token>] = [:]
        private var tokenFrequenciesForEntities: [Entity.ID: [Token: Int]] = [:]
        private var valueLenghtsForEntities: [Entity.ID: Int] = [:]

        private var averageValueLength: Double = 0.0
        private var totalLengthSum: Int = 0
        private var entitiesCount: Int = 0

        private let bm25ParameterK1: Double = 1.2  // term frequency saturation parameter
        private let bm25ParameterB: Double = 0.75  // length normalization parameter

        init(name: String) {
            self.name = name
        }

        func asDeleted(in context: Context) -> Deleted<Self>? { nil }

        func saveMetadata(to context: inout Context) throws { }

        func deleteMetadata(from context: inout Context) throws { }
    }
}

extension FullTextIndex.HashableValue {
    // Constants for BM25 ranking

    func search(_ value: String) -> [Entity.ID] {
        let tokens = value.makeTokens()
        var scores: [Entity.ID: Double] = [:]

        for token in tokens {
            guard let matchingDocs = index[token] else { continue }

            // Calculate IDF
            let documentsCount = Double(tokensForEntities.count) // total number of documents
            let matchingDocumentsCount = Double(matchingDocs.count) // number of documents containing the term
            let idf = log((documentsCount - matchingDocumentsCount + 0.5) / (matchingDocumentsCount + 0.5) + 1.0)

            for entityId in matchingDocs {
                let tokenFrequency = Double(tokenFrequenciesForEntities[entityId]?[token] ?? 0)
                let docLength = Double(valueLenghtsForEntities[entityId] ?? 0)

                // BM25 score calculation
                let numerator = tokenFrequency * (bm25ParameterK1 + 1.0)
                let denominator = tokenFrequency + bm25ParameterK1 *
                (1.0 - bm25ParameterB + bm25ParameterB * docLength / averageValueLength)
                let score = idf * numerator / denominator

                scores[entityId, default: 0] += score
            }
        }

        return scores.sorted { $0.value > $1.value }.map { $0.key }
    }
}

extension FullTextIndex.HashableValue {
    static func updateIndex(indexName: String,
                            _ entity: Entity,
                            value: Value,
                            in context: inout Context) throws {

        context.mutate(indexName, default: { Self(name: indexName) }) { index in
            index.update(entity, value: value)
        }
    }

    static func removeFromIndex(indexName: String,
                                _ entity: Entity,
                                in context: inout Context) throws {

        context.mutateIfPresent(indexName) { (index: inout Self) in
            index.remove(entity)
        }
    }
}

private extension FullTextIndex.HashableValue {
    mutating func update(_ entity: Entity,
                         value: Value) {

        let existingValue = indexedValues[entity.id]

        guard existingValue != value else {
            return
        }

        if existingValue != nil {
            remove(entity)
        }

        let tokens = makeTokens(for: value)
        tokens.forEach { token in
            index[token, default: []].insert(entity.id)
        }

        totalLengthSum += tokens.count
        entitiesCount += 1
        indexedValues[entity.id] = value
        tokensForEntities[entity.id] = Set(tokens)
        tokenFrequenciesForEntities[entity.id] = tokens.reduce(into: [:]) { $0[$1, default: 0] += 1 }
        valueLenghtsForEntities[entity.id] = tokens.count

        averageValueLength = Double(totalLengthSum) / Double(max(1, entitiesCount))
    }

    mutating func remove(_ entity: Entity) {
        guard let tokens = tokensForEntities[entity.id]
         else {
            return
        }
        tokens.forEach { token in
            index[token]?.remove(entity.id)
            if index[token]?.isEmpty == true {
                index[token] = nil
            }
        }
        totalLengthSum -= valueLenghtsForEntities[entity.id] ?? 0
        entitiesCount -= 1
        averageValueLength = Double(totalLengthSum) / Double(max(1, entitiesCount))

        indexedValues[entity.id] = nil
        tokensForEntities[entity.id] = nil
        tokenFrequenciesForEntities[entity.id] = nil
        valueLenghtsForEntities[entity.id] = nil
    }
}

extension FullTextIndex.HashableValue where Value == String {
    func makeTokens(for value: Value) -> [String] {
        value.makeTokens()
    }
}

extension FullTextIndex.HashableValue where Value == [String] {
    func makeTokens(for value: Value) -> [String] {
        value.flatMap { $0.makeTokens() }
    }
}

extension FullTextIndex.HashableValue where Value: Hashable {
    func makeTokens(for value: Value) -> [String] {
        String(describing: value).makeTokens()
    }
}
