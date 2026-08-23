import AppKit

import ServerApiDomain

/// The Mac waking up, as AppKit reports it.
///
/// **This is the whole reason `--insecure-http` is not the only way to debug a quiet server.** A
/// laptop that slept has lost its Bonjour advertisement, so the phone's list is empty and there is
/// nothing on screen anywhere to say why.
///
/// Here rather than in the composition root, with the other conformers that read this Mac: the root
/// is exempt from the coverage rows, and a module exempt from being measured is the wrong place to
/// keep anything a test might want to reach. This one turned out to be reachable — the workspace's
/// notification centre is an ordinary one and a test may post to it — so it is judged rather than
/// exempted, which is the opposite of what moving it was expected to cost.
public struct WorkspaceWakeNotifications: WakeNotifications {

    public init() {}

    public func wakes() -> AsyncStream<Void> {
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
