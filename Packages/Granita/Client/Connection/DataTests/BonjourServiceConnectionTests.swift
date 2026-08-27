import Network
import Testing

import ClientConnectionDomain
@testable import ClientConnectionData

/// A connection says six things and exactly one of them is worth an address. Which is which decides
/// whether the six-word screen gets somewhere to send a code or a sentence about why it has nowhere,
/// so it is worth pinning away from the callback it is read in — that one only runs against a real
/// network.
@Suite("Bonjour service connection")
struct BonjourServiceConnectionTests {

    // MARK: - What each state asks of the stream

    @Test
    func `given a connection is coming up when it reports setup then there is nothing to say yet`() {
        // when - then
        #expect(BonjourServiceConnection.change(for: .setup, at: nil) == .nothingYet)
    }

    @Test
    func `given a connection is being made when it reports preparing then there is nothing to say yet`() {
        // when - then
        #expect(BonjourServiceConnection.change(for: .preparing, at: nil) == .nothingYet)
    }

    @Test
    func `given the Mac went away when the connection waits then that is the last thing it says`() {
        // given — a browse result outlives the Mac that published it by seconds, so this is what a
        // Mac that has just gone to sleep looks like from here.
        let error = NWError.dns(-72_004)

        // when - then — the opposite reading to the browser's, deliberately. A waiting browser is
        // alive and recovers on its own, so it is left alone; a waiting connection is a reader
        // watching a spinner with six words typed, and the earliest honest answer beats a longer
        // wait for the same one.
        #expect(
            BonjourServiceConnection.change(for: .waiting(error), at: nil)
                == .last(.lost(.unreachable(diagnostic: "\(error.localizedDescription)\nNWError -72004")))
        )
    }

    @Test
    func `given local network access is off when the connection waits then it is a refusal rather than a fault`() {
        // given — the code iOS reports when the app may not speak to the LAN at all. It arrives as a
        // wait rather than as a death, which is the whole reason waiting is read for it.
        let error = NWError.dns(-65570)

        // when - then — a different sentence and a different remedy: offering *Try Again* against a
        // permission that will never grant itself is the one piece of advice that cannot work.
        #expect(
            BonjourServiceConnection.change(for: .waiting(error), at: nil) == .last(.lost(.localNetworkDenied))
        )
    }

    @Test
    func `given a connection dies when it reports why then that is the last thing it says`() {
        // given
        let error = NWError.posix(.ECONNREFUSED)

        // when - then — nothing arrives on a connection past this, so the stream has to end or the
        // resolver waits out its whole patience for a connection that is already gone.
        #expect(
            BonjourServiceConnection.change(for: .failed(error), at: nil)
                == .last(.lost(.unreachable(diagnostic: "\(error.localizedDescription)\nNWError 61")))
        )
    }

    @Test
    func `given an unfamiliar dns error when the connection dies then the code goes with the sentence`() {
        // given — the resolver has many codes and only one of them is about permission.
        let error = NWError.dns(-65_563)

        // when - then — Network.framework's own sentence is true of every failure there has ever
        // been, so the raw code is the only part of it anybody can act on. Here the reader is the
        // developer.
        #expect(
            BonjourServiceConnection.change(for: .failed(error), at: nil)
                == .last(.lost(.unreachable(diagnostic: "\(error.localizedDescription)\nNWError -65563")))
        )
    }

    @Test
    func `given the resolver stopped waiting when the connection is cancelled then it ends with nothing to add`() {
        // when - then
        #expect(BonjourServiceConnection.change(for: .cancelled, at: nil) == .nothingMore)
    }

    // MARK: - What a ready connection's path amounts to

    @Test
    func `given a connection is up when its path carries a host and a port then that is where the Mac is`() {
        // given — what the system resolved the service to, which is the only reason this connection
        // was ever opened.
        let endpoint = NWEndpoint.hostPort(host: "192.168.1.24", port: 51_763)

        // when
        let change = BonjourServiceConnection.change(for: .ready, at: endpoint)

        // then
        #expect(change == .last(.reached(ServerAddress(host: "192.168.1.24", port: 51_763))))
    }

    @Test
    func `given a connection is up when its path carries an IPv6 address then that is where the Mac is`() {
        // given — what a network with no IPv4 on it resolves to. The literal is reported as the
        // system wrote it: bracketing belongs to the layer that builds a URL, and an address that
        // arrived pre-punctuated could not be compared against anything else.
        let endpoint = NWEndpoint.hostPort(host: "2001:db8::a1", port: 51_763)

        // when
        let change = BonjourServiceConnection.change(for: .ready, at: endpoint)

        // then
        #expect(change == .last(.reached(ServerAddress(host: "2001:db8::a1", port: 51_763))))
    }

    @Test
    func `given a connection is up when its path carries a link-local address then its zone comes with it`() {
        // given — the case that quietly cost this app a whole failure mode: a link-local address is
        // meaningless without the interface it is scoped to, so the zone travels with it and the
        // URL the pairing client builds is what has to know where to put it.
        let endpoint = NWEndpoint.hostPort(host: "fe80::1%en0", port: 51_763)

        // when
        let change = BonjourServiceConnection.change(for: .ready, at: endpoint)

        // then
        #expect(change == .last(.reached(ServerAddress(host: "fe80::1%en0", port: 51_763))))
    }

    @Test
    func `given a connection is up when its path still names the service then there is nowhere to send anything`() {
        // given — the endpoint the connection was made to, unresolved: a name, a type and a domain,
        // and no address anywhere in it.
        let endpoint = NWEndpoint.service(
            name: "Davide's MacBook Pro",
            type: "_granita._tcp",
            domain: "local.",
            interface: nil
        )

        // when
        let change = BonjourServiceConnection.change(for: .ready, at: endpoint)

        // then — the six words borrow a host and a port, and answering with anything else would hand
        // the pairing client an address it cannot dial.
        #expect(
            change == .last(.lost(.unreachable(diagnostic: "the connection came up without an address on its path")))
        )
    }

    @Test
    func `given a connection is up when it has no path at all then there is nowhere to send anything`() {
        // when - then — `currentPath` is optional and a ready connection with none is a state the
        // framework permits, so it is answered rather than force-unwrapped.
        #expect(
            BonjourServiceConnection.change(for: .ready, at: nil)
                == .last(.lost(.unreachable(diagnostic: "the connection came up without an address on its path")))
        )
    }

    // MARK: - What each change does to the stream

    @Test
    func `given there is nothing to say yet when it reaches the stream then it stays open`() async {
        // given — something put on the stream behind the change under test, so that "still open" is
        // asserted by what arrives rather than by waiting for something that never does.
        let next = EndpointResolution.reached(ServerAddress(host: "192.168.1.25", port: 51_764))

        // when
        let reported = await streamed(.nothingYet, followedBy: next)

        // then — a connection that is still preparing must not end the stream, or the resolver gives
        // up on a Mac that was about to answer.
        #expect(reported == [next])
    }

    @Test
    func `given a connection has answered when it reaches the stream then nothing follows it`() async {
        // given
        let address = ServerAddress(host: "192.168.1.24", port: 51_763)
        let next = EndpointResolution.reached(ServerAddress(host: "192.168.1.25", port: 51_764))

        // when
        let reported = await streamed(.last(.reached(address)), followedBy: next)

        // then — what came behind it is swallowed, which is what "the last thing it says" has to
        // mean.
        #expect(reported == [.reached(address)])
    }

    @Test
    func `given a connection was stopped on purpose when it reaches the stream then it ends saying nothing`() async {
        // given
        let next = EndpointResolution.reached(ServerAddress(host: "192.168.1.25", port: 51_764))

        // when
        let reported = await streamed(.nothingMore, followedBy: next)

        // then — the resolver reads an empty stream as "it never said where it was", so a cancelled
        // connection that put anything here would be an answer nobody observed.
        #expect(reported.isEmpty)
    }

    // MARK: - The part only a real network runs

    @Test(.timeLimit(.minutes(1)))
    func `given a real connection when it is cancelled then its stream ends without inventing an address`() async {
        // given — the one thing this drives for real. Nothing advertises the service on a build
        // machine, so what is asserted is the teardown, which does not depend on anything answering.
        let mac = DiscoveredServer(
            id: BonjourInstanceName(rawValue: "Davide's MacBook Pro"),
            name: "Davide's MacBook Pro"
        )
        let sut = BonjourServiceConnection(to: mac)

        // when
        let resolutions = sut.start()
        sut.cancel()

        // then — reaching the line after the loop is the assertion the resolver leans on: a
        // cancelled connection ends its stream rather than leaving a task waiting out its patience.
        // What it must never do is answer, because an address nobody observed is an address the
        // pairing handshake would be sent to.
        var reported: [EndpointResolution] = []
        for await resolution in resolutions {
            reported.append(resolution)
        }
        #expect(reported.contains { if case .reached = $0 { true } else { false } } == false)
    }
}

// MARK: -

/// Everything a change puts on a stream, with `next` offered behind it: a change that ended the
/// stream is one `next` never gets past, which is how "and nothing further will arrive" is asserted
/// by what does not come back rather than by waiting for something that never does.
private func streamed(
    _ change: ConnectionStateChange,
    followedBy next: EndpointResolution
) async -> [EndpointResolution] {
    let stream = AsyncStream<EndpointResolution> { continuation in
        change.apply(to: continuation)
        continuation.yield(next)
        continuation.finish()
    }
    var reported: [EndpointResolution] = []
    for await resolution in stream {
        reported.append(resolution)
    }
    return reported
}
