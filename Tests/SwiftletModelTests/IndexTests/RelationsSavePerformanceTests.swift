//
//  RelationsSavePerformanceTests.swift
//  SwiftletModel
//
//  Created by Serge Kazakov on 05/06/2026.
//

import SwiftletModel
import Foundation
import XCTest

/// Save benchmarks for an entity graph with relations.
///
/// Unlike the flat models used by `SortIndexPerformanceTests`, `Message` carries a rich relation
/// graph: a required to-one `author`, an optional to-one `chat` (with inverse), a cascade `attachment`,
/// a self-referential `replyTo`, and a many-to-many `viewedBy`. Saving it exercises the full write
/// path: normalization, recursive entity saves, bidirectional link maintenance, and index updates
/// across multiple entity types.
final class RelationsSavePerformanceTests: XCTestCase {
    var count: Int { 1000 }

    /// Shared pools so that the same `User`/`Chat` entities are referenced (and re-merged) across
    /// many messages — mirroring a realistic chat graph and stressing the repeated-insert path.
    lazy var users: [User] = (0..<50).map { Self.makeUser($0) }
    lazy var chats: [Chat] = (0..<20).map { Chat(id: "c\($0)") }

    /// Messages whose relations are embedded as full entities — the heaviest write path
    /// (recursive saves of author/chat/attachment/viewers plus inverse-link updates).
    lazy var messagesWithEntities: [Message] = (0..<count).map { makeMessageWithEntities($0) }.shuffled()

    /// Messages whose relations are stored as ids only — the light path that updates links
    /// without saving the related entities.
    lazy var messagesWithIds: [Message] = (0..<count).map { makeMessageWithIds($0) }.shuffled()

    /// Baseline: messages carrying only the required `author` relation (as an id), no other relations.
    lazy var flatMessages: [Message] = (0..<count).map { makeFlatMessage($0) }.shuffled()

    // MARK: - Factories

    private static func makeUser(_ idx: Int) -> User {
        User(id: "u\(idx)", name: "User \(idx)", username: "@user\(idx)", email: "user\(idx)@mail.com")
    }

    private func makeMessageWithEntities(_ idx: Int) -> Message {
        let attachment = Attachment(id: "a\(idx)", kind: .image(url: URL(string: "http://cdn.test/\(idx).jpg")!))
        let viewers: [User] = [
            users[idx % users.count],
            users[(idx + 1) % users.count],
            users[(idx + 2) % users.count]
        ]
        return Message(
            id: "\(idx)",
            text: "Message number \(idx)",
            timestamp: Date(timeIntervalSince1970: TimeInterval(idx)),
            author: .relation(users[idx % users.count]),
            chat: .relation(chats[idx % chats.count]),
            attachment: .relation(attachment),
            viewedBy: .relation(viewers)
        )
    }

    private func makeMessageWithIds(_ idx: Int) -> Message {
        let viewerIds: [User.ID] = [
            users[idx % users.count].id,
            users[(idx + 1) % users.count].id,
            users[(idx + 2) % users.count].id
        ]
        return Message(
            id: "\(idx)",
            text: "Message number \(idx)",
            timestamp: Date(timeIntervalSince1970: TimeInterval(idx)),
            author: .id(users[idx % users.count].id),
            chat: .id(chats[idx % chats.count].id),
            attachment: .id("a\(idx)"),
            viewedBy: .ids(viewerIds)
        )
    }

    private func makeFlatMessage(_ idx: Int) -> Message {
        Message(
            id: "\(idx)",
            text: "Message number \(idx)",
            timestamp: Date(timeIntervalSince1970: TimeInterval(idx)),
            author: .id(users[idx % users.count].id)
        )
    }

    /// The exact multiset of `User` saves that `author` + `viewedBy` trigger across all messages
    /// (1 author + 3 viewers per message = 4000 saves of 50 distinct users), with NO relation
    /// machinery. Saving these directly isolates the bare `User` entity cost from the link upkeep.
    lazy var authorAndViewerUserSaves: [User] = (0..<count).flatMap { idx -> [User] in
        [
            users[idx % users.count],
            users[idx % users.count],
            users[(idx + 1) % users.count],
            users[(idx + 2) % users.count]
        ]
    }

    /// The 1000 distinct attachments that the `attachment` relation saves, with no inverse link.
    lazy var bareAttachments: [Attachment] = (0..<count).map { idx in
        Attachment(id: "a\(idx)", kind: .image(url: URL(string: "http://cdn.test/\(idx).jpg")!))
    }

    // MARK: - Single-relation datasets
    //
    // Each message saves exactly ONE child entity (distinct per message → a single fresh insert),
    // with every other relation left `.none`. Comparing against a relation-free message isolates
    // the cost of one relation save, and the three child types show how child weight changes it.

