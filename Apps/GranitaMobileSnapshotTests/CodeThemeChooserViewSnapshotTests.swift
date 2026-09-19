import ClientSettingsUi
import ClientViewerDomain
import SwiftUI
import Testing

/// The list of themes, with every pair drawn in both halves.
///
/// **What these baselines hold is that the dark half is drawn dark inside a light sheet, and the light
/// half light inside a dark one.** That is the whole of the design's answer to "how does a reader see
/// the half their phone is not showing", and it is the one thing here a unit test cannot photograph: a
/// sample that started resolving its card colour from the environment would still be a rectangle with
/// code in it, and every assertion about the model would pass.
///
/// **Both appearances of every subject, and the rows never differ between them.** A row carries no
/// captions and no *in use* marker — those live in the section, where there is a live question about
/// which half the reader is in — so the only thing that changes between the light and dark renders is
/// the sheet around the cards.
@Suite("Code theme chooser", .serialized)
@MainActor
struct CodeThemeChooserViewSnapshotTests {

    @Test(arguments: CodeTheme.allCases, SnapshotLayout.all)
    func `given a chosen theme when the chooser renders then it matches its baseline`(
        chosen: CodeTheme,
        layout: SnapshotLayout
    ) {
        // given - when - then — one subject per theme rather than one for the list, because the
        // checkmark is the only thing that moves and a single subject would photograph it once.
        assertScreenSnapshot(
            CodeThemeChooserView(chosen: chosen, onChoose: { _ in }),
            layout: layout,
            named: chosen.rawValue
        )
    }

    /// The reader's largest non-accessibility size, on the layout with the least room.
    ///
    /// **The frame the design asked for, and it is about the samples rather than the names.** The two
    /// cards are 10pt monospaced inside a row whose label grows with the reader's type, so xxLarge is
    /// where a card either keeps its three lines or starts clipping them — and `lineLimit(1)` plus
    /// `.clipped()` is the call being photographed. One frame rather than four: the question is the
    /// narrowest width at the largest type, and the iPad and the dark sheet answer it no differently.
    @Test
    func `given the largest type size when the chooser renders then it matches its baseline`() {
        // given - when - then
        assertScreenSnapshot(
            CodeThemeChooserView(chosen: .default, onChoose: { _ in })
                .dynamicTypeSize(.xxLarge),
            layout: .iPhoneLight,
            named: "xxLarge"
        )
    }
}
