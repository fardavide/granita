import Testing

import ClientSettingsDomain
import ClientViewerDomain

/// Which half of a pair is being drawn, which is the one question the *in use* marker under the samples
/// has to answer correctly.
///
/// **The interesting case is `system`, and it is the default and the common one.** A view that resolved
/// the marker from the picker's own value would be right on both forced settings and wrong on the one
/// nearly every reader is in — which is why the answer is a two-case enum rather than an optional a
/// caller can quietly read as *light*.
@Suite("App appearance")
struct AppAppearanceTests {

    @Test(arguments: HighlightAppearance.allCases)
    func `given the system appearance when it is resolved then the phone decides`(
        system: HighlightAppearance
    ) {
        // given - when - then
        #expect(AppAppearance.system.highlightAppearance.resolved(whenFollowing: system) == system)
    }

    @Test(arguments: HighlightAppearance.allCases)
    func `given a forced light appearance when it is resolved then the phone is ignored`(
        system: HighlightAppearance
    ) {
        // given - when - then — the frame this covers is a dark phone whose picker says Light: the
        // marker belongs under the left sample in both of that subject's renders.
        #expect(AppAppearance.light.highlightAppearance.resolved(whenFollowing: system) == .light)
    }

    @Test(arguments: HighlightAppearance.allCases)
    func `given a forced dark appearance when it is resolved then the phone is ignored`(
        system: HighlightAppearance
    ) {
        // given - when - then
        #expect(AppAppearance.dark.highlightAppearance.resolved(whenFollowing: system) == .dark)
    }

    @Test
    func `given every appearance when it is named then the segment has a word`() {
        // given - when - then — three segments, three words, and the picker is built from `allCases`, so
        // a fourth case added without a name would draw an empty segment rather than fail to compile.
        #expect(AppAppearance.allCases.allSatisfy { $0.displayName.isEmpty == false })
    }
}
