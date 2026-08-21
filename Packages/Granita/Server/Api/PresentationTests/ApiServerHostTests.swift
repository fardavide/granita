import Foundation
import Testing

import ServerApiDomain
import ServerApiPresentation

/// Binds a real listener on loopback, which is the only way to learn what the menu bar item will
/// say. Every other test in this target drives the router in-process and never binds anything — and
/// that is exactly why the port reported to the status line was wrong until it was run for real.
@Suite("Api server host", .serialized)
struct ApiServerHostTests {

    @Test(.timeLimit(.minutes(1)))
    func `given a port the system chooses when the server binds then it reports the one it got`() async throws {
        // given — port 0 asks for whatever is free, which is the same question a Bonjour service
        // endpoint answers: the port is not knowable from the configuration.
        let host = ApiServerHost(
            configuration: ApiServerConfiguration(
                dependencies: ApiScenario.healthOnlyDependencies(serverVersion: "0.0.5"),
                binding: .hostname("127.0.0.1", port: 0),
                // Plaintext here on purpose: what this test is about is which port was bound, and
                // a TLS identity would need the Keychain, which a test binary does not have.
                transport: .insecurePlaintext
            )
        )

        // when — read through an iterator that stays in scope. Leaving a `for await` early drops
        // the stream, and dropping the stream is what tells the host to stop serving.
        var states = host.run().makeAsyncIterator()
        let first = await states.next()
        let second = await states.next()

        // then
        #expect(first == .starting)
        guard case .running(let bound)? = second else {
            Issue.record("expected the server to report where it bound, got \(String(describing: second))")
            return
        }
        #expect(bound.host == "127.0.0.1")
        #expect(bound.port > 0)

        // and then — the port it named is the port serving on it, which is the whole claim the
        // status line makes.
        let health = try await Data(
            contentsOf: URL(string: "http://127.0.0.1:\(bound.port)/v1/health")!
        )
        #expect(String(decoding: health, as: UTF8.self).contains("\"serverVersion\":\"0.0.5\""))
    }
}
