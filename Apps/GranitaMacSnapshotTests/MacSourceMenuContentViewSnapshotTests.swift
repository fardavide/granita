import SwiftUI
import Testing

import ClientConnectionDomain
import ClientConnectionUi
import ClientMacDomain

@Suite("Mac reader source menu", .serialized)
@MainActor
struct MacSourceMenuContentViewSnapshotTests {

    @Test(arguments: Subject.all, MacAppearance.all)
    func sourceMenu(subject: Subject, appearance: MacAppearance) async throws {
        try await assertReaderSnapshot(
            VStack(alignment: .leading, spacing: 6) {
                MacSourceMenuContentView(
                    source: .thisMac,
                    menu: MacSourceMenu(
                        discovery: subject.discovery,
                        remembered: [],
                        excluding: BonjourInstanceName(rawValue: "granita-this-mac")
                    ),
                    remembered: subject.remembered,
                    logCopyState: subject.logCopyState,
                    onChoose: { _ in },
                    onSearchAgain: {},
                    onOpenSettings: {},
                    onCopyLogs: {}
                )
            }
            .buttonStyle(.plain)
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(nsColor: .windowBackgroundColor)),
            appearance: appearance,
            named: subject.name,
            size: CGSize(width: 360, height: 240)
        )
    }

    // MARK: -

    struct Subject: Sendable, CustomTestStringConvertible {

        let name: String
        let discovery: DiscoveryState
        let remembered: Set<BonjourInstanceName>
        let logCopyState: DiagnosticCopyState

        var testDescription: String { name }

        static let all: [Subject] = {
            let macBook = DiscoveredServer(
                id: BonjourInstanceName(rawValue: "granita-macbook-pro"),
                name: "MacBook Pro"
            )
            let studio = DiscoveredServer(
                id: BonjourInstanceName(rawValue: "granita-mac-studio"),
                name: "Mac Studio"
            )
            let workMac = DiscoveredServer(
                id: BonjourInstanceName(rawValue: "granita-work-macbook-pro"),
                name: "Davide's 16-inch MacBook Pro (work)"
            )

            return [
                Subject(name: "this-mac-alone", discovery: .found([]), remembered: [], logCopyState: .ready),
                Subject(
                    name: "one-unpaired-mac",
                    discovery: .found([studio]),
                    remembered: [], logCopyState: .ready
                ),
                Subject(
                    name: "several-macs-one-paired",
                    discovery: .found([macBook, studio, workMac]),
                    remembered: [macBook.id], logCopyState: .ready
                ),
                Subject(name: "searching", discovery: .searching, remembered: [], logCopyState: .ready),
                Subject(
                    name: "local-network-denied",
                    discovery: .localNetworkDenied,
                    remembered: [], logCopyState: .ready
                ),
                Subject(
                    name: "search-failed",
                    discovery: .failed(diagnostic: "NWError: -65555 PolicyDenied"),
                    remembered: [], logCopyState: .ready
                ),
                Subject(name: "search-failed-copying-logs", discovery: .failed(diagnostic: "NWError: -65555 PolicyDenied"), remembered: [], logCopyState: .copying),
                Subject(name: "search-failed-logs-copied", discovery: .failed(diagnostic: "NWError: -65555 PolicyDenied"), remembered: [], logCopyState: .copied),
                Subject(name: "search-failed-could-not-copy-logs", discovery: .failed(diagnostic: "NWError: -65555 PolicyDenied"), remembered: [], logCopyState: .failed)
            ]
        }()
    }
}
