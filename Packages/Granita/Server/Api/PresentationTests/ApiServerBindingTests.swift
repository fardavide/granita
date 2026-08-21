import Hummingbird
import Testing

import ServerApiPresentation

/// How the server is reachable, which is one decision with two very different consequences.
@Suite("Api server binding")
struct ApiServerBindingTests {

    @Test
    func `given a Bonjour binding when the application is built then it is built without binding a port`() {
        // given — the advertised path cannot be tested by connecting to it: the system chooses the
        // port and publishes the one it chose, so there is no number to predict. What is worth
        // asserting is that building the application succeeds at all, because the bootstrap
        // underneath fails hard rather than degrading when handed the wrong event loop group — and
        // that failure would otherwise first appear at launch.
        let configuration = ApiServerConfiguration(
            dependencies: ApiScenario.healthOnlyDependencies(serverVersion: "0.0.4"),
            binding: .bonjourService(name: "Davide's MacBook Pro")
        )

        // when - then
        _ = ApiServer.make(configuration: configuration)
    }

    @Test
    func `given a plain address when the application is built then it names the host and port asked for`() {
        // given — the escape hatch, and the only form reachable by typing an address.
        let configuration = ApiServerConfiguration(
            dependencies: ApiScenario.healthOnlyDependencies(serverVersion: "0.0.4"),
            binding: .hostname("127.0.0.1", port: 8737)
        )

        // when
        let application = ApiServer.make(configuration: configuration)

        // then
        #expect(application.configuration.address == .hostname("127.0.0.1", port: 8737))
    }
}
