import ServerApiDomain

/// The two reasons this Mac stands its server up again, as one stream.
///
/// `RebindingOnWake` watches exactly one source and tears the old server down before the new one
/// asks for the port — which is the part that is easy to get wrong and is already right. A Restart
/// button is not a second mechanism, it is a second *reason*, so it arrives through the same seam
/// rather than through a method that would have to repeat the teardown ordering.
///
/// Deliberately not distinguished downstream. What a rebind does is identical either way, and the
/// `starting` state the reader sees comes from the server itself, so nothing here has to invent one.
public struct Rebinds: WakeNotifications, ServerRestarting {

    private let sleeping: any WakeNotifications
    private let asked: AsyncStream<Void>
    private let askedContinuation: AsyncStream<Void>.Continuation

    public init(wakes: any WakeNotifications) {
        sleeping = wakes
        (asked, askedContinuation) = AsyncStream<Void>.makeStream()
    }

    public func restart() async {
        askedContinuation.yield(())
    }

    public func wakes() -> AsyncStream<Void> {
        let sleeping = sleeping
        let asked = asked
        return AsyncStream { merged in
            let forwarding = Task {
                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        for await _ in sleeping.wakes() { merged.yield(()) }
                    }
                    group.addTask {
                        for await _ in asked { merged.yield(()) }
                    }
                }
                merged.finish()
            }
            merged.onTermination = { _ in forwarding.cancel() }
        }
    }
}
