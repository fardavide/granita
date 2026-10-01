import Foundation

import ClientConnectionData
import ClientConnectionDomain
import ClientConnectionPresentation
import ServerApiPresentation

@MainActor
final class MacRemoteComposition {
    let model: ClientConnectionModel
    let rememberedMacs: RememberedMacs
    let localInstance = BonjourInstanceName(rawValue: MachineName.computer)
    let device = PairingDevice(name: MachineName.computer, platform: "macOS")

    init(logs: ConnectionLogs, copyingLogs: any DiagnosticLogsCopying) {
        let store = KeychainRememberedMacStore()
        let waking = MagicPacketWake(
            datagrams: BroadcastDatagrams(destinations: BroadcastDatagrams.everywhereOnThisNetwork),
            ports: MagicPacketWake.conventionalPorts
        )
        let addresses = WakingServerAddresses(
            addresses: BonjourServerAddressResolver(),
            macs: store,
            waking: waking,
            patience: WakingServerAddresses.defaultPatience
        )
        let routes = RacingServerAddresses(
            addresses: addresses,
            macs: store,
            localNetwork: NetworkLocalNetworkAvailability(),
            health: HttpPinnedServerHealth(logs: logs),
            timing: logs
        )
        rememberedMacs = RememberedMacs(
            store: store,
            addresses: routes,
            connect: { mac in
                HttpGranitaRepository(
                    mac: mac,
                    transport: UrlSessionHttpTransport(pinnedTo: mac.fingerprint, logs: logs)
                )
            },
            healthOf: { address, fingerprint in
                try? await HttpServerPairing(
                    macReachableAt: address,
                    transport: UrlSessionHttpTransport(
                        pinnedTo: fingerprint,
                        logs: logs,
                        requestTimeout: .seconds(5)
                    )
                ).health()
            }
        )
        let camera = NoPairingCamera()
        model = ClientConnectionModel(
            browsing: ExcludingServerDiscovery(
                discovery: WakingServerDiscovery(
                    discovery: BonjourServerDiscovery(), macs: store, waking: waking
                ),
                instance: localInstance
            ),
            joining: MacPairing(macs: store, handshake: { attempt in
                if let pin = attempt.pin {
                    HttpServerPairing(
                        mac: attempt,
                        transport: UrlSessionHttpTransport(pinnedTo: pin, logs: logs)
                    )
                } else {
                    HttpServerPairing(
                        mac: attempt,
                        transport: UrlSessionHttpTransport(trustingFirstAnswer: (), logs: logs)
                    )
                }
            }),
            camera: camera,
            scanner: camera,
            addresses: addresses,
            copyingLogs: copyingLogs,
            settings: SystemSettingsOpener()
        )
    }
}
