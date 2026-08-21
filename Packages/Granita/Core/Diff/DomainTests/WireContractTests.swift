import Foundation
import Testing

@testable import CoreDiffDomain

/// These values are a contract, not an implementation detail. The Mac app and the phone app ship
/// independently, so a renamed case or a changed key is a version skew that decodes to nothing —
/// and the client branches on several of them.
@Suite("Wire contract")
struct WireContractTests {

    @Test
    func `given the file statuses when encoded then their names are exactly the agreed ones`() {
        // given - when
        let encoded = FileStatus.allCases.map(\.rawValue).sorted()

        // then — `copied` is deliberately absent: copy detection needs --find-copies, which is
        // expensive and never passed.
        #expect(encoded == [
            "added", "conflicted", "deleted", "modified", "renamed", "typeChanged", "untracked"
        ])
    }

    @Test
    func `given the diff line kinds when encoded then their names are exactly the agreed ones`() {
        // given - when
        let encoded = DiffLineKind.allCases.map(\.rawValue).sorted()

        // then
        #expect(encoded == ["addition", "conflictMarker", "context", "deletion", "noNewlineMarker"])
    }

    @Test
    func `given a diff line when round-tripped then it survives unchanged with camelCase keys`() throws {
        // given
        let line = DiffLine(
            kind: .addition,
            oldNumber: nil,
            newNumber: 42,
            text: "    let value = 1",
            displayColumns: 21,
            needsMeasurement: false,
            segments: [WordSegment(text: "value", isChanged: true)]
        )

        // when
        let data = try JSONEncoder().encode(line)
        let decoded = try JSONDecoder().decode(DiffLine.self, from: data)

        // then
        #expect(decoded == line)
        let keys = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        ).keys.sorted()
        #expect(keys == ["displayColumns", "kind", "needsMeasurement", "newNumber", "segments", "text"])
    }

    @Test
    func `given a line with no old number when encoded then the absent side is omitted, not null`() throws {
        // given — an addition has no old-side number, and the wire should say so by omission.
        let line = DiffLine(
            kind: .addition, oldNumber: nil, newNumber: 1,
            text: "x", displayColumns: 1, segments: nil
        )

        // when
        let object = try JSONSerialization.jsonObject(
            with: try JSONEncoder().encode(line)
        ) as? [String: Any]

        // then
        #expect(object?["oldNumber"] == nil)
        #expect(object?["segments"] == nil)
    }

    @Test
    func `given an identifier when encoded then it is a bare string rather than a wrapped object`() throws {
        // given
        let id = WorktreeID(rawValue: "0123456789abcdef0123456789abcdef")

        // when
        let encoded = String(decoding: try JSONEncoder().encode(id), as: UTF8.self)

        // then — the synthesised encoding of a one-field struct is `{"rawValue":"…"}`, and an
        // identifier is a string everywhere it is used: a path component in a URL, a key in a
        // dictionary of viewed state, a value the phone stores and hands back. The wrapper is a
        // compile-time distinction between three kinds of hash, not a shape the wire owes anyone.
        #expect(encoded == "\"0123456789abcdef0123456789abcdef\"")
    }

    @Test
    func `given an identifier written as a bare string when decoded then it round-trips`() throws {
        // given
        let json = Data("\"fedcba9876543210fedcba9876543210\"".utf8)

        // when
        let decoded = try JSONDecoder().decode(FileID.self, from: json)

        // then
        #expect(decoded == FileID(rawValue: "fedcba9876543210fedcba9876543210"))
    }

    @Test
    func `given a dictionary keyed by identifier when encoded then it is a JSON object`() throws {
        // given — how viewed state travels: a file identifier against what was seen.
        let viewed = [FileID(rawValue: "aaaabbbbccccddddaaaabbbbccccdddd"): "content-hash"]

        // when
        let encoded = try JSONEncoder().encode(viewed)

        // then — a dictionary whose key does not encode as a single string is written as a flat
        // array of alternating keys and values instead, which no other language's client would
        // read as a mapping.
        let object = try JSONSerialization.jsonObject(with: encoded) as? [String: String]
        #expect(object == ["aaaabbbbccccddddaaaabbbbccccdddd": "content-hash"])
    }

    @Test
    func `given a file change when round-tripped then it survives with camelCase keys`() throws {
        // given
        let change = FileChange(
            id: FileID(repositoryRelativePath: "src/renamed.txt"),
            path: "src/renamed.txt",
            oldPath: "src/original.txt",
            status: .renamed,
            isBinary: false,
            isSubmodule: false,
            stats: ChangeStats(filesChanged: 1, insertions: 3, deletions: 1),
            contentHash: String(repeating: "a", count: 64),
            estimatedLineCount: 12,
            isViewed: false,
            isTruncated: false,
            language: "text"
        )

        // when
        let data = try JSONEncoder().encode(change)

        // then
        #expect(try JSONDecoder().decode(FileChange.self, from: data) == change)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["id"] as? String == change.id.rawValue)
        #expect(object["oldPath"] as? String == "src/original.txt")
    }

    @Test
    func `given a file that was not renamed when encoded then the old path is omitted`() throws {
        // given
        let change = FileChange(
            id: FileID(repositoryRelativePath: "a.txt"),
            path: "a.txt",
            oldPath: nil,
            status: .modified,
            isBinary: false,
            isSubmodule: false,
            stats: ChangeStats(filesChanged: 1, insertions: 1, deletions: 0),
            contentHash: String(repeating: "b", count: 64),
            estimatedLineCount: 4,
            isViewed: true,
            isTruncated: false,
            language: nil
        )

        // when
        let object = try JSONSerialization.jsonObject(
            with: try JSONEncoder().encode(change)
        ) as? [String: Any]

        // then
        #expect(object?["oldPath"] == nil)
        #expect(object?["language"] == nil)
        #expect(object?["isViewed"] as? Bool == true)
    }

    @Test
    func `given change stats when summed then they add up across files`() {
        // given
        let stats = [
            ChangeStats(filesChanged: 1, insertions: 10, deletions: 2),
            ChangeStats(filesChanged: 1, insertions: 5, deletions: 8)
        ]

        // when
        let total = stats.reduce(.zero, +)

        // then
        #expect(total == ChangeStats(filesChanged: 2, insertions: 15, deletions: 10))
    }
}
