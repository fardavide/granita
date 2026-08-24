import ServerApiDomain
import ServerStoreDomain

/// The API server, behind SPEC §9's lock on the document.
///
/// **A wrapper rather than a check in a composition root**, for the reason every host decorator here
/// exists: a root is exempt from both coverage rows, and the refusal — the one branch that matters —
/// would be the part nothing could be asked about. It is also the only shape in which the refusal
/// arrives as a state the menu bar and General already know how to receive, instead of a second
/// property saying the same thing in different words.
///
/// **The lock is taken before anything binds, and nothing binds if it is not taken.** Serving anyway
/// with a row explaining that this had not happened is precisely the second writer the lock exists
/// to prevent.
public struct StoreLockingServerHost: ServerHosting {

    private let host: any ServerHosting
    private let lock: any StoreLocking

    public init(host: any ServerHosting, lock: any StoreLocking) {
        self.host = host
        self.lock = lock
    }

    public func run() -> AsyncStream<ServerRunState> {
        let host = host
        let lock = lock
        return AsyncStream { continuation in
            let serving = Task {
                switch await lock.acquire() {
                case .acquired:
                    for await state in host.run() {
                        continuation.yield(state)
                    }
                case .heldBy(let holder):
                    // No `.starting` before it. The server is not coming up, and a state that says
                    // it is — even for one frame — is the menu bar telling a reader to wait for
                    // something that will not arrive.
                    continuation.yield(.blockedByAnotherProcess(holder))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in serving.cancel() }
        }
    }
}
