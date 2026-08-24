import Foundation
import Testing

import CoreDiagnosticsData
import CoreDiagnosticsDomain

/// The verbose switch, across launches.
@Suite("Verbose logging setting")
struct UserDefaultsVerboseLoggingTests {

    @Test
    func `given nothing was ever stored when the setting is read then verbose is off`() {
        // given - when - then — design §7's footnote is what makes this the right default: verbose
        // records every request and every git invocation, which nobody wants until they are looking
        // for something.
        #expect(Scenario().sut.isVerbose == false)
    }

    @Test
    func `given the switch is turned on when the setting is read then verbose is on`() {
        // given
        let scenario = Scenario()

        // when
        scenario.sut.setVerbose(true)

        // then
        #expect(scenario.sut.isVerbose)
    }

    @Test
    func `given the switch was on when it is turned off then verbose is off again`() {
        // given
        let scenario = Scenario()
        scenario.sut.setVerbose(true)

        // when
        scenario.sut.setVerbose(false)

        // then
        #expect(scenario.sut.isVerbose == false)
    }

    // MARK: -

    private struct Scenario {

        let sut: UserDefaultsVerboseLogging

        init() {
            // A suite per subject, so two tests running at once cannot read each other's answer and
            // neither decides what Davide's own next launch does.
            let name = "granita.tests.\(UUID().uuidString)"
            UserDefaults.standard.removePersistentDomain(forName: name)
            sut = UserDefaultsVerboseLogging(defaults: UserDefaults(suiteName: name) ?? .standard)
        }
    }
}
