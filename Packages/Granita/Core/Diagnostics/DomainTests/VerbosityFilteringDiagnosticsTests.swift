import Testing

import CoreDiagnosticsDomain

/// What the verbose switch actually switches.
///
/// Design §7's footnote is the specification: *verbose logging records every request and every git
/// invocation until you turn it off*. So the switch decides the detail and nothing else — a failure
/// that only appeared once someone had thought to turn logging up would be found after it mattered.
@Suite("Verbosity filtering")
struct VerbosityFilteringDiagnosticsTests {

    @Test
    func `given the switch is off when detail is recorded then nothing reaches the log`() {
        // given
        let scenario = Scenario(isVerbose: false)

        // when
        scenario.sut.detail("git rev-parse --git-dir", about: .git)

        // then
        #expect(scenario.log.details.isEmpty)
    }

    @Test
    func `given the switch is on when detail is recorded then it reaches the log`() {
        // given
        let scenario = Scenario(isVerbose: true)

        // when
        scenario.sut.detail("git rev-parse --git-dir", about: .git)

        // then
        #expect(scenario.log.details == ["git rev-parse --git-dir"])
    }

    @Test
    func `given the switch is off when something is noted then it reaches the log anyway`() {
        // given — the half that must not be behind the switch. A reader who has to turn logging on
        // before a failure is written down learns about it after it stopped mattering.
        let scenario = Scenario(isVerbose: false)

        // when
        scenario.sut.note("git could not be run", about: .git)

        // then
        #expect(scenario.log.notes == ["git could not be run"])
    }

    @Test
    func `given the switch is moved while running when detail is recorded then the new setting applies`() {
        // given — the switch is on a Settings pane and the server reading it started at launch. A
        // verbosity captured at composition time is a switch that does nothing until a restart,
        // which is a control that appears to do nothing.
        let scenario = Scenario(isVerbose: false)
        scenario.sut.detail("before", about: .requests)

        // when
        scenario.verbosity.setVerbose(true)
        scenario.sut.detail("after", about: .requests)

        // then
        #expect(scenario.log.details == ["after"])
    }

    @Test
    func `given a line is recorded when it is read back then it carries what it was about`() {
        // given
        let scenario = Scenario(isVerbose: true)

        // when
        scenario.sut.detail("GET /v1/projects", about: .requests)

        // then — the subject is what a reader filters Console by, so a line that lost it is a line
        // they cannot find.
        #expect(scenario.log.subjects == [.requests])
    }

    // MARK: -

    private struct Scenario {

        let sut: VerbosityFilteringDiagnostics
        let log: FakeDiagnostics
        let verbosity: FakeVerboseLogging

        init(isVerbose: Bool) {
            log = FakeDiagnostics()
            verbosity = FakeVerboseLogging(isVerbose: isVerbose)
            sut = VerbosityFilteringDiagnostics(wrapped: log, verbosity: verbosity)
        }
    }
}