    /// One-way to-one `author`, child `User` (4 indexes: 3 unique + 1 hash).
    lazy var singleAuthorMessages: [Message] = (0..<count).map { idx in
        Message(
            id: "\(idx)",
            text: "Message number \(idx)",
            timestamp: Date(timeIntervalSince1970: TimeInterval(idx)),
            author: .relation(Self.makeUser(idx))
        )
    }

    /// Mutual to-one `chat` (inverse `messages`), child `Chat` (no indexes).
    lazy var singleChatMessages: [Message] = (0..<count).map { idx in
        Message(
            id: "\(idx)",
            text: "Message number \(idx)",
            timestamp: Date(timeIntervalSince1970: TimeInterval(idx)),
            chat: .relation(Chat(id: "c\(idx)"))
        )
    }

    /// Mutual to-one cascade `attachment` (inverse `message`), child `Attachment` (1 hash index).
    lazy var singleAttachmentMessages: [Message] = (0..<count).map { idx in
        let attachment = Attachment(id: "a\(idx)", kind: .image(url: URL(string: "http://cdn.test/\(idx).jpg")!))
        return Message(
            id: "\(idx)",
            text: "Message number \(idx)",
            timestamp: Date(timeIntervalSince1970: TimeInterval(idx)),
            attachment: .relation(attachment)
        )
    }

    /// Reference: a message with NO relations at all (every relation `.none` — the init default).
    lazy var noRelationMessages: [Message] = (0..<count).map { idx in
        Message(
            id: "\(idx)",
            text: "Message number \(idx)",
            timestamp: Date(timeIntervalSince1970: TimeInterval(idx))
        )
    }

    /// `.none` vs explicit-empty: a mutual to-many `replies` set to `.relation([])`, rest `.none`.
    /// `.relation([])` takes the `.replace` path (`findChildrenOf` query) where `.none` takes `.append`.
    lazy var emptyRepliesMessages: [Message] = (0..<count).map { idx in
        Message(
            id: "\(idx)",
            text: "Message number \(idx)",
            timestamp: Date(timeIntervalSince1970: TimeInterval(idx)),
            replies: .relation([])
        )
    }

    /// A mutual to-one `chat` set to `.null` (explicit empty), rest `.none`. `.null` → `.replace` path.
    lazy var nullChatMessages: [Message] = (0..<count).map { idx in
        Message(
            id: "\(idx)",
            text: "Message number \(idx)",
            timestamp: Date(timeIntervalSince1970: TimeInterval(idx)),
            chat: .null
        )
    }

    // MARK: - Benchmarks

    /// Bare `User` saves at the same redundancy as `author` + `viewedBy`, without relation machinery.
    /// Compare against the per-relation ablation: if this ≈ author+viewedBy cost, `User` is the weight;
    /// if it's much cheaper, the relation/link machinery is the overhead.
    func test_BareUserSaves_SavePerformance() throws {
        let models = authorAndViewerUserSaves

        measure {
            var context = Context()
            try! models.forEach { try $0.save(to: &context) }
        }
    }

    /// Bare `Attachment` saves (no inverse `message` link). Compare against the `attachment` relation cost.
    func test_BareAttachmentSaves_SavePerformance() throws {
        let models = bareAttachments

        measure {
            var context = Context()
            try! models.forEach { try $0.save(to: &context) }
        }
    }

    func test_SingleRelation_NoRelations_SavePerformance() throws {
        let models = noRelationMessages
        measure {
            var context = Context()
            try! models.forEach { try $0.save(to: &context) }
        }
    }

    func test_SingleRelation_EmptyReplies_SavePerformance() throws {
        let models = emptyRepliesMessages
        measure {
            var context = Context()
            try! models.forEach { try $0.save(to: &context) }
        }
    }

    func test_SingleRelation_NullChat_SavePerformance() throws {
        let models = nullChatMessages
        measure {
            var context = Context()
            try! models.forEach { try $0.save(to: &context) }
        }
    }

    func test_SingleRelation_Chat_SavePerformance() throws {
        let models = singleChatMessages
        measure {
            var context = Context()
            try! models.forEach { try $0.save(to: &context) }
        }
    }

    func test_SingleRelation_Attachment_SavePerformance() throws {
        let models = singleAttachmentMessages
        measure {
            var context = Context()
            try! models.forEach { try $0.save(to: &context) }
        }
    }

    func test_SingleRelation_Author_SavePerformance() throws {
        let models = singleAuthorMessages
        measure {
            var context = Context()
            try! models.forEach { try $0.save(to: &context) }
        }
    }

    func test_RelationsAsEntities_SavePerformance() throws {
        let models = messagesWithEntities

        measure {
            var context = Context()
            try! models.forEach { try $0.save(to: &context) }
        }
    }

    func test_RelationsAsIds_SavePerformance() throws {
        let models = messagesWithIds

        measure {
            var context = Context()
            try! models.forEach { try $0.save(to: &context) }
        }
    }

    func test_FlatMessages_SavePerformance() throws {
        let models = flatMessages

        measure {
            var context = Context()
            try! models.forEach { try $0.save(to: &context) }
        }
    }
}
