import Testing

@testable import ClientViewerDomain

/// The one row inside a reserved card, which is three words' worth of difference and the whole of
/// what design §9 gives a reader to tell three situations apart.
///
/// Asserted here rather than through the view that draws them, because a sentence only a `Ui` target
/// reads is a sentence nothing in this repository holds to its spelling — and the difference between
/// *reading*, *still reading* and *couldn’t read* is the feature.
@Suite("Diff file wait")
struct DiffFileWaitTests {

    @Test
    func `given a file still on its way when its row speaks then it names who is being asked`() {
        // given - when - then
        #expect(DiffFileWait.reading.sentence == "reading from your Mac")
        #expect(DiffFileWait.reading.isFailed == false)
    }

    @Test
    func `given a file that has been on its way a while when its row speaks then it adds one word`() {
        // given - when - then — one word, once, rather than the loading screen's elapsed clock: five
        // files are in flight here and a clock would be five stopwatches ticking in a scroll.
        #expect(DiffFileWait.stillReading.sentence == "still reading from your Mac")
        #expect(DiffFileWait.stillReading.isFailed == false)
    }

    @Test
    func `given a file whose batch was refused when its row speaks then it says so and takes the marker`() {
        // given - when - then — the marker column's third word goes with this one, which is what
        // makes a stopped card tell itself apart from a card that is merely still coming.
        #expect(DiffFileWait.failed.sentence == "couldn’t read this file")
        #expect(DiffFileWait.failed.isFailed)
    }

    @Test
    func `given every wait when its row speaks then no two of them say the same thing`() {
        // given — three pictures rather than one is the whole of §9, so two cases that read alike
        // would be the defect it was raised for, wearing a sentence.
        let spoken = Set(DiffFileWait.allCases.map(\.sentence))

        // when - then
        #expect(spoken.count == DiffFileWait.allCases.count)
    }

    @Test
    func `when the threshold is asked for then it is the ten seconds the design names`() {
        // given - when - then — stated rather than left to the model, because the row's second word
        // and the batch that triggers it are two halves of one fact.
        #expect(DiffFileWait.longWait == .seconds(10))
    }
}
