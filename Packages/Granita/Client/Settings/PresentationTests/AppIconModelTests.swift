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

    init(canChangeIcon: Bool = true, current: AppIcon = .default, refusal: AppIconRefusal? = nil) {
        switcher = FakeAppIconSwitcher(canChangeIcon: canChangeIcon, current: current, refusal: refusal)
        sut = AppIconModel(switcher: switcher)
    }
}
