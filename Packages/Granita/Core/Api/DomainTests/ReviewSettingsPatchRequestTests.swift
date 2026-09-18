import Foundation
import Testing

import CoreReviewDomain
@testable import CoreApiDomain

/// The patch that carries only what a reader changed.
///
/// **Three states on one key, and the whole safety of editing while the Mac is away rests on them**:
/// absent leaves the setting alone, null clears it, a value sets it. `decodeIfPresent` answers nil
/// for the first two alike, which is why this type decodes by asking whether the key is there.
@Suite("Review settings patch request")
struct ReviewSettingsPatchRequestTests {

    @Test
    func `given a key that is absent when decoded then the setting is left alone`() throws {
        // given — a phone that changed the label style and never read this Mac's opening line. The
        // patch must not carry an opinion about the line it has never seen.
        let json = #"{"identifier": "numbers"}"#

        // when
        let patch = try JSONDecoder().decode(
            ReviewSettingsPatchRequest.self,
            from: Data(json.utf8)
        )

        // then
        #expect(patch.openingLine == nil)
        #expect(patch.identifier == .numbers)
    }

    @Test
    func `given a key that is null when decoded then the setting is cleared rather than untouched`(
    ) throws {
        // given — Reset, which is the one thing that puts the built-in line back. It has to reach
        // the Mac as an instruction rather than as silence.
        let json = #"{"openingLine": null}"#

        // when
        let patch = try JSONDecoder().decode(
            ReviewSettingsPatchRequest.self,
            from: Data(json.utf8)
        )

        // then — `.some(nil)`: mentioned, and mentioned as nothing.
        #expect(patch.openingLine != nil)
        #expect(patch.openingLine ?? "unset" == nil)
        #expect(patch.identifier == nil)
    }

    @Test
    func `given a line cleared to empty when decoded then it is a value rather than an absence`(
    ) throws {
        // given — a review that begins at its first comment is a legal answer, and it is not the
        // same as never having chosen one.
        let json = #"{"openingLine": ""}"#

        // when
        let patch = try JSONDecoder().decode(
            ReviewSettingsPatchRequest.self,
            from: Data(json.utf8)
        )

        // then
        #expect(patch.openingLine == .some(""))
    }

    @Test
    func `given a patch that mentions nothing when encoded then it carries no keys at all`() throws {
        // given
        let patch = ReviewSettingsPatchRequest(openingLine: nil, identifier: nil)

        // when
        let json = try #require(String(data: try JSONEncoder().encode(patch), encoding: .utf8))

        // then — an empty object rather than two nulls, which would clear both settings.
        #expect(json == "{}")
    }

    @Test
    func `given a cleared line when encoded then the null survives the round trip`() throws {
        // given — the case an `encodeIfPresent` would silently drop, turning Reset into a request
        // that changes nothing.
        let patch = ReviewSettingsPatchRequest(openingLine: .some(nil), identifier: nil)

        // when
        let decoded = try JSONDecoder().decode(
            ReviewSettingsPatchRequest.self,
            from: try JSONEncoder().encode(patch)
        )

        // then
        #expect(decoded.openingLine != nil)
        #expect(decoded.openingLine ?? "unset" == nil)
    }

    @Test
    func `given both settings when encoded then both travel`() throws {
        // given
        let patch = ReviewSettingsPatchRequest(openingLine: .some("Mine."), identifier: .letters)

        // when
        let decoded = try JSONDecoder().decode(
            ReviewSettingsPatchRequest.self,
            from: try JSONEncoder().encode(patch)
        )

        // then
        #expect(decoded.openingLine == .some("Mine."))
        #expect(decoded.identifier == .letters)
    }
}
