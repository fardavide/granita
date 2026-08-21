import ServerApiDomain

/// Runs the server, and stands a new one up whenever the Mac wakes.
///
/// SPEC §9 asks for this in one sentence and it is the least visible thing in the milestone: a
/// laptop that slept is the single most likely reason the phone cannot reach the Mac, and there is
/// no screen anywhere in the fix. What was actually lost across a sleep is the Bonjour
/// advertisement — a phone that cannot find the Mac has nothing to tap and nothing to read.
///
/// **A cancelled `ServiceGroup` cannot be restarted**, which is the whole reason this is a wrapper
/// rather than a method. Waking means constructing a new `Application` and a new group, so the old
/// one is torn down and waited for before the new one asks for the port — two listeners racing for
/// one port ends with the second one failing to bind and the Mac staying unreachable.
public struct RebindingOnWake: ServerHosting {

    private let host: any ServerHosting
    private let wakes: any WakeNotifications

    public init(host: any ServerHosting, wakes: any WakeNotifications) {
        self.host = host
        self.wakes = wakes
    }

    public func run() -> AsyncStream<ServerRunState> {
        let host = host
        let wakes = wakes
        return AsyncStream { continuation in
            let rebinding = Task {
                var serving = Self.serve(host, into: continuation)
                for await _ in wakes.wakes() {
                    serving.cancel()
                    await serving.value
                    guard Task.isCancelled == false else { break }
                    serving = Self.serve(host, into: continuation)
                }
                serving.cancel()
                await serving.value
                continuation.finish()
            }
            continuation.onTermination = { _ in rebinding.cancel() }
        }
    }

    /// Forwards one server's states, and nothing else. Every state the menu bar draws comes from
    /// the server itself — including the `starting` a rebind produces, which is what makes a
    /// rebind visible without this type inventing a state of its own.
    private static func serve(
        _ host: any ServerHosting,
        into continuation: AsyncStream<ServerRunState>.Continuation
    ) -> Task<Void, Never> {
        Task {
            for await state in host.run() {
                continuation.yield(state)
            }
        }
    }
}
