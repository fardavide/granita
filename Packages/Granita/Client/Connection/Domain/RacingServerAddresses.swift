public struct RacingServerAddresses: ServerAddressResolving {

    private let addresses: any ServerAddressResolving
    private let macs: any RememberedMacStore
    private let localNetwork: any LocalNetworkAvailabilityChecking
    private let health: any PinnedServerHealthChecking
    private let timing: any ConnectionTimingRecording
    private let elapsedSince: @Sendable (ContinuousClock.Instant) -> Duration

    public init(
        addresses: any ServerAddressResolving,
        macs: any RememberedMacStore,
        localNetwork: any LocalNetworkAvailabilityChecking,
        health: any PinnedServerHealthChecking,
        timing: any ConnectionTimingRecording,
        elapsedSince: @escaping @Sendable (ContinuousClock.Instant) -> Duration = { $0.duration(to: ContinuousClock.now) }
    ) {
        self.addresses = addresses
        self.macs = macs
        self.localNetwork = localNetwork
        self.health = health
        self.timing = timing
        self.elapsedSince = elapsedSince
    }

    public func address(of server: DiscoveredServer) async throws(ServerAddressResolutionFailure) -> ServerAddress {
        try await address(of: server, reporting: { _ in })
    }

    public func address(
        of server: DiscoveredServer,
        reporting progress: @escaping @Sendable (WorktreeReadStage) async -> Void
    ) async throws(ServerAddressResolutionFailure) -> ServerAddress {
        let remembered: RememberedMac?
        do {
            remembered = try await macs.remembered(server.id)
        } catch {
            throw .unreachable(diagnostic: "the remembered Mac could not be read")
        }
        guard let remembered, let address = remembered.fallbackAddress else {
            await progress(.finding(.local))
            guard await localNetwork.availability() == .available else {
                await timing.record(.finished(.localDiscovery, duration: .zero, outcome: .skipped))
                throw .unreachable(diagnostic: "Wi-Fi is unavailable and this Mac has no saved remote address")
            }
            let address = try await discover(server)
            guard let remembered else {
                await progress(.reading(.unknown))
                return address
            }
            let verified = await verify(address, remembered: remembered, stage: .localVerification, reporting: progress)
            let resolved = try verified.get()
            await progress(.reading(.local))
            return resolved
        }
        let localAvailable = await localNetwork.availability() == .available
        await progress(.finding(localAvailable ? .localAndTailnet : .tailnet))
        let result = await withTaskGroup(of: Result<(address: ServerAddress, route: WorktreeConnectionRoute), ServerAddressResolutionFailure>.self) { group in
            group.addTask {
                await verify(address, remembered: remembered, stage: .tailnetVerification, reporting: progress)
                    .map { (address: $0, route: .tailnet) }
            }
            group.addTask {
                await localAddress(of: server, remembered: remembered, reporting: progress)
                    .map { (address: $0, route: .local) }
            }
            var lastFailure = ServerAddressResolutionFailure.unreachable(diagnostic: "no route completed pinned HTTPS verification")
            for await result in group {
                switch result {
                case .success:
                    group.cancelAll()
                    return result
                case .failure(let failure):
                    lastFailure = failure
                }
            }
            return .failure(lastFailure)
        }
        let resolved = try result.get()
        await progress(.reading(resolved.route))
        return resolved.address
    }

    private func localAddress(of server: DiscoveredServer, remembered: RememberedMac, reporting progress: @escaping @Sendable (WorktreeReadStage) async -> Void) async -> Result<ServerAddress, ServerAddressResolutionFailure> {
        guard await localNetwork.availability() == .available else {
            await timing.record(.finished(.localDiscovery, duration: .zero, outcome: .skipped))
            return .failure(.unreachable(diagnostic: "Wi-Fi is unavailable for local discovery"))
        }
        do {
            let address = try await discover(server)
            return await verify(address, remembered: remembered, stage: .localVerification, reporting: progress)
        } catch {
            return .failure(error)
        }
    }

    private func discover(_ server: DiscoveredServer) async throws(ServerAddressResolutionFailure) -> ServerAddress {
        let started = ContinuousClock.now
        await timing.record(.started(.localDiscovery))
        do {
            let address = try await addresses.address(of: server)
            await timing.record(.finished(.localDiscovery, duration: elapsedSince(started), outcome: .succeeded))
            return address
        } catch {
            await timing.record(.finished(.localDiscovery, duration: elapsedSince(started), outcome: Task.isCancelled ? .cancelled : .failed))
            throw error
        }
    }

    private func verify(_ address: ServerAddress, remembered: RememberedMac, stage: ConnectionStage, reporting progress: @escaping @Sendable (WorktreeReadStage) async -> Void) async -> Result<ServerAddress, ServerAddressResolutionFailure> {
        let started = ContinuousClock.now
        await timing.record(.started(stage))
        await progress(.verifying)
        do {
            _ = try await health.health(at: address, pinnedTo: remembered.fingerprint)
            await timing.record(.finished(stage, duration: elapsedSince(started), outcome: .succeeded))
            return .success(address)
        } catch {
            await timing.record(.finished(stage, duration: elapsedSince(started), outcome: error == .cancelled ? .cancelled : .failed))
            return .failure(.unreachable(diagnostic: "the route did not complete pinned HTTPS verification"))
        }
    }
}
