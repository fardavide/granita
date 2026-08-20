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
