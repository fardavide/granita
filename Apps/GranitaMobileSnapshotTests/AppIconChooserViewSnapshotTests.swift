import ClientSettingsDomain
import ClientSettingsUi
import SwiftUI
import Testing

/// The Home Screen icon previews and the saved choice.
///
/// **What these hold is that the drawings are the real ones**: the previews come from the app's own
/// asset catalog, which this bundle is hosted in, so a preview that went missing would render as an
/// empty square beside its name rather than fail anything else.
@Suite("App icon chooser", .serialized)
@MainActor
struct AppIconChooserViewSnapshotTests {

    @Test(arguments: AppIconChooserCase.all, SnapshotLayout.all)
    func `given an icon choice when the chooser renders then it matches its baseline`(
        subject: AppIconChooserCase,
        layout: SnapshotLayout
    ) {
        // given - when - then
        assertScreenSnapshot(
            AppIconChooserView(
                choice: subject.choice,
                selection: subject.selection,
                schedule: subject.schedule,
                onChoose: { _ in },
                onChooseSchedule: { _ in }
            ),
            layout: layout,
            named: subject.name
        )
    }
}

// MARK: -

struct AppIconChooserCase: Sendable, CustomTestStringConvertible {

    let name: String
    let choice: AppIconChoice
    let selection: AppIcon
    let schedule: AppIconSchedule

    var testDescription: String { name }

    static let all: [AppIconChooserCase] = [
        AppIconChooserCase(name: "granita", choice: .showing(.granita), selection: .granita, schedule: .automatic),

        AppIconChooserCase(name: "ice-cube", choice: .showing(.iceCube), selection: .iceCube, schedule: .manual),

        AppIconChooserCase(name: "christmas", choice: .showing(.christmas), selection: .iceCube, schedule: .automatic),

        // The system's explanation sits under the message about the icon it kept.
        AppIconChooserCase(
            name: "refused",
            choice: .refused(
                showing: .granita,
                reason: "Resource temporarily unavailable (NSPOSIXErrorDomain 35)"
            ),
            selection: .granita,
            schedule: .automatic
        )
    ]
}
