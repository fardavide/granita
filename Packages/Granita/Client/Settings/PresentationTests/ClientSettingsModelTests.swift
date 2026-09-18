import Testing

import ClientConnectionDomain
import ClientSettingsDomain
import CoreReviewDomain
@testable import ClientSettingsPresentation

/// The review's two settings, and where they stand against the Mac that holds them.
///
/// The subject running through all of it: **a reader may always type.** A closed laptop is the
/// normal condition here, so nothing a reader does on this screen is allowed to be discarded for
/// want of a Mac that will answer later.
@Suite("Client settings model")
@MainActor
struct ClientSettingsModelTests {

    @Test
    func `given a Mac holding a line when the screen opens then it shows that line`() async {
        // given
        let scenario = Scenario(
            macHolding: ReviewSettings(openingLine: "Review the work here.", identifier: .numbers)
        )

        // when
        await scenario.sut.load()

        // then — the Mac wins at read time, which is the half of Davide's call this covers.
        #expect(scenario.sut.openingLineDraft == "Review the work here.")
        #expect(scenario.sut.settings.identifier == .numbers)
        #expect(scenario.sut.standing == .settled)
    }

    @Test
    func `given a Mac that never answers when the screen opens then it still opens`() async {
        // given — there is no loading state and no failure screen: the values this phone last had
        // are values it would honour, so there is nothing for a spinner to stand in front of.
        let scenario = Scenario(macFailing: .unreachable(diagnostic: "NWError -65563"))

        // when
        await scenario.sut.load()

        // then
        #expect(scenario.sut.standing == .queued)
        #expect(scenario.sut.openingLineDraft == ReviewSettings.defaultOpeningLine)
    }

    @Test
    func `given an unreachable Mac when the opening line is changed then it is kept and queued`(
    ) async {
        // given — the state that makes this screen hard. Read-only here would leave the two controls
        // unusable for most of the time the app is open, including a whole train journey.
        let scenario = Scenario(macFailing: .unreachable(diagnostic: "NWError -65563"))
        scenario.sut.openingLineDraft = "Mine."

        // when
        await scenario.sut.commitOpeningLine()

        // then — in effect on this phone, and the footer says where it went.
        #expect(scenario.sut.settings.openingLine == "Mine.")
        #expect(scenario.sut.standing == .queued)
    }

    @Test
    func `given a change when it is sent then only the field the reader touched travels`() async {
        // given — a queued opening line must not carry a label style this phone never read, which is
        // what the presence-versus-null idiom is doing here.
        let scenario = Scenario()

        // when
        scenario.sut.openingLineDraft = "Mine."
        await scenario.sut.commitOpeningLine()

        // then
        let patch = scenario.mac.patches.last
        #expect(patch?.openingLine == .some("Mine."))
        #expect(patch?.identifier == nil)
    }

    @Test
    func `given a line cleared to nothing when it is sent then that is a value rather than a reset`(
    ) async {
        // given — a review with no opening line is a legal answer, and it is not the same as never
        // having chosen one. Collapsing them would make clearing the field restore the default.
        let scenario = Scenario()

        // when
        scenario.sut.openingLineDraft = ""
        await scenario.sut.commitOpeningLine()

        // then
        #expect(scenario.mac.patches.last?.openingLine == .some(""))
        #expect(scenario.sut.settings.resolvedOpeningLine == nil)
    }

    @Test
    func `given a chosen line when it is reset then the default comes back`() async {
        // given
        let scenario = Scenario(
            macHolding: ReviewSettings(openingLine: "Mine.", identifier: .letters)
        )
        await scenario.sut.load()

        // when
        await scenario.sut.resetOpeningLine()

        // then — null rather than the default string, so the Mac records "never chosen" and every
        // device reading it gets whatever that release's built-in line is.
        #expect(scenario.mac.patches.last?.openingLine == .some(nil))
        #expect(scenario.sut.isOpeningLineDefault)
        #expect(scenario.sut.openingLineDraft == ReviewSettings.defaultOpeningLine)
    }

    @Test
    func `given a Mac too old for these when the screen opens then nothing is offered to queue`(
    ) async {
        // given — an absent route is an older Mac rather than a refusal, and there is no addressee.
        let scenario = Scenario(macFailing: .routeNotServed)

        // when
        await scenario.sut.load()

        // then
        #expect(scenario.sut.standing == .tooOld)
        #expect(scenario.sut.standing.acceptsEdits == false)
    }

    @Test
    func `given the Mac refused when a change is sent then this phone keeps using its own`() async {
        // given
        let scenario = Scenario(macFailing: .badRequest(message: "the document could not be read"))

        // when
        scenario.sut.openingLineDraft = "Mine."
        await scenario.sut.commitOpeningLine()

        // then — the two copies disagree and the sentence says which one is being used.
        #expect(scenario.sut.standing == .refused(reason: "the document could not be read"))
        #expect(scenario.sut.settings.openingLine == "Mine.")
    }

    @Test
    func `given no Mac at all when the screen opens then it is reachable and inert`() async {
        // given — discoverability was the real half of that question; operability is not, because a
        // queued value needs somewhere to go and this reader has nowhere, ever.
        let scenario = Scenario(paired: false)

        // when
        await scenario.sut.load()

        // then
        #expect(scenario.sut.standing == .noMac)
        #expect(scenario.sut.standing.acceptsEdits == false)
        #expect(scenario.mac.patches.isEmpty)
    }

    @Test
    func `given no Mac when a change is attempted then nothing is sent anywhere`() async {
        // given
        let scenario = Scenario(paired: false)

        // when
        await scenario.sut.choose(.numbers)

        // then
        #expect(scenario.mac.patches.isEmpty)
        #expect(scenario.sut.standing == .noMac)
    }

    // MARK: - Scenario

    private struct Scenario {

        let sut: ClientSettingsModel
        let mac: FakeSettingsRepository

        init(
            macHolding stored: ReviewSettings = .unset,
            macFailing failure: ApiFailure? = nil,
            paired: Bool = true
        ) {
            mac = FakeSettingsRepository(holding: stored, failing: failure)
            sut = ClientSettingsModel(macName: "MacBook Pro", isPaired: paired, repository: mac)
        }
    }
}
