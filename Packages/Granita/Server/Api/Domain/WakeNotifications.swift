/// Tells us the Mac woke up.
///
/// Behind a protocol for one reason: the only way to produce a real one is to close a laptop lid,
/// and the loop that consumes it — tear the old server down, wait for it, stand a new one up — is
/// the part with something to get wrong.
public protocol WakeNotifications: Sendable {

    /// Every time this Mac comes back from sleep, for as long as it is listened to.
    func wakes() -> AsyncStream<Void>
}
