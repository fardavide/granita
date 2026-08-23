import Foundation
import Testing

import ServerApiDomain
import ServerApiPresentation
import ServerIdentityDomain

/// The wrapper that asks for a transport once per run rather than once per launch.
///
/// It lived in the menu bar app's composition root, where nothing could reach it: the per-run claim
/// its own comment makes was unassertable, and so was every one of the four sentences it produces
/// for a reader standing at the Mac.
@Suite("Transport resolving server host", .serialized)
struct TransportResolvingServerHostTests {

    @Test(.timeLimit(.minutes(1)))
    func `given a transport that resolves when the host runs then it reports where it bound`() async throws {
        // given — plaintext, because what this test is about is that a resolved transport reaches
        // the bind. A TLS identity would need the Keychain, which a test binary does not have.
        let host = TransportResolvingServerHost(
            dependencies: ApiScenario.healthOnlyDependencies(serverVersion: "0.0.14"),
            binding: .hostname("127.0.0.1", port: 0),
            transport: { .insecurePlaintext }
        )

        // when — through an iterator that stays in scope: dropping the stream stops the server.
        var states = host.run().makeAsyncIterator()
        let reached = await Self.statesUntilBound(&states)

        // then — starting arrives twice, and that is not a defect. This wrapper says it while the
        // transport is being resolved, which can take a Keychain unlock; the host it wraps says it
        // again while the port is being bound. Both are true and the icon draws the same thing.
        #expect(reached.first == .starting)
        guard case .running(let bound)? = reached.last else {
            Issue.record("expected the server to report where it bound, got \(reached)")
            return
        }
        #expect(bound.port > 0)
    }

    @Test(.timeLimit(.minutes(1)))
    func `given two runs when each binds then the transport is resolved once per run`() async throws {
        // given — the whole reason this is a wrapper rather than a parameter on the configuration.
        // A rebind after waking has to be able to fail for a reason someone can act on, which a
        // transport resolved once at launch could only report as the app never having started.
        let resolutions = Resolutions()
        let host = TransportResolvingServerHost(
            dependencies: ApiScenario.healthOnlyDependencies(serverVersion: "0.0.14"),
            binding: .hostname("127.0.0.1", port: 0),
            transport: {
                await resolutions.record()
                return .insecurePlaintext
            }
        )

        // when — each run is carried all the way to a bind, so what is counted is two servings
        // rather than two streams that were dropped before they asked anything.
        for _ in 0..<2 {
            var states = host.run().makeAsyncIterator()
            _ = await Self.statesUntilBound(&states)
        }

        // then
        #expect(await resolutions.count == 2)
    }

    @Test(arguments: [
        (
            ServerIdentityError.malformedSubject(reason: "the name is empty"),
            "this Mac's name or addresses cannot go in a certificate: the name is empty"
        ),
        (
            ServerIdentityError.notSignable(reason: "the key refused"),
            "the identity could not be signed: the key refused"
        ),
        (
            ServerIdentityError.keychainRefused(operation: "reading the identity", status: -25308),
            "the Keychain refused while reading the identity (-25308) — unlock the login keychain"
        ),
        (
            ServerIdentityError.identityUnusable(reason: "the certificate has no private key"),
            "the certificate has no private key"
        )
    ])
    func `given a refused identity when the host runs then it fails in words a reader can act on`(
        refusal: ServerIdentityError,
        expected: String
    ) async throws {
        // given
        let host = TransportResolvingServerHost(
            dependencies: ApiScenario.healthOnlyDependencies(serverVersion: "0.0.14"),
            binding: .hostname("127.0.0.1", port: 0),
            transport: { () async throws(ServerIdentityError) -> ApiTransport in throw refusal }
        )

        // when
        var states = host.run().makeAsyncIterator()
        _ = await states.next()
        let second = await states.next()

        // then
        #expect(second == .failed(reason: expected))
    }

    @Test(.timeLimit(.minutes(1)))
    func `given a refused identity when the host runs then the stream ends rather than hanging`() async throws {
        // given — a status item following a stream that never finishes shows "starting" forever.
        let host = TransportResolvingServerHost(
            dependencies: ApiScenario.healthOnlyDependencies(serverVersion: "0.0.14"),
            binding: .hostname("127.0.0.1", port: 0),
            transport: { () async throws(ServerIdentityError) -> ApiTransport in
                throw .identityUnusable(reason: "gone")
            }
        )

        // when
        var states = host.run().makeAsyncIterator()
        _ = await states.next()
        _ = await states.next()

        // then
        #expect(await states.next() == nil)
    }

    /// Reads states until the server says where it bound, or until it is clear it never will.
    ///
    /// The iterator is passed `inout` rather than returned: dropping the stream is what tells the
    /// host to stop serving, so it has to stay in the caller's scope.
    private static func statesUntilBound(
        _ states: inout AsyncStream<ServerRunState>.Iterator
    ) async -> [ServerRunState] {
        var reached: [ServerRunState] = []
        while reached.count < 4, let next = await states.next() {
            reached.append(next)
            if case .running = next { break }
        }
        return reached
    }
}

/// How many times the transport closure was asked. An actor because the closure is `@Sendable` and
/// runs on whatever executor the stream's task lands on.
private actor Resolutions {

    private(set) var count = 0

    func record() {
        count += 1
    }
}
