import CryptoKit
import Foundation

import CoreApiDomain
import CorePairingDomain
import ServerApiDomain
import ServerStoreDomain

/// Offers pairings and turns them into tokens.
///
/// An actor because a pairing is single use, and "check it then spend it" is exactly the sequence
/// two concurrent requests must not interleave — a code accepted twice is a second device paired
/// from one photograph of the same QR.
public actor Pairing {

    /// SPEC §8's window. Long enough to point a camera at a screen, short enough that a photograph
    /// of one is worthless by the time anyone finds it.
    ///
    /// The number itself lives one layer down, on the invitation, because the Devices tab fills a
    /// bar against it and cannot see this actor.
    public static let codeLifetime = PairingInvitation.lifetime

    private let store: any Store
    private let now: @Sendable () -> Date
    private var outstanding: [Offer] = []

    public init(store: any Store, now: @escaping @Sendable () -> Date) {
        self.store = store
        self.now = now
    }

    /// How many pairings are waiting to be redeemed. Read by a test; the housekeeping it checks is
    /// what stops a pairing sheet opened fifty times from leaving fifty live codes behind.
    public var outstandingCount: Int {
        outstanding.count
    }

    /// A fresh pairing: a code for the camera, and six words for when there is not one.
    ///
    /// **Two credentials, one pairing.** The words are not a rendering of the code — they are
    /// independently random, because a code short enough to read aloud is not a code long enough
    /// to put in a QR, and each is spent by redeeming either.
    public func invite() -> PairingCode {
        outstanding.removeAll { now().timeIntervalSince($0.offeredAt) > Self.codeLifetime }

        let offer = Offer(
            code: Self.randomHexadecimal(bytes: 16),
            spokenCode: SpokenWords.code(),
            offeredAt: now()
        )
        outstanding.append(offer)
        return PairingCode(
            code: offer.code,
            spokenCode: offer.spokenCode,
            expiresAt: offer.offeredAt.addingTimeInterval(Self.codeLifetime)
        )
    }

    /// Spends a pairing and returns the token to hand back, or says why not.
    ///
    /// Refuses in two distinguishable ways, which the wire deliberately does not repeat: an
    /// unauthenticated caller told apart "never a code" from "a code, too late" has an oracle for
    /// whether it is guessing in the right shape at all. The connection log carries the difference
    /// instead, where the only reader is the person standing at the Mac.
    public func redeem(
        code offered: String,
        deviceName: String,
        platform: String
    ) async throws(PairingRefusal) -> PairResponse {
        let typed = SpokenWords.normalised(offered)
        guard let index = outstanding.firstIndex(where: { $0.code == offered || $0.spokenCode == typed }) else {
            throw .noSuchCode
        }
        let offer = outstanding.remove(at: index)
        guard now().timeIntervalSince(offer.offeredAt) <= Self.codeLifetime else {
            throw .codeExpired
        }

        let token = Self.randomHexadecimal(bytes: 32)
        let device = StoredDevice(
            id: UUID().uuidString,
            name: deviceName,
            platform: platform,
            tokenHash: TokenHash.of(token),
            pairedAt: now()
        )
        do {
            try await store.add(device: device)
        } catch {
            throw .notRecordable(reason: reason(for: error))
        }
        return PairResponse(token: token, deviceId: device.id, serverInstanceId: Self.instanceId)
    }

    /// Stable for the life of this process, so a phone can tell the Mac it paired with from another
    /// one advertising the same service name.
    public static let instanceId = UUID().uuidString

    private func reason(for error: StoreError) -> String {
        switch error {
        case .notWritable(let reason): reason
        case .documentIsFromANewerVersion: "a newer version of Granita wrote this Mac's data"
        }
    }

    private static func randomHexadecimal(bytes count: Int) -> String {
        (0..<count).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()
    }

    /// One pairing, and both ways of spending it.
    private struct Offer {
        let code: String
        let spokenCode: String
        let offeredAt: Date
    }
}

/// What a phone is shown in order to pair.
public struct PairingCode: Hashable, Sendable {

    /// What the QR carries — long, and never typed by anyone.
    public let code: String

    /// Six words shown under it, for when the camera is unavailable. Redeems the same pairing.
    public let spokenCode: String

    public let expiresAt: Date

    public init(code: String, spokenCode: String, expiresAt: Date) {
        self.code = code
        self.spokenCode = spokenCode
        self.expiresAt = expiresAt
    }
}

public enum PairingRefusal: Error, Hashable, Sendable {

    /// Not a code this Mac issued — mistyped, meant for another Mac, or already spent.
    case noSuchCode

    /// A code this Mac did issue, offered after its two minutes were up.
    case codeExpired

    /// The pairing itself was fine and the device could not be written down, so it is refused
    /// rather than reported as paired — a phone holding a token this Mac has no record of is a
    /// phone that is quietly locked out forever.
    case notRecordable(reason: String)
}

// MARK: -

enum TokenHash {

    static func of(_ token: String) -> String {
        SHA256.hash(data: Data(token.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// Compares in time that does not depend on where the two differ.
    ///
    /// Both sides are fixed-width hexadecimal hashes rather than the tokens themselves, so this is
    /// belt and braces — but a comparison that returns early on the first wrong character leaks the
    /// prefix, and over a LAN that is a practical attack rather than a theoretical one.
    static func matches(_ candidate: String, _ known: String) -> Bool {
        let left = Array(candidate.utf8)
        let right = Array(known.utf8)
        guard left.count == right.count else { return false }
        var difference: UInt8 = 0
        for index in left.indices {
            difference |= left[index] ^ right[index]
        }
        return difference == 0
    }
}

/// Refuses a source that keeps guessing.
///
/// Per source address rather than globally, so one phone with a stale token cannot lock the others
/// out of a Mac.
public actor FailedAttempts {

    private static let window: TimeInterval = 60
    private static let allowed = 5

    private let now: @Sendable () -> Date
    private var attempts: [String: [Date]] = [:]

    public init(now: @escaping @Sendable () -> Date) {
        self.now = now
    }

    public func isBlocked(source: String) -> Bool {
        recent(source).count >= Self.allowed
    }

    public func record(source: String) {
        attempts[source] = recent(source) + [now()]
    }

    public func clear(source: String) {
        attempts[source] = nil
    }

    private func recent(_ source: String) -> [Date] {
        (attempts[source] ?? []).filter { now().timeIntervalSince($0) < Self.window }
    }
}
