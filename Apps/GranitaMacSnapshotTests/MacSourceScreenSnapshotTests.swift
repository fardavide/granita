import SwiftUI
import Testing

import ClientConnectionDomain
import ClientConnectionPresentation
import ClientConnectionUi
import ClientMacDomain

@Suite("Mac source composition", .serialized)
@MainActor
struct MacSourceScreenSnapshotTests {
    @Test(arguments: Subject.allCases, MacAppearance.all)
    func source(subject: Subject, appearance: MacAppearance) async throws {
        let scenario = Scenario(subject: subject)
        try await assertReaderSnapshot(
            scenario.view,
            appearance: appearance,
            named: subject.rawValue,
            size: subject == .pairing ? CGSize(width: 1260, height: 800) : CGSize(width: 440, height: 160),
            capturesPresentedSheet: subject == .pairing
        ) {
            try await scenario.prepare()
        }
    }

    enum Subject: String, CaseIterable, Sendable, CustomTestStringConvertible {
        case thisMac = "this-mac"
        case remembered = "remembered-remote-mac"
        case pairing = "pairing-a-new-remote-mac"

        var testDescription: String { rawValue }
    }

    @MainActor
    private final class Scenario {
        let subject: Subject
        let server: DiscoveredServer
        let model: ClientConnectionModel
        private var onPair: ((DiscoveredServer) -> Void)?

        init(subject: Subject) {
            self.subject = subject
            let server = DiscoveredServer(id: BonjourInstanceName(rawValue: "granita-mac-studio"), name: "Mac Studio")
            self.server = server
            model = ClientConnectionModel(
                browsing: FakeMacPairingDiscovery(answering: .found(subject == .thisMac ? [] : [server])),
                joining: FakeMacPairingJoining(
                    answering: .refused(.pairingExpired),
                    remembered: subject == .remembered ? [server.id] : []
                ),
                camera: FakeMacPairingCamera(),
                scanner: FakeMacPairingScanner(),
                addresses: FakeMacPairingAddressResolver(),
                copyingLogs: FakeDiagnosticLogsCopying(),
                settings: FakeMacPairingSettings()
            )
        }

        func prepare() async throws {
            await model.start()
            switch subject {
            case .thisMac:
                #expect(model.discovery == .found([]))
            case .remembered:
                #expect(model.rememberedServers == [server])
            case .pairing:
                let pair = try #require(onPair)
                pair(server)
                #expect(model.pairing == .notStarted)
                #expect(model.typedWords.isEmpty)
            }
        }

        var view: some View {
            MacSourceScreen(
                model: model,
                localInstance: BonjourInstanceName(rawValue: "granita-this-mac"),
                device: PairingDevice(name: "Davide's MacBook Pro", platform: "macOS"),
                source: .constant(subject == .remembered ? .remote(server) : .thisMac)
            ) { menu, pair in
                self.content(menu, onPair: pair)
            }
        }

        private func content(_ menu: MacSourceMenuView, onPair: @escaping (DiscoveredServer) -> Void) -> some View {
            self.onPair = onPair
            return VStack(alignment: .leading) {
                menu
                Text("Choose a worktree to read its changes.")
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
