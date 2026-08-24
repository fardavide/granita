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
        .unsupportedApiVersion
    ])
    func `given a refusal the Mac spells deliberately when read then it carries no small print`(
        failure: ApiFailure
    ) {
        // given - when - then
        #expect(failure.diagnostic == nil)
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
