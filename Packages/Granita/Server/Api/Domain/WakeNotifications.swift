/// Tells us the Mac woke up.
///
/// Behind a protocol for one reason: the only way to produce a real one is to close a laptop lid,
/// and the loop that consumes it — tear the old server down, wait for it, stand a new one up — is
/// the part with something to get wrong.
/// A rebind the person at the Mac asked for.
///
/// Separate from waking because the reasons differ, not the remedy. A laptop that changed network
/// keeps running and quietly stops being reachable, and there is no notification for that — so the
/// General tab's Restart is the only way back short of quitting the app.
public protocol ServerRestarting: Sendable {

    func restart() async
}

public protocol WakeNotifications: Sendable {

    /// Every time this Mac comes back from sleep, for as long as it is listened to.
    func wakes() -> AsyncStream<Void>
}
