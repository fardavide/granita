import SwiftUI
import Testing

import ClientConnectionDomain
import ClientSettingsPresentation
import CoreReviewDomain

@Suite("Remote Mac review settings screen", .serialized)
@MainActor
struct ReviewSettingsScreenSnapshotTests {

    @Test(arguments: Subject.allCases, MacAppearance.all)
    func settings(subject: Subject, appearance: MacAppearance) async throws {
        let scenario = Scenario(subject: subject)

        try await assertReaderSnapshot(
            scenario.view,
            appearance: appearance,
            named: subject.rawValue,
            size: CGSize(width: 620, height: 540)
        ) {
            await scenario.prepare()
        }
    }

    enum Subject: String, CaseIterable, Sendable, CustomTestStringConvertible {
        case neverChanged = "remote-default-review-settings"
        case customOpeningLine = "remote-custom-opening-line-and-numbered-comments"
        case noOpeningLine = "remote-review-begins-at-the-first-comment"
        case unreachable = "remote-settings-kept-while-the-mac-is-away"
        case tooOld = "remote-mac-predates-review-settings"
        case refused = "remote-mac-refused-to-save-the-new-line"

        var testDescription: String { rawValue }
    }

    @MainActor
    private struct Scenario {
        let subject: Subject
        let repository: FakeSettingsRepository
        let model: ClientSettingsModel
        let appearance: AppearanceModel
        let appIcon: AppIconModel

        init(subject: Subject) {
            self.subject = subject
            let settings: ReviewSettings = switch subject {
            case .neverChanged, .unreachable, .tooOld, .refused:
                .unset
            case .customOpeningLine:
                ReviewSettings(openingLine: "Review the work in this worktree.", identifier: .numbers)
            case .noOpeningLine:
                ReviewSettings(openingLine: "", identifier: .letters)
            }
            let failure: ApiFailure? = switch subject {
            case .unreachable: .unreachable(diagnostic: "NSURLErrorDomain -1004")
            case .tooOld: .routeNotServed
            case .neverChanged, .customOpeningLine, .noOpeningLine, .refused: nil
            }
            let repository = FakeSettingsRepository(holding: settings, failing: failure)
            self.repository = repository
            model = ClientSettingsModel(macName: "MacBook Pro", isPaired: true, repository: repository)
            appearance = AppearanceModel(preferences: FakeAppearancePreferences())
            appIcon = AppIconModel(switcher: FakeAppIconSwitcher(canChangeIcon: false))
        }

        func prepare() async {
            await model.load()
            switch subject {
            case .neverChanged:
                #expect(model.isOpeningLineDefault)
                #expect(model.standing == .settled)
            case .customOpeningLine:
                #expect(model.openingLineDraft == "Review the work in this worktree.")
                #expect(model.settings.identifier == .numbers)
            case .noOpeningLine:
                #expect(model.openingLineDraft.isEmpty)
                #expect(model.isOpeningLineDefault == false)
            case .unreachable:
                #expect(model.standing == .queued)
            case .tooOld:
                #expect(model.standing == .tooOld)
            case .refused:
                repository.failure = .gitFailure(message: "the document on disk could not be read")
                model.openingLineDraft = "Reply to each point by its letter."
                await model.commitOpeningLine()
                #expect(model.standing == .refused(reason: "the document on disk could not be read"))
                #expect(model.openingLineDraft == "Reply to each point by its letter.")
            }
        }

        var view: some View {
            ReviewSettingsScreen(
                model: model,
                appearance: appearance,
                appIcon: appIcon,
                onPair: {}
            )
        }
    }
}
