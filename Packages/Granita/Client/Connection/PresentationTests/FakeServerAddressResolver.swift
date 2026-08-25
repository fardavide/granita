import ClientConnectionDomain

/// Answers where a browsed Mac is, or why it could not be found.
///
/// A `Result` rather than two initialisers, because both endings matter to the same screen: six
/// typed words that cannot be sent anywhere and six that can differ only here, and the failing half
/// is the one design §5 gives a button to.
struct FakeServerAddressResolver: ServerAddressResolving {

    let answering: Result<ServerAddress, ServerAddressResolutionFailure>

    func address(of server: DiscoveredServer) async throws(ServerAddressResolutionFailure) -> ServerAddress {
        switch answering {
        case .success(let address): return address
        case .failure(let failure): throw failure
        }
    }
}
