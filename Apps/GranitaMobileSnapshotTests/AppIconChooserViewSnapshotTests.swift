import ClientSettingsDomain
import ClientSettingsUi
import SwiftUI
import Testing

/// The two Home Screen icons, with the checkmark where the Home Screen is.
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
            AppIconChooserView(choice: subject.choice, onChoose: { _ in }),
            layout: layout,
            named: subject.name
        )
    }
}

// MARK: -

struct AppIconChooserCase: Sendable, CustomTestStringConvertible {

    let name: String
    let choice: AppIconChoice

    var testDescription: String { name }

    static let all: [AppIconChooserCase] = [
        // What every reader sees first: the glass ticked, and the word *Default* beside it.
        AppIconChooserCase(name: "granita", choice: .showing(.granita)),

        // The checkmark moved, and *Default* did not — the word marks the default, not the choice.
        AppIconChooserCase(name: "ice-cube", choice: .showing(.iceCube)),

        // **The system said no.** The checkmark stays on the glass because the Home Screen does, our
        // sentence says so, and the system's own words sit underneath as small print with their code.
        AppIconChooserCase(
            name: "refused",
            choice: .refused(
                showing: .granita,
                reason: "Resource temporarily unavailable (NSPOSIXErrorDomain 35)"
            )
        )
    ]
}
