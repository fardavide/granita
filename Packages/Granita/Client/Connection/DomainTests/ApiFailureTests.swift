import Foundation
import Testing

import ClientConnectionDomain

/// Which refusals carry the machine's own words, and which are answers rather than faults.
///
/// Asserted case by case because a screen prints this in small print under its own sentence: a
/// refusal that grew a diagnostic by accident would put "unauthorized" in a monospaced font under a
/// sentence that already said so.
@Suite("Api failure diagnostics")
struct ApiFailureTests {

    @Test(arguments: [
        ApiFailure.unauthorized,
        .pairingExpired,
        .rateLimited,
        .projectNotVisible,
        .worktreeGone,
        .fileGone,
        .staleContentHash,
        .tooLarge,
        .unsupportedApiVersion,
        // Not a refusal at all — this phone called the request off — and it carries no small print
        // for a stronger reason than the others: nothing is meant to be on screen to print it
        // under. A diagnostic here would be `Code=-999 "cancelled"` on a screen the reader reached
        // by pressing Back, which is what this case was made to stop.
        .cancelled
    ])
    func `given a refusal the Mac spells deliberately when read then it carries no small print`(
        failure: ApiFailure
    ) {
        // given - when - then
        #expect(failure.diagnostic == nil)
    }

    /// **A cancelled request is not a failure, and this is the rule that decides it.**
    ///
    /// It lives on the type rather than in the transport because a `URLSession` cannot be built in a
    /// test binary — so while this was a `catch` block it was a decision nothing could hold to its
    /// behaviour, and the behaviour was wrong: `NSURLErrorCancelled` was reported as the Mac being
    /// unreachable, which put *Could not read your Mac* on the screen a reader reached by pressing
    /// Back. Seen on a real iPhone.
    @Test
    func `given a request this phone called off when it is read then it is not the Mac being unreachable`() {
        // given - when - then
        #expect(ApiFailure.forTransport(URLError(.cancelled)) == .cancelled)
        #expect(ApiFailure.forTransport(CancellationError()) == .cancelled)
    }

    @Test
    func `given a failure this layer already understands when it is read then it passes through`() {
        // given — a refusal the Mac spelled deliberately must not be reworded as a network problem
        // on its way up.
        // when - then
        #expect(ApiFailure.forTransport(ApiFailure.unauthorized) == .unauthorized)
        #expect(ApiFailure.forTransport(ApiFailure.pairingExpired) == .pairingExpired)
    }

    @Test
    func `given a network failure when it is read then it is unreachable and keeps the system's words`() {
        // given — the diagnostic is small print rather than advice, which is why it is kept verbatim
        // and never put in a screen's description slot.
        // when
        let failure = ApiFailure.forTransport(URLError(.cannotConnectToHost))

        // then
        guard case .unreachable(let diagnostic) = failure else {
            Issue.record("a network failure has to read as the Mac being out of reach")
            return
        }
        #expect(diagnostic.isEmpty == false)
    }

    @Test(arguments: [
        (ApiFailure.gitFailure(message: "fatal: not a git repository"), "fatal: not a git repository"),
        (.badRequest(message: "contextLines must be between 0 and 20"), "contextLines must be between 0 and 20"),
        (.requestNotBuildable(diagnostic: "could not build a URL"), "could not build a URL"),
        (.unreachable(diagnostic: "NWError -65563"), "NWError -65563"),
        (.notUnderstood(diagnostic: "expected an object"), "expected an object")
    ])
    func `given a fault with words of its own when read then they are what is carried`(
        failure: ApiFailure,
        expected: String
    ) {
        // given - when - then
        #expect(failure.diagnostic == expected)
    }
}
