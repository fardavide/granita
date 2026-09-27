import Testing

import ClientSettingsDomain

/// Which drawing the Home Screen shows, and what the chooser says about the last attempt to change it.
@Suite("App icon")
struct AppIconTests {

    @Test
    func `when nothing was ever chosen then the icon is the glass`() {
        // given - when - then — the drawing the app ships with, and the only one a Mac ever shows.
        #expect(AppIcon.default == .granita)
    }

    @Test
    func `given every icon when it is named then the chooser has a word for it`() {
        // given - when - then — the chooser is built from `allCases`, so an icon added without a name
        // would draw a picture with nothing beside it rather than fail to compile.
        #expect(AppIcon.granita.displayName == "Granita")
        #expect(AppIcon.iceCube.displayName == "Ice Cube")
    }

    @Test
    func `given an icon that changed when the shown one is read then it is that icon`() {
        // given - when - then
        #expect(AppIconChoice.showing(.iceCube).shown == .iceCube)
    }

    @Test
    func `given a change the system refused when the shown one is read then it is the icon it kept`() {
        // given — the reader asked for the cube and the system kept the glass. **The checkmark has to
        // stay on the glass**, because that is what their Home Screen still shows; a chooser that
        // ticked what was asked for would be reporting a change that never happened.
        let choice = AppIconChoice.refused(showing: .granita, reason: "The operation was cancelled.")

        // when - then
        #expect(choice.shown == .granita)
    }
}
