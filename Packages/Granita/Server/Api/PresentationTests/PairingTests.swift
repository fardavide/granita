import Foundation
import Testing

import CoreApiDomain
import CorePairingDomain
import ServerApiPresentation
import ServerStoreDomain

/// One pairing, two ways in: the code the QR carries and the six words under it.
///
/// The words are not a display of the code — they are a second credential for the same pairing,
/// because a camera is exactly what is unavailable when someone needs this most. What both share
/// is the slot: spending either spends the pairing.
struct PairingTests {

    // MARK: - Issuing

    @Test func `when a pairing is offered then the words and the code are both usable`() async throws {
        // given
        let scenario = Scenario()

        // when
        let offered = await scenario.pairing.invite()

        // then
        #expect(offered.code.isEmpty == false)
        #expect(offered.spokenCode.split(separator: "-").count == 6)
    }

    @Test func `when a pairing is offered then it expires two minutes later`() async throws {
        // given
        let scenario = Scenario()

        // when
        let offered = await scenario.pairing.invite()

        // then
        // Long enough to point a camera at a screen, short enough that a photograph of one is
        // worthless by the time anyone finds it.
        #expect(offered.expiresAt.timeIntervalSince(scenario.clock.reading) == 120)
    }

    @Test func `when two pairings are offered then neither repeats the other`() async throws {
        // given
        let scenario = Scenario()

        // when
        let first = await scenario.pairing.invite()
        let second = await scenario.pairing.invite()

        // then
        #expect(first.code != second.code)
        #expect(first.spokenCode != second.spokenCode)
    }

    // MARK: - Redeeming

    @Test func `given an offered pairing when its code is redeemed then a device is recorded`() async throws {
        // given
        let scenario = Scenario()
        let offered = await scenario.pairing.invite()

        // when
        let paired = try await scenario.redeem(offered.code, as: "Davide's iPhone")

        // then
        let devices = await scenario.store.state().devices
        #expect(devices.map(\.name) == ["Davide's iPhone"])
        #expect(paired.deviceId == devices.first?.id)
    }

    @Test func `given an offered pairing when its words are redeemed then the same device is recorded`() async throws {
        // given
        let scenario = Scenario()
        let offered = await scenario.pairing.invite()

        // when
        let paired = try await scenario.redeem(offered.spokenCode, as: "Davide's iPad")

        // then
        // The whole reason the words exist: they are a credential, not a rendering of one.
        #expect(paired.token.isEmpty == false)
        #expect(await scenario.store.state().devices.map(\.name) == ["Davide's iPad"])
    }

