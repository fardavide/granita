import AppKit
import Foundation

import ServerApiDomain
import ServerApiPresentation
import ServerIdentityData
import ServerIdentityDomain

/// The server the menu bar app runs: the same one the executable runs, under the identity in the
/// login Keychain.
///
/// A wrapper rather than a parameter on `ApiServerHost`, because the Keychain is asked **per run**.
/// A rebind after waking has to be able to fail for a reason someone can act on — a keychain that
/// is locked, or an identity deleted by hand between one bind and the next — and a configuration
/// built once at launch could only report that as the app never having started.
struct KeychainBackedServerHost: ServerHosting {

    let dependencies: ApiDependencies
    let serviceName: String
    let identities: KeychainServerIdentityStore

    func run() -> AsyncStream<ServerRunState> {
        AsyncStream { continuation in
            let serving = Task {
                continuation.yield(.starting)
                do {
                    let host = ApiServerHost(
                        configuration: ApiServerConfiguration(
                            dependencies: dependencies,
                            binding: .bonjourService(name: serviceName),
                            transport: .tls(try await identities.keychainIdentity().reference)
                        )
                    )
                    for await state in host.run() {
                        continuation.yield(state)
                    }
                } catch let refused as ServerIdentityError {
                    continuation.yield(.failed(reason: reason(for: refused)))
                } catch {
                    continuation.yield(.failed(reason: "\(error)"))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in serving.cancel() }
        }
    }

    /// In words rather than as a status code, because the person who can act on any of these is
    /// standing at this Mac and is reading a menu, not a log.
    private func reason(for error: ServerIdentityError) -> String {
        switch error {
        case .malformedSubject(let reason):
            "this Mac's name or addresses cannot go in a certificate: \(reason)"
        case .notSignable(let reason):
            "the identity could not be signed: \(reason)"
        case .keychainRefused(let operation, let status):
            "the Keychain refused while \(operation) (\(status)) — unlock the login keychain"
        case .identityUnusable(let reason):
            reason
        }
    }
}

/// The Mac waking up, as AppKit reports it.
///
/// **This is the whole reason `--insecure-http` is not the only way to debug a quiet server.** A
/// laptop that slept has lost its Bonjour advertisement, so the phone's list is empty and there is
/// nothing on screen anywhere to say why.
struct WorkspaceWakeNotifications: WakeNotifications {

    func wakes() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let observing = Task {
                let waking = NSWorkspace.shared.notificationCenter.notifications(
                    named: NSWorkspace.didWakeNotification
                )
                for await _ in waking {
                    continuation.yield(())
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in observing.cancel() }
        }
    }
}
