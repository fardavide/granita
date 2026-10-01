import SwiftUI
import Testing

import ClientConnectionDomain
import ClientConnectionPresentation

@Suite("Mac source composition", .serialized)
@MainActor
struct MacSourceScreenSnapshotTests {
    @Test(arguments: MacAppearance.all)
    func source(appearance: MacAppearance) async throws {
        let model = ClientConnectionModel(
            browsing: FakeMacPairingDiscovery(),
            joining: FakeMacPairingJoining(answering: .refused(.pairingExpired)),
            camera: FakeMacPairingCamera(),
            scanner: FakeMacPairingScanner(),
            addresses: FakeMacPairingAddressResolver(),
            copyingLogs: FakeDiagnosticLogsCopying(),
            settings: FakeMacPairingSettings()
        )
        try await assertReaderSnapshot(
            MacSourceScreen(
                model: model,
                localInstance: BonjourInstanceName(rawValue: "granita-this-mac"),
                device: PairingDevice(name: "Davide's MacBook Pro", platform: "macOS"),
                source: .constant(.thisMac)
            ) { menu, _ in
                VStack(alignment: .leading) {
                    menu
                    Text("Choose a worktree to read its changes.")
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            },
            appearance: appearance,
            named: "this-mac",
            size: CGSize(width: 440, height: 160)
        ) {
            await model.start()
            #expect(model.discovery == .found([]))
        }
    }
}
