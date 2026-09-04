import Foundation
import Security

import ClientConnectionDomain
import CoreBrandingDomain

/// The phone's one copy of each Mac's pairing, in the Keychain.
///
/// **There is no second copy anywhere.** The Mac stores a hash of the token, so a pairing lost here
/// cannot be recovered from there and the reader has to pair again — which is why every failure to
/// write one is reported rather than shrugged at, and why this is the Keychain rather than a
/// preference file that a backup would carry to another device.
///
/// Nothing in a test constructs this. A SwiftPM test binary is unsigned and has no keychain of its
/// own, so exercising it would mean writing into a real one; it sits behind `RememberedMacStore` for
/// that reason, and everything downstream is tested against a fake. The same reasoning already
/// exempts the Mac's identity store, and the bar is the same: unrunnable by construction, never
/// merely untested. **What could be moved out of it has been** — the bytes of an item are
/// `RememberedMacRecord`'s and are asserted next door.
public struct KeychainRememberedMacStore: RememberedMacStore {

    /// One service for every Mac, with the Bonjour instance name as the account, so a phone paired
    /// with two Macs holds two items rather than overwriting one.
    private static let service = "\(Branding.bundleIdentifierPrefix).macs"

    /// Where 0.4.0 and earlier kept a bare token under the identifier the Mac issued.
    ///
    /// Those items are unreachable — nothing joins that identifier to a browse result, which is the
    /// defect this store's key exists to end — and each one is a live bearer token, since the Mac's
    /// device record outlives the launch that issued it. They are deleted rather than left, and the
    /// moment to do it is the one that proves the new format works.
    private static let supersededService = "\(Branding.bundleIdentifierPrefix).pairing"

    public init() {}

    public func remembered(
        _ mac: BonjourInstanceName
    ) async throws(RememberedMacStoreFailure) -> RememberedMac? {
        var query = Self.item(for: mac)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var found: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &found)
        switch status {
        case errSecSuccess:
            guard let data = found as? Data, let record = RememberedMacRecord.decoded(from: data) else {
                throw .unreadable
            }
            return record.remembered
        case errSecItemNotFound:
            // Never paired with that Mac. Not a failure — it is the state the app starts in.
            return nil
        default:
            throw .refused(status: status)
        }
    }

    public func remember(_ mac: PairedMac) async throws(RememberedMacStoreFailure) {
        guard let bytes = RememberedMacRecord(of: mac).encoded else {
            throw .unreadable
        }

        // Re-pairing with a Mac is an ordinary thing to do, so an existing item is replaced rather
        // than colliding: `SecItemAdd` answers `errSecDuplicateItem` and there is nothing useful to
        // tell a reader who has just successfully paired.
        let existing = Self.item(for: mac.instance)
        let updated = SecItemUpdate(existing as CFDictionary, [kSecValueData as String: bytes] as CFDictionary)
        if updated == errSecSuccess {
            Self.deleteWhatTheOldFormatLeft()
            return
        }
        guard updated == errSecItemNotFound else {
            throw .refused(status: updated)
        }

        var item = existing
        item[kSecValueData as String] = bytes
        // The phone must reach its Mac after a reboot without anyone unlocking anything, and a
        // pairing is worthless off this device: `ThisDeviceOnly` keeps it out of an iCloud backup
        // that would restore it onto a phone the Mac never paired with.
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let added = SecItemAdd(item as CFDictionary, nil)
        guard added == errSecSuccess else {
            throw .refused(status: added)
        }
        Self.deleteWhatTheOldFormatLeft()
    }

    public func forget(_ mac: BonjourInstanceName) async throws(RememberedMacStoreFailure) {
        let status = SecItemDelete(Self.item(for: mac) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw .refused(status: status)
        }
    }

    public func rememberedMacs() async throws(RememberedMacStoreFailure) -> Set<BonjourInstanceName> {
        // Attributes, never `kSecReturnData`: this answers a question about where a tap goes, and a
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
            return Set(
                items
                    .compactMap { $0[kSecAttrAccount as String] as? String }
                    .map(BonjourInstanceName.init(rawValue:))
            )
        case errSecItemNotFound:
            return []
        default:
            throw .refused(status: status)
        }
    }

    public func wakeAddresses() async throws(RememberedMacStoreFailure) -> [HardwareAddress] {
        // **This one does read the data**, unlike the enumeration above, because a hardware address
        // is stored inside the same item as the token — so there is no attribute-only query that
        // answers it. What comes back is narrowed to the addresses before it leaves this method, so
        // no credential crosses the boundary even though one was read to get here.
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var found: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &found)
        switch status {
        case errSecSuccess:
            guard let items = found as? [Data] else {
                throw .unreadable
            }
            // A record this version cannot read is skipped rather than thrown on: one unreadable
            // pairing must not cost the wake of every other Mac.
            return items
                .compactMap(RememberedMacRecord.decoded(from:))
                .flatMap(\.remembered.wakeAddresses)
        case errSecItemNotFound:
            return []
        default:
            throw .refused(status: status)
        }
    }

    /// Removes every item the superseded format wrote, and reports nothing.
    ///
    /// It runs after a successful write rather than at launch, because that is the point at which
    /// the reader demonstrably has a pairing in the shape this version can use — and because a
    /// Keychain call on every scene evaluation would be a cost paid forever for a migration that
    /// happens once. Its own failure is not the caller's business: the pairing that was just written
    /// down succeeded, and refusing to report that because some dead bytes survived would be a
    /// screen about the wrong thing.
    private static func deleteWhatTheOldFormatLeft() {
        SecItemDelete(
            [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: supersededService
            ] as CFDictionary
        )
    }

    private static func item(for mac: BonjourInstanceName) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: mac.rawValue
        ]
    }
}
