import Testing

import CoreApiDomain
import CorePairingDomain

@testable import ClientConnectionDomain

@Suite("Racing server addresses")
struct RacingServerAddressesTests {

    @Test
    func `given a remembered tailnet Mac on cellular when resolving then its pinned route is used without asking Bonjour`() async throws {
        // given
        let server = DiscoveredServer(id: BonjourInstanceName(rawValue: "Remote MacBook Pro"), name: "Remote MacBook Pro")
        let tailnetAddress = ServerAddress(host: "100.81.42.98", port: 8_737)
        let fingerprint = SpkiFingerprint(rawValue: "remembered-mac-public-key")
        let scenario = Scenario(
            remembering: [server.id: RememberedMac(
                device: PairedDevice(token: PairingToken(rawValue: "remembered-phone-token"), deviceId: DeviceId(rawValue: "paired-phone"), serverInstanceId: ServerInstanceId(rawValue: "paired-remote-mac")),
                fingerprint: fingerprint, fallbackAddress: tailnetAddress, wakeAddresses: []
            )],
            localNetworkAvailability: .unavailable
        )

        // when
        let address = try await scenario.sut.address(of: server)

        // then
        #expect(address == tailnetAddress)
        #expect(scenario.addresses.lookups == 0)
        #expect(await scenario.health.invocations == [FakePinnedServerHealthChecking.Invocation(address: tailnetAddress, fingerprint: fingerprint)])
        let events = await scenario.timing.events
        #expect(events.contains(.finished(.localDiscovery, duration: .zero, outcome: .skipped)))
        #expect(events.contains(.started(.tailnetVerification)))
        #expect(events.contains(.finished(.tailnetVerification, duration: .milliseconds(123), outcome: .succeeded)))
    }

    @Test(.timeLimit(.minutes(1)))
    func `given a suspended Bonjour lookup when tailnet verifies then tailnet wins and cancels the local lookup`() async throws {
        // given
        let server = DiscoveredServer(id: BonjourInstanceName(rawValue: "Mac on another Wi-Fi network"), name: "Mac on another Wi-Fi network")
        let tailnetAddress = ServerAddress(host: "100.77.23.91", port: 8_737)
        let scenario = Scenario(
            remembering: [server.id: RememberedMac(
                device: PairedDevice(token: PairingToken(rawValue: "remote-review-token"), deviceId: DeviceId(rawValue: "review-phone"), serverInstanceId: ServerInstanceId(rawValue: "remote-review-mac")),
                fingerprint: SpkiFingerprint(rawValue: "remote-review-public-key"), fallbackAddress: tailnetAddress, wakeAddresses: []
            )],
            localNetworkAvailability: .available,
            suspendingLocalLookup: true
        )

        // when
        let address = try await scenario.sut.address(of: server)

        // then
        #expect(address == tailnetAddress)
        #expect(scenario.addresses.lookups == 1)
        #expect(scenario.addresses.cancelledLookups == 1)
        #expect(await scenario.timing.events.contains(.finished(.localDiscovery, duration: .milliseconds(123), outcome: .cancelled)))
    }

    @Test(.timeLimit(.minutes(1)))
    func `given a rejected LAN pin when tailnet verifies then the unverified local route cannot win`() async throws {
        // given
        let server = DiscoveredServer(id: BonjourInstanceName(rawValue: "Impostor LAN answer"), name: "Mac")
        let localAddress = ServerAddress(host: "impostor.local", port: 61_022)
        let tailnetAddress = ServerAddress(host: "100.65.78.91", port: 8_737)
        let fingerprint = SpkiFingerprint(rawValue: "genuine-mac-key")
        let scenario = Scenario(
            remembering: [server.id: RememberedMac(
                device: PairedDevice(token: PairingToken(rawValue: "token"), deviceId: DeviceId(rawValue: "phone"), serverInstanceId: ServerInstanceId(rawValue: "mac")),
                fingerprint: fingerprint, fallbackAddress: tailnetAddress, wakeAddresses: []
            )],
            localNetworkAvailability: .available,
            resolving: .success(localAddress),
            healthAnswers: [localAddress: .failure(.unreachable(diagnostic: "The pinned key did not match"))],
            healthWaitsForCalls: [tailnetAddress: localAddress]
        )

        // when
        let address = try await scenario.sut.address(of: server)

        // then
        #expect(address == tailnetAddress)
        #expect(await scenario.health.invocations.contains(FakePinnedServerHealthChecking.Invocation(address: localAddress, fingerprint: fingerprint)))
    }

