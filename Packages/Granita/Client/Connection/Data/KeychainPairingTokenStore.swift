import Foundation
import Security

import ClientConnectionDomain
import CoreBrandingDomain

/// The phone's one copy of each Mac's token, in the Keychain.
///
/// **There is no second copy anywhere.** The Mac stores a hash, so a token lost here cannot be
/// recovered from there and the reader has to pair again — which is why every failure to write one
/// is reported rather than shrugged at, and why this is the Keychain rather than a preference file
/// that a backup would carry to another device.
///
/// Nothing in a test constructs this. A SwiftPM test binary is unsigned and has no keychain of its
/// own, so exercising it would mean writing into a real one; it sits behind `PairingTokenStore` for
/// that reason, and everything downstream is tested against a fake. The same reasoning already
/// exempts the Mac's identity store, and the bar is the same: unrunnable by construction, never
/// merely untested.
public struct KeychainPairingTokenStore: PairingTokenStore {

    /// One service for every Mac, with the instance identifier as the account, so a phone paired
    /// with two Macs holds two items rather than overwriting one.
    private static let service = "\(Branding.bundleIdentifierPrefix).pairing"

    public init() {}

    public func token(
        issuedBy server: ServerInstanceId
    ) async throws(PairingTokenStoreFailure) -> PairingToken? {
        var query = Self.item(for: server)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var found: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &found)
        switch status {
        case errSecSuccess:
            guard let data = found as? Data, let token = String(data: data, encoding: .utf8) else {
                throw .unreadable
            }
            return PairingToken(rawValue: token)
        case errSecItemNotFound:
            // Never paired with that Mac. Not a failure — it is the state the app starts in.
            return nil
        default:
            throw .refused(status: status)
        }
    }

    public func save(
        _ token: PairingToken,
        issuedBy server: ServerInstanceId
    ) async throws(PairingTokenStoreFailure) {
        // Re-pairing with a Mac is an ordinary thing to do, so an existing item is replaced rather
        // than colliding: `SecItemAdd` answers `errSecDuplicateItem` and there is nothing useful to
        // tell a reader who has just successfully paired.
        let existing = Self.item(for: server)
        let update = [kSecValueData as String: Data(token.rawValue.utf8)]
        let updated = SecItemUpdate(existing as CFDictionary, update as CFDictionary)
        if updated == errSecSuccess {
            return
        }
        guard updated == errSecItemNotFound else {
            throw .refused(status: updated)
        }

        var item = existing
        item[kSecValueData as String] = Data(token.rawValue.utf8)
        // The phone must reach its Mac after a reboot without anyone unlocking anything, and a
        // token is worthless off this device: `ThisDeviceOnly` keeps it out of an iCloud backup
        // that would restore it onto a phone the Mac never paired with.
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let added = SecItemAdd(item as CFDictionary, nil)
        guard added == errSecSuccess else {
            throw .refused(status: added)
        }
    }

    public func remove(issuedBy server: ServerInstanceId) async throws(PairingTokenStoreFailure) {
        let status = SecItemDelete(Self.item(for: server) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw .refused(status: status)
        }
    }

    public func pairedServers() async throws(PairingTokenStoreFailure) -> Set<ServerInstanceId> {
        // Attributes, never `kSecReturnData`: this answers a question about sorting a list, and a
        // query that came back with every token in it would be a credential handed to a view layer.
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var found: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &found)
        switch status {
        case errSecSuccess:
            guard let items = found as? [[String: Any]] else {
                throw .unreadable
            }
            return Set(items.compactMap { $0[kSecAttrAccount as String] as? String }.map(ServerInstanceId.init(rawValue:)))
        case errSecItemNotFound:
            return []
        default:
            throw .refused(status: status)
        }
    }

    private static func item(for server: ServerInstanceId) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: server.rawValue
        ]
    }
}
