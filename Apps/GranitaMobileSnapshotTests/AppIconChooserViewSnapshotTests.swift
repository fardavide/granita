import ClientSettingsDomain
import ClientSettingsUi
import SwiftUI
import Testing

/// The Home Screen icons and seasonal toggle, with the checkmark where the Home Screen is.
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
                choice: subject.choice, schedule: subject.schedule, onChoose: { _ in }, onChooseSchedule: { _ in }
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
    let schedule: AppIconSchedule

    var testDescription: String { name }

    static let all: [AppIconChooserCase] = [
        AppIconChooserCase(name: "granita", choice: .showing(.granita), schedule: .automatic),

        AppIconChooserCase(name: "ice-cube", choice: .showing(.iceCube), schedule: .manual),

        AppIconChooserCase(name: "christmas", choice: .showing(.christmas), schedule: .automatic),

        // **The system said no.** The checkmark stays on the glass because the Home Screen does, our
        // sentence says so, and the system's own words sit underneath as small print with their code.
        AppIconChooserCase(
            name: "refused",
            choice: .refused(
                showing: .granita,
                reason: "Resource temporarily unavailable (NSPOSIXErrorDomain 35)"
            ),
            schedule: .automatic
        )
    ]
}
