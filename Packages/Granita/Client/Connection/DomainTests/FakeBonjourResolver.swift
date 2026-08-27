import Synchronization

import ClientConnectionDomain

/// Answers where a browsed Mac is, and counts how often it was asked.
///
/// **The count is the point of this one existing beside the Presentation module's own resolver.**
/// What the reconnection promises is that a Mac is looked up once and then kept, and that a read
/// which could not reach it throws the lookup away — neither of which is visible in the answer, only
/// in how many times the question was put.
final class FakeBonjourResolver: ServerAddressResolving {

    var lookups: Int { asked.withLock { $0 } }

    private let answering: Result<ServerAddress, ServerAddressResolutionFailure>
    private let asked = Mutex(0)

    init(answering: Result<ServerAddress, ServerAddressResolutionFailure>) {
        self.answering = answering
    }

    func address(of server: DiscoveredServer) async throws(ServerAddressResolutionFailure) -> ServerAddress {
        asked.withLock { $0 += 1 }
        switch answering {
        case .success(let address): return address
        case .failure(let failure): throw failure
        }
    }
}
