import SwiftUI
import Testing

import ClientConnectionDomain
import ClientConnectionPresentation
import CorePairingDomain

@Suite("Mac six-word pairing", .serialized)
@MainActor
struct MacWordsPairingScreenSnapshotTests {
    @Test(arguments: Subject.allCases, MacAppearance.all)
    func pairing(subject: Subject, appearance: MacAppearance) async throws {
        let server = DiscoveredServer(id: BonjourInstanceName(rawValue: "Mac Studio"), name: "Mac Studio")
        let device = PairingDevice(name: "Davide's MacBook Pro", platform: "macOS")
        let model = ClientConnectionModel(
            browsing: FakeMacPairingDiscovery(),
            joining: FakeMacPairingJoining(
                answering: subject.outcome,
                pairingDelay: subject == .spending ? .seconds(3_600) : .zero,
                savingDelay: subject == .saving ? .seconds(3_600) : .zero
            ),
            camera: FakeMacPairingCamera(),
            scanner: FakeMacPairingScanner(),
            addresses: FakeMacPairingAddressResolver(answering: subject.address),
            copyingLogs: FakeDiagnosticLogsCopying(),
            settings: FakeMacPairingSettings()
        )
        model.beginPairing(with: server)
        model.typedWords = subject.words
        if subject == .unknownWord {
            #expect(model.firstUnknownWord == "anchorr")
        }
        var pending: Task<Void, Never>?
        defer { pending?.cancel() }
        try await assertReaderSnapshot(
            MacWordsPairingScreen(model: model, server: server, device: device, onPaired: { _ in }),
            appearance: appearance,
            named: subject.rawValue,
            size: CGSize(width: 440, height: 460)
        ) {
            switch subject {
            case .empty, .partial, .complete, .unknownWord: break
            case .spending:
                pending = Task { await model.spendTypedWords(on: server, as: device) }
                for _ in 0..<100 {
                    if model.pairing == .spending { break }
                    try await Task.sleep(for: .milliseconds(2))
                }
                #expect(model.pairing == .spending)
            case .saving:
                await model.spendTypedWords(on: server, as: device)
                pending = Task { await model.saveTokenAgain() }
                for _ in 0..<100 {
                    if model.pairing == .savingToken { break }
                    try await Task.sleep(for: .milliseconds(2))
                }
                #expect(model.pairing == .savingToken)
            case .unreachable, .permissionDenied:
                await model.spendTypedWords(on: server, as: device)
                if case .failure(let failure) = subject.address {
                    #expect(model.pairing == .notReached(failure))
                }
            case .expired, .macBehind, .unanswered, .phoneBehind, .agreedAndRefused,
                 .rateLimited, .unauthorized, .refusedDiagnostic, .keyNotSaved,
                 .contractUnanswered, .keyUnanswered:
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
        case phoneBehind = "reader-behind-without-testflight"
        case agreedAndRefused = "contract-agreed-and-refused"
        case rateLimited = "rate-limited"
        case unauthorized = "refused-plainly"
        case refusedDiagnostic = "refused-with-small-print"
        case keyNotSaved = "key-not-saved"
        case contractUnanswered = "contract-read-no-answer"
        case keyUnanswered = "key-write-no-answer"
        case unreachable = "mac-unreachable"
        case permissionDenied = "local-network-denied"
        case spending = "spending-the-code"
        case saving = "saving-the-key"

        var testDescription: String { rawValue }
        var words: String {
            switch self {
            case .empty: ""
            case .partial: "amber anchor"
            case .unknownWord: "amber anchorr apple"
            case .complete, .expired, .macBehind, .unanswered, .phoneBehind, .agreedAndRefused,
                 .rateLimited, .unauthorized, .refusedDiagnostic, .keyNotSaved,
                 .contractUnanswered, .keyUnanswered, .unreachable, .permissionDenied,
                 .spending, .saving: "amber anchor apple arrow autumn bacon"
            }
        }
        var outcome: PairingOutcome {
            switch self {
            case .empty, .partial, .complete, .unknownWord, .expired, .unreachable, .permissionDenied,
                 .spending: .refused(.pairingExpired)
            case .macBehind: .wrongContract(.macIsBehind(serving: 0))
            case .unanswered: .neverAnswered(.spendingTheCode)
            case .phoneBehind: .wrongContract(.phoneIsBehind(serving: 2))
            case .agreedAndRefused: .wrongContract(.sameContract)
            case .rateLimited: .refused(.rateLimited)
            case .unauthorized: .refused(.unauthorized)
            case .refusedDiagnostic: .refused(.notUnderstood(diagnostic: "POST /v1/pair\nunknown error code: device_quota"))
            case .keyNotSaved, .saving: .tokenNotStored(Self.pairedMac, .refused(status: -25_308))
            case .contractUnanswered: .neverAnswered(.readingTheContract)
            case .keyUnanswered: .neverAnswered(.writingTheKey(Self.pairedMac))
            }
        }

        var address: Result<ServerAddress, ServerAddressResolutionFailure> {
            switch self {
            case .unreachable: .failure(.unreachable(diagnostic: "NWError -65563"))
            case .permissionDenied: .failure(.localNetworkDenied)
            case .empty, .partial, .complete, .unknownWord, .expired, .macBehind, .unanswered,
                 .phoneBehind, .agreedAndRefused, .rateLimited, .unauthorized, .refusedDiagnostic,
                 .keyNotSaved, .contractUnanswered, .keyUnanswered, .spending, .saving:
                .success(ServerAddress(host: "Mac-Studio.local", port: 54_321))
            }
        }

        private static let pairedMac = PairedMac(
            instance: BonjourInstanceName(rawValue: "Mac Studio"),
            name: "Mac Studio",
            device: PairedDevice(
                token: PairingToken(rawValue: "snapshot-only-token"),
                deviceId: DeviceId(rawValue: "snapshot-device"),
                serverInstanceId: ServerInstanceId(rawValue: "snapshot-server")
            ),
            address: ServerAddress(host: "Mac-Studio.local", port: 54_321),
            fallbackAddress: nil,
            fingerprint: SpkiFingerprint(rawValue: "9dQ0mHXWiHc4T0uQr4nqe3sBEUqB1qkFqjNwr8SsCkI="),
            wakeAddresses: []
        )
    }
}
