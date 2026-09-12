import Foundation
import Testing

import ClientConnectionData
import ClientConnectionDomain

@Suite("Connection stage timing logs")
struct ConnectionTimingLogsTests {
    @Test(arguments: [
        StageRendering(stage: .localDiscovery, label: "LOCAL DISCOVERY"),
        StageRendering(stage: .tailnetVerification, label: "TAILNET VERIFICATION"),
        StageRendering(stage: .localVerification, label: "LOCAL VERIFICATION")
    ], [
        OutcomeRendering(outcome: .succeeded, label: "succeeded"),
        OutcomeRendering(outcome: .failed, label: "failed"),
        OutcomeRendering(outcome: .cancelled, label: "cancelled"),
        OutcomeRendering(outcome: .skipped, label: "skipped")
    ])
    func `given a connection stage when timing events are recorded then logs show ordered stage outcomes and elapsed milliseconds`(stage: StageRendering, outcome: OutcomeRendering) async throws {
        // given
        let scenario = Scenario(timestamp: try #require(ISO8601DateFormatter().date(from: "2026-09-12T19:42:17Z")))
        let recorder: any ConnectionTimingRecording = scenario.sut

        // when
        await recorder.record(.started(stage.stage))
        await recorder.record(.finished(stage.stage, duration: .milliseconds(4_213), outcome: outcome.outcome))
        let report = await scenario.sut.report()

        // then
        let started = try #require(report.range(of: "2026-09-12T19:42:17Z \(stage.label) — started"))
        let finished = try #require(report.range(of: "2026-09-12T19:42:17Z \(stage.label) — \(outcome.label) — 4213 ms"))
        #expect(started.lowerBound < finished.lowerBound)
    }

    @Test
    func `given a timed request with a credential bearing URL when logs are copied then stage outcome and milliseconds exclude secrets`() async throws {
        // given
        let scenario = Scenario(timestamp: try #require(ISO8601DateFormatter().date(from: "2026-09-12T19:42:17Z")))
        let url = try #require(URL(string:
            "https://private-user:private-password@100.87.42.19:8737/v1/worktrees"
                + "?pairingCode=private-pairing-code&token=private-bearer-token#private-fragment"
        ))

        // when
        await scenario.sut.record(.requestStarted(method: .get, url: url))
        await scenario.sut.record(.requestTimed(method: .get, url: url, duration: .milliseconds(12_345), outcome: .succeeded))
        let report = await scenario.sut.report()

        // then
        let started = try #require(report.range(of: "2026-09-12T19:42:17Z REQUEST GET https://100.87.42.19:8737/v1/worktrees — started"))
        let finished = try #require(report.range(of: "2026-09-12T19:42:17Z REQUEST GET https://100.87.42.19:8737/v1/worktrees — succeeded — 12345 ms"))
        #expect(started.lowerBound < finished.lowerBound)
        for secret in ["private-user", "private-password", "pairingCode", "private-pairing-code", "token", "private-bearer-token", "private-fragment"] {
            #expect(report.contains(secret) == false)
        }
    }

    struct StageRendering: Sendable {
        let stage: ConnectionStage
        let label: String
    }

    struct OutcomeRendering: Sendable {
        let outcome: ConnectionStageOutcome
        let label: String
    }

    private struct Scenario {
        let sut: ConnectionLogs

        init(timestamp: Date) {
            sut = ConnectionLogs(context: ConnectionLogContext(appVersion: "0.11.3", build: "302", systemVersion: "iOS 27.0", deviceModel: "iPhone"), capacity: 8, now: { timestamp })
        }
    }
}
