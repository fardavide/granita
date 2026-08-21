import CryptoKit
import Foundation

import ServerStoreDomain

/// Issues one-time pairing codes and turns them into tokens.
///
/// An actor because a code is single use, and "check it then spend it" is exactly the sequence two
/// concurrent requests must not interleave — a code accepted twice is a second device paired from
/// one scan of the same QR.
public actor Pairing {

    /// SPEC §8's window. Long enough to point a camera at a screen, short enough that a photograph
    /// of one is worthless by the time anyone finds it.
    public static let codeLifetime: TimeInterval = 120

    private let store: any Store
    private let now: @Sendable () -> Date
    private var issued: [String: Date] = [:]

    public init(store: any Store, now: @escaping @Sendable () -> Date) {
        self.store = store
        self.now = now
    }

    /// A fresh code, and the six words that stand in for it when there is no camera.
    public func issueCode() -> (code: String, spokenCode: String) {
        let code = Self.randomHexadecimal(bytes: 16)
        issued[code] = now()
        return (code, Self.spoken(for: code))
    }

    /// Spends a code and returns the token to hand back, or refuses.
    public func redeem(
        code: String,
        deviceName: String,
        platform: String
    ) async throws(ApiError) -> PairResponse {
        guard let issuedAt = issued.removeValue(forKey: code),
              now().timeIntervalSince(issuedAt) <= Self.codeLifetime
        else {
            throw ApiError(.pairingExpired, message: "that pairing code has expired or was already used")
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
            throw ApiError(.gitFailure, message: "could not record the pairing: \(error)")
        }
        return PairResponse(token: token, deviceId: device.id, serverInstanceId: Self.instanceId)
    }

    /// Stable for the life of this process, so a phone can tell the Mac it paired with from another
    /// one advertising the same service name.
    public static let instanceId = UUID().uuidString

    private static func randomHexadecimal(bytes count: Int) -> String {
        (0..<count).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()
    }

    /// Six words from a code, for when the camera is unavailable.
    private static func spoken(for code: String) -> String {
        let words = ["amber", "basil", "cedar", "delta", "ember", "fjord", "glass", "harbor",
                     "indigo", "jasper", "kelp", "lantern", "meadow", "nectar", "opal", "pepper"]
        return code.prefix(6).map { character in
            words[Int(String(character), radix: 16) ?? 0]
        }.joined(separator: "-")
    }
}

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
