import Foundation
import Testing

import ServerApiDomain
import ServerStoreDomain
@testable import ServerApiPresentation

/// The lock, in front of the server rather than inside it.
///
/// **A decorator for the same reason `RebindingOnWake` is one**: whether this Mac may serve at all
/// is a question asked once, before anything binds, and answering it inside `ApiServerHost` would
/// put a store concern in the type whose one job is a socket. It is also the only shape in which
/// the refusal is a state the menu bar already knows how to receive.
@Suite("Store locking server host")
struct StoreLockingServerHostTests {

    @Test
    func `given nobody holds the document when the server runs then it serves as normal`() async {
        // given
        let endpoint = ServerEndpoint(host: "MacBook-Pro.local", port: 59_144)
        let sut = StoreLockingServerHost(
            host: FakeHost(states: [.starting, .running(endpoint)]),
            lock: FakeStoreLock(outcome: .acquired)
        )

        // when
        let states = await collect(sut)

        // then — the lock is invisible when it is free, which is every ordinary launch.
        #expect(states == [.starting, .running(endpoint)])
    }

    @Test
    func `given another process holds the document when the server runs then it refuses and names it`(
    ) async {
        // given — SPEC §9 line 810. Davide settled on 22 August 2026 that the second process
        // refuses rather than opening read-only: two processes disagreeing about what is switched
        // on, with a phone reading one of them, is worse than a Mac that says why it is not serving.
        let holder = StoreLockHolder(processIdentifier: 4213, processName: "granita-server")
        let sut = StoreLockingServerHost(
            host: FakeHost(states: [.starting, .running(ServerEndpoint(host: "nope", port: 1))]),
            lock: FakeStoreLock(outcome: .heldBy(holder))
        )

        // when
        let states = await collect(sut)

        // then
        #expect(states == [.blockedByAnotherProcess(holder)])
    }

    @Test
    func `given another process holds the document when the server runs then nothing binds at all`(
    ) async {
        // given — the refusal has to be *instead of* serving rather than beside it. A server that
        // bound anyway would be the second writer this lock exists to prevent, with a row on
        // Advanced explaining that it had not happened.
        let host = FakeHost(states: [.starting, .running(ServerEndpoint(host: "nope", port: 1))])
        let sut = StoreLockingServerHost(
            host: host,
            lock: FakeStoreLock(outcome: .heldBy(nil))
        )

        // when
        _ = await collect(sut)

        // then
        #expect(await host.runs == 0)
    }

    @Test
    func `given the holder cannot be read when the server runs then it still refuses`() async {
        // given — whether the lock is taken is the kernel's answer and who has it is a courtesy
        // read from a file. Losing the second must not soften the first.
        let sut = StoreLockingServerHost(
            host: FakeHost(states: [.starting]),
            lock: FakeStoreLock(outcome: .heldBy(nil))
        )

        // when
        let states = await collect(sut)

        // then
        #expect(states == [.blockedByAnotherProcess(nil)])
    }

    // MARK: -

    private func collect(_ host: some ServerHosting) async -> [ServerRunState] {
        var states: [ServerRunState] = []
        for await state in host.run() {
            states.append(state)
        }
        return states
    }
}

/// Yields what it was given and finishes, and counts whether it was asked at all — which is the
/// assertion the refusal turns on.
private actor FakeHost: ServerHosting {

    private(set) var runs = 0

    private let states: [ServerRunState]

    init(states: [ServerRunState]) {
        self.states = states
    }

    nonisolated func run() -> AsyncStream<ServerRunState> {
        AsyncStream { continuation in
            Task {
                await recordRun()
                for state in await states { continuation.yield(state) }
                continuation.finish()
            }
        }
    }

    private func recordRun() {
        runs += 1
    }
}

private struct FakeStoreLock: StoreLocking {

    let outcome: StoreLockOutcome

    func acquire() async -> StoreLockOutcome { outcome }
}
