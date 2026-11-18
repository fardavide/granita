import Foundation
import Testing

import ClientSettingsDomain
import ClientSettingsPresentation

/// Which icon the Home Screen shows, and what the chooser says after the reader picks one.
@Suite("App icon model")
@MainActor
struct AppIconModelTests {

    // MARK: - What it opens on

    @Test
    func `given a device that cannot change its icon when the model is made then there is no choice`() {
        // given - when — a Mac. The row is absent there, so nothing may report a choice to draw.
        let scenario = Scenario(canChangeIcon: false)

        // then
        #expect(scenario.sut.standing == .unavailable)
    }

    @Test
    func `given the cube already on the Home Screen when the model is made then it opens on the cube`() {
        // given - when — iOS keeps the alternate across launches and reports it, so the chooser has to
        // read it rather than assume the glass.
        let scenario = Scenario(current: .iceCube)

        // then
        #expect(scenario.sut.standing == .available(.showing(.iceCube)))
    }

    @Test
    func `given the default icon when the app opens on December first then it shows Christmas`() async throws {
        // given
        let scenario = Scenario(current: .granita)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 12, day: 1)))

        // when
        await scenario.sut.refreshSeasonalIcon(on: date, in: calendar.timeZone)

        // then
        #expect(scenario.switcher.requested == [.christmas])
        #expect(scenario.sut.standing == .available(.showing(.christmas)))
    }

    @Test
    func `given the reader chose Granita when the app opens in December then Granita stays`() async throws {
        // given
        let scenario = Scenario(current: .iceCube)
        await scenario.sut.choose(.granita)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 12, day: 25)))

        // when
        let reopened = AppIconModel(switcher: scenario.switcher, preferences: scenario.preferences)
        await reopened.refreshSeasonalIcon(on: date, in: calendar.timeZone)

        // then
        #expect(scenario.switcher.requested == [.granita])
        #expect(reopened.standing == .available(.showing(.granita)))
    }

    @Test(arguments: [
        (DateComponents(year: 2026, month: 11, day: 30, hour: 23, minute: 59), AppIcon.granita, AppIcon.granita),
        (DateComponents(year: 2027, month: 1, day: 7, hour: 23, minute: 59), AppIcon.granita, AppIcon.christmas),
        (DateComponents(year: 2027, month: 1, day: 8, hour: 0, minute: 0), AppIcon.christmas, AppIcon.granita)
    ])
    func `given automatic icons when the local date changes then the icon follows the season`(
        boundary: (date: DateComponents, shown: AppIcon, expected: AppIcon)
    ) async throws {
        // given
        let scenario = Scenario(current: boundary.shown)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: -8 * 60 * 60))
        let date = try #require(calendar.date(from: boundary.date))

        // when
        await scenario.sut.refreshSeasonalIcon(on: date, in: calendar.timeZone)

        // then
        #expect(scenario.sut.standing == .available(.showing(boundary.expected)))
        #expect(scenario.switcher.requested == (boundary.expected == boundary.shown ? [] : [boundary.expected]))
    }

    @Test
    func `given a legacy Ice Cube choice when the app opens in December then Ice Cube stays`() async throws {
        // given
        let scenario = Scenario(current: .iceCube)
        let date = try Date("2026-12-25T12:00:00Z", strategy: .iso8601)

        // when
        await scenario.sut.refreshSeasonalIcon(on: date, in: .gmt)

        // then
        #expect(scenario.switcher.requested.isEmpty)
        #expect(scenario.sut.schedule == .manual)
    }

    @Test
    func `given a manual icon when automatic is enabled in December then Christmas is applied`() async throws {
        // given
        let scenario = Scenario(current: .iceCube)
        let date = try Date("2026-12-25T12:00:00Z", strategy: .iso8601)

        // when
        await scenario.sut.chooseSchedule(.automatic, on: date, in: .gmt)

        // then
        #expect(scenario.sut.standing == .available(.showing(.christmas)))
        #expect(scenario.preferences.schedule(defaultingTo: .manual) == .automatic)
    }

    @Test
    func `given a seasonal Christmas icon when automatic is disabled then the icon is kept in January`() async throws {
        // given
        let scenario = Scenario(current: .christmas)
        let date = try Date("2027-01-08T00:00:00Z", strategy: .iso8601)

        // when
        await scenario.sut.chooseSchedule(.manual, on: date, in: .gmt)
        await scenario.sut.refreshSeasonalIcon(on: date, in: .gmt)

        // then
        #expect(scenario.switcher.requested.isEmpty)
        #expect(scenario.preferences.schedule(defaultingTo: .automatic) == .manual)
    }

    @Test
    func `given a refused seasonal change when activation is retried then Christmas is applied`() async throws {
        // given
        let scenario = Scenario(refusal: AppIconRefusal(reason: "Busy"))
        let date = try Date("2026-12-25T12:00:00Z", strategy: .iso8601)
        await scenario.sut.refreshSeasonalIcon(on: date, in: .gmt)
        scenario.switcher.stopRefusing()

        // when
        await scenario.sut.refreshSeasonalIcon(on: date, in: .gmt)

        // then
        #expect(scenario.switcher.requested == [.christmas, .christmas])
        #expect(scenario.sut.standing == .available(.showing(.christmas)))
    }

    // MARK: - Choosing

    @Test
    func `given the glass when the cube is chosen then the Home Screen shows the cube`() async {
        // given
        let scenario = Scenario(current: .granita)

        // when
        await scenario.sut.choose(.iceCube)

        // then — asked of the system, and moved on screen only once the system agreed.
        #expect(scenario.switcher.requested == [.iceCube])
        #expect(scenario.sut.standing == .available(.showing(.iceCube)))
    }

    @Test
    func `given the cube when the icon already shown is chosen then the system is not asked`() async {
        // given
        let scenario = Scenario(current: .iceCube)

        // when
        await scenario.sut.choose(.iceCube)

        // then — iOS answers every change with an alert, and this one would announce nothing.
        #expect(scenario.switcher.requested.isEmpty)
        #expect(scenario.sut.standing == .available(.showing(.iceCube)))
    }

    @Test
    func `given the system refuses when the cube is chosen then the glass stays ticked with the reason`() async {
        // given
        let scenario = Scenario(
            current: .granita,
            refusal: AppIconRefusal(reason: "Resource temporarily unavailable (NSPOSIXErrorDomain 35)")
        )

        // when
        await scenario.sut.choose(.iceCube)

        // then — the checkmark stays where the Home Screen is, and the system's words come with it.
        #expect(
            scenario.sut.standing == .available(
                .refused(showing: .granita, reason: "Resource temporarily unavailable (NSPOSIXErrorDomain 35)")
            )
        )
    }

    @Test
    func `given a refusal on screen when a change then succeeds then the refusal leaves`() async {
        // given — refused once, then the system recovered.
        let scenario = Scenario(current: .granita, refusal: AppIconRefusal(reason: "Busy"))
        await scenario.sut.choose(.iceCube)
        scenario.switcher.stopRefusing()

        // when
        await scenario.sut.choose(.iceCube)

        // then
        #expect(scenario.sut.standing == .available(.showing(.iceCube)))
    }

    @Test
    func `given a device that cannot change its icon when an icon is chosen then nothing is asked`() async {
        // given
        let scenario = Scenario(canChangeIcon: false)

        // when
        await scenario.sut.choose(.iceCube)

        // then
        #expect(scenario.switcher.requested.isEmpty)
        #expect(scenario.sut.standing == .unavailable)
    }
}

// MARK: -

@MainActor
private struct Scenario {

    let sut: AppIconModel
    let switcher: FakeAppIconSwitcher
    let preferences = FakeAppIconPreferences()

    init(canChangeIcon: Bool = true, current: AppIcon = .default, refusal: AppIconRefusal? = nil) {
        switcher = FakeAppIconSwitcher(canChangeIcon: canChangeIcon, current: current, refusal: refusal)
        sut = AppIconModel(switcher: switcher, preferences: preferences)
    }
}
