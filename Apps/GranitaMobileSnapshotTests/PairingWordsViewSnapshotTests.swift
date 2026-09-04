import ClientConnectionUi
import CorePairingDomain
import SwiftUI
import Testing

/// The six-word field, in every shape the phrase under it can take.
///
/// **One appearance and five inputs**, because that is what design §5 draws: this screen has no
/// states of its own — no spinner, no refusal, nothing about the network — and everything that moves
/// on it moves because somebody typed. So the subject of each of these is a string, and what is
/// asserted is the three lines the string produces: the echo in the Mac's own format, the count, and
/// the red line that appears only for a word no code could contain.
///
/// **A refusal is not among them, and that is not an omission.** §5 puts the consequence of one on
/// the outcome screen and sends the reader back here with the phrase still typed — which is the
/// `all-six` baseline again, under a name that would claim something the pixels do not. What a
/// refusal does to this screen is photographed one file over, where the receipt is.
///
/// Main-actor isolated, and it must be. Swift Testing runs `@Test` functions off the main actor by
/// default, and rendering touches UIKit view properties — which trap with
/// `_raiseExceptionForBackgroundThreadLayerPropertyModification`. That trap is worse than a plain
/// failure: the crash restarts the test host, and the retry then reports "0 tests passed", so the
/// suite goes green having rendered nothing.
@Suite("Pairing words screen", .serialized)
@MainActor
struct PairingWordsViewSnapshotTests {

    @Test(arguments: WordsCase.all, SnapshotLayout.all)
    func `given a typed phrase when rendering then it matches its baseline`(
        subject: WordsCase,
        layout: SnapshotLayout
    ) {
        // given - when - then
        //
        // Unclamped like every screen before a paired Mac. §5 gives this one no iPad drawing of its
        // own: the field at the top and the keyboard taking the bottom third, at whatever width the
        // window is — through 0.7.0 that width was a 420pt column in the middle of it.
        assertScreenSnapshot(
            NavigationStack {
                PairingWordsView(
                    macName: aMacName,
                    typedWords: .constant(subject.typed),
                    spokenWords: subject.spokenWords,
                    unknownWord: subject.unknownWord,
                    onPair: {}
                )
            },
            layout: layout,
            named: subject.name
        )
    }
}

// MARK: -

/// Named so the baseline filename says which state it captures, and so a failure names it too.
///
/// The two derived properties are read from `SpokenWords` rather than written out beside each
/// phrase, because the screen's whole claim is that what it echoes is what the phone made of what
/// was typed. A hand-written echo would photograph the echo this suite believes in.
struct WordsCase: Sendable, CustomTestStringConvertible {

    let name: String
    let typed: String

    var testDescription: String { name }

    var spokenWords: [String] { SpokenWords.words(in: typed) }

    var unknownWord: String? { SpokenWords.firstUnknownWord(in: typed) }

    static let all: [WordsCase] = [
        // The screen as it is pushed: the placeholder, an empty echo, "0 of 6", and the button dark.
        WordsCase(name: "nothing-typed", typed: ""),

        // Mid-phrase, and nothing accusing anybody of anything. The last word typed is exempt from
        // the unknown-word check until the phrase is the full six, so this is also the state that
        // proves a reader three keystrokes from finishing is left alone.
        WordsCase(name: "half-a-phrase", typed: "amber anchor apple"),

        // A word the list does not hold, caught before a round trip is spent — and a wasted round
        // trip is a fifth of the rate limit. Only the first, and only a settled one.
        WordsCase(name: "a-word-that-is-not-one", typed: "amber branch apple arrow"),

        // Six entered lights the button and nothing else: no count in the label, no ready badge.
        WordsCase(name: "all-six", typed: "amber anchor apple arrow autumn bacon"),

        // **The field corrects nothing, and this is the picture of it.** Typed exactly as the Mac
        // draws the words — capitalised first word, middle dots — the field keeps every character and
        // the echo underneath shows the six the phone made of them. The two lines differing is the
        // whole design, so it is a baseline rather than an argument.
        WordsCase(name: "typed-as-the-Mac-shows-it", typed: "Amber · anchor · apple · arrow · autumn · bacon")
    ]
}
