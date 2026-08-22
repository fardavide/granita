import ServiceManagement

import ServerMacDomain

/// The login item, through `SMAppService.mainApp`.
///
/// SPEC §9 names this API specifically. What earns it a module rather than two lines in the
/// composition root is what its status values mean: `SMAppService` reports four, and only
/// `.enabled` is "on". `.requiresApproval` is the one that matters most and is the easiest to read
/// as success — the registration was accepted, and the item will **not** run until someone approves
/// it in Login Items. For an app whose entire job is to be running when the phone looks, that is
/// indistinguishable from off.
///
/// So this reports `.requiresApproval` as not registered while letting `register()` succeed. The
/// pair is deliberate: the toggle shows what will actually happen at the next login, and turning it
/// on again is not treated as an error.
///
/// `SMAppService.mainApp` is read per call rather than stored. It is a reference type the SDK does
/// not declare `Sendable`, and holding one would mean vouching for that; asking for it each time
/// costs nothing and states no such thing.
public struct ServiceLoginItemRegistry: LoginItemRegistry {

    public init() {}

    public func isRegistered() async -> Bool {
        SMAppService.mainApp.status == .enabled
    }

    public func register() async throws(LoginItemFailure) {
        do {
            try SMAppService.mainApp.register()
        } catch {
            throw .refused(reason: error.localizedDescription)
        }
        // The status is re-read rather than assumed, and this is the whole reason this type exists.
        // A first registration normally lands on `.requiresApproval`: nothing threw, and nothing
        // will start at the next login either. Reporting that as success is the one failure mode
        // that a person discovers by rebooting and finding their phone cannot see this Mac.
        if SMAppService.mainApp.status != .enabled {
            throw .notApproved
        }
    }

    public func unregister() async throws(LoginItemFailure) {
        do {
            try await SMAppService.mainApp.unregister()
        } catch {
            throw .refused(reason: error.localizedDescription)
        }
    }
}
