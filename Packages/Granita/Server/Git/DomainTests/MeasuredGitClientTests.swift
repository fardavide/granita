import Foundation
import Testing

import ServerGitDomain

@Suite("Measured git client")
struct MeasuredGitClientTests {

    @Test
    func `given git fails when a command is measured then its exact error survives and a failed duration is reported`() async {
        // given
        let failure = GitError.commandFailed(command: .headCommit, exitCode: 128, standardError: "fatal: the profile checkout has no HEAD")
        let scenario = Scenario(
            output: GitOutput(standardOutput: Data([0x70, 0x00, 0x72]), isTruncated: false),
            failure: failure
        )

        // when
        await #expect(throws: failure) {
            try await scenario.sut.run(.headCommit, in: RepositoryLocation(path: "/repo/failed-loading-profile"))
        }

        // then
        #expect(await scenario.measurements.measurements == [
            GitCommandMeasurement(command: .headCommit, duration: .milliseconds(347), outcome: .failed)
        ])
    }

    @Test
    func `given git returns distinct bytes when a command is measured then its output survives and a successful duration is reported`() async throws {
        // given
        let output = GitOutput(standardOutput: Data([0x62, 0x00, 0xff, 0x73]), isTruncated: true)
        let scenario = Scenario(output: output)

        // when
        let result = try await scenario.sut.run(.worktrees, in: RepositoryLocation(path: "/repo/loading-profile"))

        // then
        #expect(result == output)
        #expect(await scenario.measurements.measurements == [
            GitCommandMeasurement(command: .worktrees, duration: .milliseconds(347), outcome: .succeeded)
        ])
    }

    private struct Scenario {
        let sut: MeasuredGitClient
        let measurements: FakeGitCommandMeasurementRecording

        init(output: GitOutput, failure: GitError? = nil) {
            measurements = FakeGitCommandMeasurementRecording()
            sut = MeasuredGitClient(
                client: FakeGitClient(output: output, failure: failure),
                reporting: { [measurements] measurement in
                    await measurements.record(measurement)
                },
                elapsedSince: { _ in .milliseconds(347) }
            )
        }
    }
}