    @Test func `given a pairing redeemed by its code when its words are offered then they are refused`() async throws {
        // given
        let scenario = Scenario()
        let offered = await scenario.pairing.invite()
        _ = try await scenario.redeem(offered.code, as: "first")

        // when - then
        // Both credentials name one pairing, so spending either spends it. Otherwise a QR
        // photographed over someone's shoulder still pairs after they have finished.
        await #expect(throws: PairingRefusal.noSuchCode) {
            try await scenario.redeem(offered.spokenCode, as: "second")
        }
    }

    @Test func `given a pairing that was already redeemed when it is offered again then it is refused`() async throws {
        // given
        let scenario = Scenario()
        let offered = await scenario.pairing.invite()
        _ = try await scenario.redeem(offered.code, as: "first")

        // when - then
        await #expect(throws: PairingRefusal.noSuchCode) {
            try await scenario.redeem(offered.code, as: "second")
        }
    }

    @Test func `given a code nobody issued when it is offered then it is refused as unknown`() async throws {
        // given
        let scenario = Scenario()

        // when - then
        await #expect(throws: PairingRefusal.noSuchCode) {
            try await scenario.redeem("not-a-code", as: "someone")
        }
    }

    @Test func `given a pairing older than two minutes when it is offered then it is refused as expired`() async throws {
        // given
        let scenario = Scenario()
        let offered = await scenario.pairing.invite()

        // when
        scenario.clock.advance(by: 121)

        // then
        // Told apart from an unknown code deliberately: the two mean different things to whoever
        // is standing at the Mac, and the connection log is where that difference is spent.
        await #expect(throws: PairingRefusal.codeExpired) {
            try await scenario.redeem(offered.code, as: "too slow")
        }
    }

    @Test func `given a pairing exactly at its expiry when it is offered then it is still accepted`() async throws {
        // given
        let scenario = Scenario()
        let offered = await scenario.pairing.invite()

        // when
        scenario.clock.advance(by: 120)

        // then
        _ = try await scenario.redeem(offered.code, as: "just in time")
        #expect(await scenario.store.state().devices.count == 1)
    }

    // MARK: - Typing the words

    @Test func `given words typed with spaces when they are offered then they are still accepted`() async throws {
        // given
        let scenario = Scenario()
        let offered = await scenario.pairing.invite()

        // when
        let typed = offered.spokenCode.replacingOccurrences(of: "-", with: " ")

        // then
        // Nobody types the hyphens. Refusing what a person reasonably reads off a screen would
        // make the fallback useless in exactly the situation it exists for.
        _ = try await scenario.redeem(typed, as: "typed with spaces")
        #expect(await scenario.store.state().devices.count == 1)
    }

    @Test func `given words typed in capitals and padded when they are offered then they are still accepted`() async throws {
        // given
        let scenario = Scenario()
        let offered = await scenario.pairing.invite()

        // when
        let typed = "  \(offered.spokenCode.uppercased())  "

        // then
        _ = try await scenario.redeem(typed, as: "typed loudly")
        #expect(await scenario.store.state().devices.count == 1)
    }

    // MARK: - The token

    @Test func `when a pairing is redeemed then the store keeps the token's hash and not the token`() async throws {
        // given
        let scenario = Scenario()
        let offered = await scenario.pairing.invite()

        // when
        let paired = try await scenario.redeem(offered.code, as: "Davide's iPhone")

        // then
        // A store that leaks is then a store that leaks nothing usable, and the only copy of the
        // token itself is in the phone's Keychain.
        let stored = try #require(await scenario.store.state().devices.first)
        #expect(stored.tokenHash != paired.token)
        #expect(stored.tokenHash.contains(paired.token) == false)
    }

    @Test func `given a store that refuses to write when a pairing is redeemed then it is not reported as paired`() async throws {
        // given
        let scenario = Scenario(storeFailure: .notWritable(reason: "the disk is full"))
        let offered = await scenario.pairing.invite()

        // when - then
        await #expect(throws: PairingRefusal.notRecordable(reason: "the disk is full")) {
            try await scenario.redeem(offered.code, as: "Davide's iPhone")
        }
    }

    // MARK: - Housekeeping

    @Test func `given many pairings nobody redeemed when another is offered then the expired ones are dropped`() async throws {
        // given
        let scenario = Scenario()
        for _ in 0..<10 {
            _ = await scenario.pairing.invite()
        }

        // when
        scenario.clock.advance(by: 121)
        let fresh = await scenario.pairing.invite()

        // then
        // Opening the pairing sheet is free and someone will do it fifty times. Nothing here is
        // large, but a list that only grows is a list that only grows.
        #expect(await scenario.pairing.outstandingCount == 1)
        #expect(fresh.code.isEmpty == false)
    }

    // MARK: -

    private struct Scenario {

        let clock = Clock()
        let store: FakeStore
        let pairing: Pairing

        init(storeFailure: StoreError? = nil) {
            store = FakeStore(failure: storeFailure)
            let clock = clock
            pairing = Pairing(store: store, now: { clock.reading })
        }

        func redeem(_ code: String, as name: String) async throws(PairingRefusal) -> PairResponse {
            try await pairing.redeem(code: code, deviceName: name, platform: "iOS")
        }
    }
}

// MARK: -

/// A clock a test moves by hand, so an expiry is asserted rather than waited for.
final class Clock: @unchecked Sendable {

    // Mutated only from the test's own thread before each read, and read through the `now` closure
    // the subject holds. There is no concurrency here for a lock to protect — the actor under test
    // is the only other participant and it never writes.
    private(set) var reading = Date(timeIntervalSince1970: 1_771_632_000)

    func advance(by seconds: TimeInterval) {
        reading = reading.addingTimeInterval(seconds)
    }
}