    @Test
    func `given a remembered LAN only Mac on cellular when resolving then Bonjour is not attempted`() async {
        // given
        let server = DiscoveredServer(id: BonjourInstanceName(rawValue: "Legacy Mac"), name: "Mac")
        let scenario = Scenario(
            remembering: [server.id: RememberedMac(
                device: PairedDevice(token: PairingToken(rawValue: "token"), deviceId: DeviceId(rawValue: "phone"), serverInstanceId: ServerInstanceId(rawValue: "mac")),
                fingerprint: SpkiFingerprint(rawValue: "key"), fallbackAddress: nil, wakeAddresses: []
            )],
            localNetworkAvailability: .unavailable
        )

        // when
        await #expect(throws: ServerAddressResolutionFailure.self) {
            try await scenario.sut.address(of: server)
        }

        // then
        #expect(scenario.addresses.lookups == 0)
        #expect(await scenario.health.invocations.isEmpty)
    }

    @Test(.timeLimit(.minutes(1)))
    func `given a suspended waking LAN lookup when tailnet wins then cancellation sends no wake packets`() async throws {
        // given
        let server = DiscoveredServer(id: BonjourInstanceName(rawValue: "Awake tailnet Mac"), name: "Mac")
        let scenario = Scenario(
            remembering: [server.id: RememberedMac(
                device: PairedDevice(token: PairingToken(rawValue: "token"), deviceId: DeviceId(rawValue: "phone"), serverInstanceId: ServerInstanceId(rawValue: "mac")),
                fingerprint: SpkiFingerprint(rawValue: "key"), fallbackAddress: ServerAddress(host: "100.88.34.76", port: 8_737),
                wakeAddresses: HardwareAddress.all(in: ["3e:2d:c6:c3:4b:fe"])
            )],
            localNetworkAvailability: .available,
            suspendingLocalLookup: true,
            usingWakeRetries: true
        )

        // when
        _ = try await scenario.sut.address(of: server)

        // then
        #expect(scenario.addresses.cancelledLookups == 1)
        #expect(await scenario.waking.woken.isEmpty)
    }

    @Test(arguments: [ApiFailure.unreachable(diagnostic: "Tailnet disconnected"), .cancelled])
    func `given failed tailnet verification on Wi-Fi when LAN verifies then LAN wins`(failure: ApiFailure) async throws {
        // given
        let server = DiscoveredServer(id: BonjourInstanceName(rawValue: "Nearby Mac"), name: "Mac")
        let local = ServerAddress(host: "nearby.local", port: 61_045)
        let remote = ServerAddress(host: "100.74.25.89", port: 8_737)
        let scenario = Scenario(
            remembering: [server.id: RememberedMac(
                device: PairedDevice(token: PairingToken(rawValue: "token"), deviceId: DeviceId(rawValue: "phone"), serverInstanceId: ServerInstanceId(rawValue: "mac")),
                fingerprint: SpkiFingerprint(rawValue: "key"), fallbackAddress: remote, wakeAddresses: []
            )],
            localNetworkAvailability: .available,
            resolving: .success(local),
            healthAnswers: [remote: .failure(failure)],
            healthWaitsForCalls: [local: remote]
        )

        // when
        let address = try await scenario.sut.address(of: server)

        // then
        #expect(address == local)
        #expect(await scenario.timing.events.contains(.finished(.localVerification, duration: .milliseconds(123), outcome: .succeeded)))
    }

    @Test
    func `given both pinned routes fail when resolving then no route is returned`() async {
        // given
        let server = DiscoveredServer(id: BonjourInstanceName(rawValue: "Unreachable Mac"), name: "Mac")
        let local = ServerAddress(host: "unreachable.local", port: 61_056)
        let remote = ServerAddress(host: "100.79.24.87", port: 8_737)
        let scenario = Scenario(
            remembering: [server.id: RememberedMac(
                device: PairedDevice(token: PairingToken(rawValue: "token"), deviceId: DeviceId(rawValue: "phone"), serverInstanceId: ServerInstanceId(rawValue: "mac")),
                fingerprint: SpkiFingerprint(rawValue: "key"), fallbackAddress: remote, wakeAddresses: []
            )],
            localNetworkAvailability: .available,
            resolving: .success(local),
            healthAnswers: [local: .failure(.unreachable(diagnostic: "LAN failed")), remote: .failure(.unreachable(diagnostic: "Tailnet failed"))]
        )

        // when
        await #expect(throws: ServerAddressResolutionFailure.self) { try await scenario.sut.address(of: server) }

        // then
        #expect(await scenario.health.invocations.count == 2)
    }

    @Test
    func `given denied local networking and failed tailnet when resolving then no local health is sent`() async {
        // given
        let server = DiscoveredServer(id: BonjourInstanceName(rawValue: "Permission blocked Mac"), name: "Mac")
        let remote = ServerAddress(host: "100.89.64.27", port: 8_737)
        let scenario = Scenario(
            remembering: [server.id: RememberedMac(
                device: PairedDevice(token: PairingToken(rawValue: "token"), deviceId: DeviceId(rawValue: "phone"), serverInstanceId: ServerInstanceId(rawValue: "mac")),
                fingerprint: SpkiFingerprint(rawValue: "key"), fallbackAddress: remote, wakeAddresses: []
            )],
            localNetworkAvailability: .available,
            resolving: .failure(.localNetworkDenied),
            healthAnswers: [remote: .failure(.unreachable(diagnostic: "Tailnet disconnected"))]
        )

        // when
        await #expect(throws: ServerAddressResolutionFailure.self) { try await scenario.sut.address(of: server) }

        // then
        #expect(scenario.addresses.lookups == 1)
        #expect(await scenario.health.invocations.count == 1)
    }

    @Test
    func `given an unremembered Mac on Wi-Fi when resolving then LAN remains available for pairing`() async throws {
        // given
        let local = ServerAddress(host: "new-mac.local", port: 61_067)
        let scenario = Scenario(remembering: [:], localNetworkAvailability: .available, resolving: .success(local))

        // when
        let address = try await scenario.sut.address(of: DiscoveredServer(id: BonjourInstanceName(rawValue: "New Mac"), name: "Mac"))

        // then
        #expect(address == local)
        #expect(await scenario.health.invocations.isEmpty)
    }

    @Test
    func `given refused pairing storage when resolving then neither route is attempted`() async {
        // given
        let scenario = Scenario(remembering: [:], localNetworkAvailability: .available, storeRefusing: .refused(status: -25_308))

        // when
        await #expect(throws: ServerAddressResolutionFailure.self) {
            try await scenario.sut.address(of: DiscoveredServer(id: BonjourInstanceName(rawValue: "Locked Mac"), name: "Mac"))
        }

        // then
        #expect(scenario.addresses.lookups == 0)
        #expect(await scenario.health.invocations.isEmpty)
    }

    private struct Scenario {
        let sut: RacingServerAddresses
        let addresses: FakeBonjourResolver
        let health: FakePinnedServerHealthChecking
        let waking: FakeMacWaking
        let timing: FakeConnectionTimingRecording

        init(remembering: [BonjourInstanceName: RememberedMac], localNetworkAvailability: LocalNetworkAvailability, suspendingLocalLookup: Bool = false, resolving: Result<ServerAddress, ServerAddressResolutionFailure> = .failure(.unreachable(diagnostic: "Bonjour must not be asked on cellular")), healthAnswers: [ServerAddress: Result<HealthResponse, ApiFailure>] = [:], healthWaitsForCalls: [ServerAddress: ServerAddress] = [:], usingWakeRetries: Bool = false, storeRefusing: RememberedMacStoreFailure? = nil) {
            timing = FakeConnectionTimingRecording()
            addresses = FakeBonjourResolver(answering: resolving, suspendingLookup: suspendingLocalLookup)
            waking = FakeMacWaking()
            health = FakePinnedServerHealthChecking(
                answering: HealthResponse(name: "Granita", apiVersion: 1, serverVersion: "0.11.2", tailnetEndpoint: nil, wakeAddresses: []),
                answers: healthAnswers,
                waitingFor: healthWaitsForCalls,
                beforeAnswering: { [addresses] in
                    if suspendingLocalLookup { await addresses.waitUntilAsked() }
                }
            )
            let macs = storeRefusing.map(FakeRememberedMacStore.init(refusing:)) ?? FakeRememberedMacStore(holding: remembering)
            let localAddresses: any ServerAddressResolving
            if usingWakeRetries {
                localAddresses = WakingServerAddresses(addresses: addresses, macs: macs, waking: waking, patience: [])
            } else {
                localAddresses = addresses
            }
            sut = RacingServerAddresses(
                addresses: localAddresses,
                macs: macs,
                localNetwork: FakeLocalNetworkAvailabilityChecking(answering: localNetworkAvailability),
                health: health,
                timing: timing,
                elapsedSince: { _ in .milliseconds(123) }
            )
        }
    }
}
