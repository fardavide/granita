import SwiftUI

import ClientConnectionDomain
import ClientConnectionUi
import ClientMacDomain

public struct MacSourceScreen<Content: View>: View {
    private let model: ClientConnectionModel
    private let localInstance: BonjourInstanceName
    private let device: PairingDevice
    private let reading: (MacSourceMenuView, @escaping (DiscoveredServer) -> Void) -> Content
    @Binding private var source: ReaderSource
    @State private var pairingServer: DiscoveredServer?

    public init(
        model: ClientConnectionModel,
        localInstance: BonjourInstanceName,
        device: PairingDevice,
        source: Binding<ReaderSource>,
        @ViewBuilder reading: @escaping (MacSourceMenuView, @escaping (DiscoveredServer) -> Void) -> Content
    ) {
        self.model = model
        self.localInstance = localInstance
        self.device = device
        _source = source
        self.reading = reading
    }

    public var body: some View {
        reading(
            MacSourceMenuView(
                source: source,
                menu: MacSourceMenu(
                    discovery: model.discovery,
                    remembered: model.rememberedServers,
                    excluding: localInstance
                ),
                remembered: Set(model.rememberedServers.map(\.id)),
                logCopyState: model.logCopyState,
                onChoose: { chosen in
                    model.chooseSource(chosen, onRead: { source = $0 }, onPair: beginPairing)
                },
                onSearchAgain: model.searchAgain,
                onOpenSettings: { model.openSettings(.localNetwork) },
                onCopyLogs: { Task { await model.copyLogs(context: .discovery(model.discovery)) } }
            ),
            beginPairing
        )
        .sheet(item: $pairingServer) { server in
            MacWordsPairingSheet(model: model, server: server, device: device) { mac in
                source = .remote(DiscoveredServer(id: mac.instance, name: mac.name))
                pairingServer = nil
            }
        }
        .task(id: model.attempt) { await model.start() }
    }

    private func beginPairing(_ server: DiscoveredServer) {
        model.beginPairing(with: server)
        pairingServer = server
    }
}
