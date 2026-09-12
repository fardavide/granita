import Testing

import ClientConnectionDomain
import CorePairingDomain

@Suite("Copy diagnostic logs")
struct CopyDiagnosticLogsTests {

    @Test
    func `given a diagnostic report when logs are copied then the complete report reaches the pasteboard`() async throws {
        // given
        let report = "Granita 0.11.0\nNSURLErrorDomain (-1200)"
        let scenario = Scenario(report: report)

        // when
        try await scenario.sut.copy(context: .discovery(.idle))

        // then
        #expect(await scenario.pasteboard.lastCopy() == report + "\n\nCurrent screen: discovery\nState: idle")
    }

    @Test(arguments: ContextCase.allCases)
    private func `given a current screen failure when logs are copied then useful context is included without private payloads`(
        subject: ContextCase
    ) async throws {
        // given
        let report = "Granita 0.11.0\nNSURLErrorDomain (-1200)"
        let privateDiagnostic = "Bearer private-token; pairing-code cabin-cactus-camera-candle-harbour-lantern; source let privateKey = 42"
        let privateStderr = "fatal: cannot read /Users/private-person/private-project/secret-source.swift"
        let context: DiagnosticContext
        let expectedContext: String
        switch subject {
        case .keychainRefused:
            context = .pairing(.finished(.tokenNotStored(
                PairedMac(
                    instance: BonjourInstanceName(rawValue: "private-mac-identity"),
                    name: "private-mac-name",
                    device: PairedDevice(
                        token: PairingToken(rawValue: "private-bearer-token"),
                        deviceId: DeviceId(rawValue: "private-device-id"),
                        serverInstanceId: ServerInstanceId(rawValue: "private-server-id")
                    ),
                    address: ServerAddress(host: "private-mac.local", port: 8737),
                    fallbackAddress: nil,
                    fingerprint: SpkiFingerprint(rawValue: "private-pin"),
                    wakeAddresses: []
                ),
                .refused(status: -25_308)
            )))
            expectedContext = "Current screen: pairing\nFailure: tokenNotStored\nKeychain status: -25308"
        case .discoveryFailed:
            context = .discovery(.failed(diagnostic: privateDiagnostic))
            expectedContext = "Current screen: discovery\nFailure: failed"
        case .worktreesUnreachable:
            context = .worktrees(.unreachable(diagnostic: privateDiagnostic))
            expectedContext = "Current screen: worktrees\nFailure: unreachable"
        case .diffGitFailure:
            context = .diff(.gitFailure(message: privateStderr))
            expectedContext = "Current screen: diff\nFailure: gitFailure"
        case .pairingRefused:
            context = .pairing(.finished(.refused(.pairingExpired)))
            expectedContext = "Current screen: pairing\nFailure: pairingExpired"
        case .worktreesRefused:
            context = .worktrees(.unauthorized)
            expectedContext = "Current screen: worktrees\nFailure: unauthorized"
        }
        let scenario = Scenario(report: report)

        // when
        try await scenario.sut.copy(context: context)

        // then
        let copied = try #require(await scenario.pasteboard.lastCopy())
        #expect(copied == report + "\n\n" + expectedContext)
        for secret in [
            privateDiagnostic,
            privateStderr,
            "private-token",
            "cabin-cactus-camera-candle-harbour-lantern",
            "privateKey",
            "private-mac-identity",
            "private-mac-name",
            "private-bearer-token",
            "private-device-id",
            "private-server-id",
            "private-mac.local",
            "private-pin"
        ] {
            #expect(!copied.contains(secret))
        }
    }

    @Test(arguments: DiagnosticContextClassificationCase.allCases)
    func `given a supported screen context when logs are copied then its safe classification is preserved`(
        subject: DiagnosticContextClassificationCase
    ) async throws {
        // given
        let report = "Granita 0.11.0\nCurrent app session"
        let privatePayload = "PRIVATE-PAYLOAD bearer-token pairing-code private-source.swift private-mac.local"
        let (context, expectedSummary) = subject.fixture(privatePayload: privatePayload)
        let scenario = Scenario(report: report)

        // when
        try await scenario.sut.copy(context: context)

        // then
        let copied = try #require(await scenario.pasteboard.lastCopy())
        #expect(copied == report + "\n\n" + expectedSummary)
        #expect(!copied.contains(privatePayload))
        #expect(!copied.contains("bearer-token"))
        #expect(!copied.contains("pairing-code"))
        #expect(!copied.contains("private-source.swift"))
        #expect(!copied.contains("private-mac.local"))
    }

    private enum ContextCase: CaseIterable, Sendable {
        case keychainRefused
        case discoveryFailed
        case worktreesUnreachable
        case diffGitFailure
        case pairingRefused
        case worktreesRefused
    }

    private struct Scenario {

        let sut: CopyDiagnosticLogs
        let pasteboard: FakeDiagnosticPasteboard

        init(report: String) {
            pasteboard = FakeDiagnosticPasteboard()
            sut = CopyDiagnosticLogs(
                report: FakeDiagnosticReportProviding(report: report),
                pasteboard: pasteboard
            )
        }
    }
}
