import SwiftUI
import Testing

import ClientConnectionDomain
import ClientConnectionPresentation

@Suite("Mac six-word pairing", .serialized)
@MainActor
struct MacWordsPairingScreenSnapshotTests {
    @Test(arguments: Subject.allCases, MacAppearance.all)
    func pairing(subject: Subject, appearance: MacAppearance) async throws {
        let server = DiscoveredServer(id: BonjourInstanceName(rawValue: "Mac Studio"), name: "Mac Studio")
        let device = PairingDevice(name: "Davide's MacBook Pro", platform: "macOS")
        let model = ClientConnectionModel(
            browsing: FakeMacPairingDiscovery(),
            joining: FakeMacPairingJoining(answering: subject.outcome),
            camera: FakeMacPairingCamera(),
            scanner: FakeMacPairingScanner(),
            addresses: FakeMacPairingAddressResolver(),
            copyingLogs: FakeDiagnosticLogsCopying(),
            settings: FakeMacPairingSettings()
        )
        model.beginPairing(with: server)
        model.typedWords = subject.words
        try await assertReaderSnapshot(
            MacWordsPairingScreen(model: model, server: server, device: device, onPaired: { _ in }),
            appearance: appearance,
            named: subject.rawValue,
            size: CGSize(width: 440, height: 460)
        ) {
            switch subject {
            case .empty, .partial, .complete, .unknownWord: break
            case .expired, .macBehind, .unanswered:
                await model.spendTypedWords(on: server, as: device)
                #expect(model.pairing == .finished(subject.outcome))
            }
        }
    }

    enum Subject: String, CaseIterable, Sendable, CustomTestStringConvertible {
        case empty = "empty-code"
        case partial = "two-words"
        case complete = "six-words-ready"
        case unknownWord = "unknown-word"
        case expired = "code-expired"
        case macBehind = "mac-behind"
        case unanswered = "code-spent-no-answer"

        var testDescription: String { rawValue }
        var words: String {
            switch self {
            case .empty: ""
            case .partial: "amber anchor"
            case .unknownWord: "amber anchorr"
            case .complete, .expired, .macBehind, .unanswered: "amber anchor apple arrow autumn bacon"
            }
        }
        var outcome: PairingOutcome {
            switch self {
            case .empty, .partial, .complete, .unknownWord, .expired: .refused(.pairingExpired)
            case .macBehind: .wrongContract(.macIsBehind(serving: 0))
            case .unanswered: .neverAnswered(.spendingTheCode)
            }
        }
    }
}
