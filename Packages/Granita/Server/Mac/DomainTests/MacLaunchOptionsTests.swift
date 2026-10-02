import Foundation
import Testing

import ServerMacDomain

/// What the menu bar app can be told on the command line.
///
/// Fixture options let a behavioural test drive this app without changing the reader's document
/// or preferences. Parsed here rather than in the composition root so
/// that the parsing is a thing a test can reach — the root is, by construction, the one module no
/// test constructs.
@Suite("Mac launch options")
struct MacLaunchOptionsTests {

    @Test(arguments: [
        (["--preferences-suite", "granita.tests.reader-selection"], Optional("granita.tests.reader-selection")),
        (["--preferences-suite", "granita.tests.appearance"], Optional("granita.tests.appearance")),
        ([], nil),
        (["--preferences-suite"], nil)
    ])
    func `given optional fixture preferences when parsed then only the supplied suite is named`(
        _ arguments: [String],
        _ expected: String?
    ) {
        // given - when
        let options = MacLaunchOptions(arguments)

        // then
        #expect(options.preferencesSuite == expected)
    }

    @Test(arguments: [
        (["--port", "0"], UInt16(0)),
        ([], UInt16(8737))
    ])
    func `given an optional listener port when parsed then explicit zero or the ordinary port is preserved`(
        _ arguments: [String],
        _ expected: UInt16
    ) {
        // given - when
        let options = MacLaunchOptions(arguments)

        // then
        #expect(options.port == expected)
    }

    @Test
    func `given no arguments when parsed then nothing is asked for`() {
        // given - when
        let options = MacLaunchOptions([])

        // then — the ordinary launch, which is every launch that is not a test.
        #expect(options.storeUrl == nil)
        #expect(options.opensSettingsAtLaunch == false)
    }

    @Test
    func `given a store path when parsed then that is where the document lives`() {
        // given - when
        let options = MacLaunchOptions(["--store", "/tmp/granita-ui/granita.json"])

        // then
        #expect(options.storeUrl == URL(filePath: "/tmp/granita-ui/granita.json"))
    }

    @Test
    func `given the store flag with nothing after it when parsed then no store is named`() {
        // given - when — the flag is last, so reading the next argument would read off the end.
        let options = MacLaunchOptions(["--store"])

        // then — no store rather than a crash, and the composition root then falls back to the real
        // one. A flag with no value is a mistake at a terminal, not a reason to refuse to launch.
        #expect(options.storeUrl == nil)
    }

    @Test
    func `given the settings flag when parsed then Settings is asked for`() {
        // given - when
        let options = MacLaunchOptions(["--open-settings"])

        // then
        #expect(options.opensSettingsAtLaunch)
    }

    @Test
    func `given the arguments a test runner adds when parsed then the ones we do not know are ignored`() {
        // given — XCTest appends its own argv, and a parser that refused what it did not recognise
        // would refuse every launch a UI test makes.
        let options = MacLaunchOptions([
            "-XCTIdePerfTestID", "0",
            "--store", "/tmp/granita-ui/granita.json",
            "-ApplePersistenceIgnoreState", "YES",
            "--open-settings"
        ])

        // then
        #expect(options.storeUrl == URL(filePath: "/tmp/granita-ui/granita.json"))
        #expect(options.opensSettingsAtLaunch)
    }
}
