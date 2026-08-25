import Foundation
import Testing

import CorePairingDomain

/// The vocabulary the fallback code is drawn from, and the properties its own documentation claims.
///
/// **These are asserted rather than described because the list is edited by hand.** Every property
/// below is one a person adding a word can break without noticing, and none of them fail anywhere a
/// test would otherwise look: the symptom is somebody across a room reading six words aloud and the
/// wrong pairing being spent, months from now, once.
struct SpokenWordsTests {

    // MARK: - The size the entropy argument depends on

    @Test func `given the word list then it is the length its entropy argument assumes`() {
        // given - when - then
        // 128 words, six of them, is 42 bits. The file's own reasoning depends on this number, so a
        // list that quietly grew or shrank would leave that reasoning describing something else.
        #expect(SpokenWords.all.count == 128)
    }

    @Test func `given the word list then no word appears twice`() {
        // given - when
        let unique = Set(SpokenWords.all)

        // then
        // A duplicate is a silent halving of one position's contribution.
        #expect(unique.count == SpokenWords.all.count)
    }

    // MARK: - The property that matters when the channel is a voice

    @Test func `given the word list then no two words differ by a single letter`() {
        // given
        let words = SpokenWords.all

        // when
        let confusable = words.indices.flatMap { first in
            words[words.index(after: first)...]
                .filter { Self.isOneEditApart(words[first], $0) }
                .map { "\(words[first])/\($0)" }
        }

        // then
        // The list promises this in as many words, and it is the whole reason the list is
        // hand-picked rather than taken from a dictionary: the fallback exists for the case where
        // the code is being read out or held in someone's head, which is exactly when `amber` and
        // `ember` become the same word.
        #expect(confusable == [])
    }

    @Test func `given the word list then nothing in it is spelled differently on the two sides of the atlantic`() {
        // given
        // Not exhaustive, and not meant to be — these are the endings that actually collide, and
        // the test exists so that adding `color` or `harbor` is caught rather than discussed.
        let contested = ["color", "harbor", "armor", "favor", "flavor", "labor", "meter", "liter", "fiber", "center"]

        // when
        let found = SpokenWords.all.filter { contested.contains($0) }

        // then
        #expect(found == [])
    }

    @Test func `given the word list then every word is plain lowercase ascii letters`() {
        // given
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz")

        // when
        let awkward = SpokenWords.all.filter { CharacterSet(charactersIn: $0).isSubset(of: allowed) == false }

        // then
        // A hyphen separates words in a code, so a word containing one would make the code
        // ambiguous to split; an accent would make it untypeable on the phone's keyboard.
        #expect(awkward == [])
    }

    // MARK: - Reading one back

    @Test func `given six words typed with spaces and a capital when they are normalised then they are the stored form`() {
        // given
        let typed = "  Delta pepper amber Kelp jasper meadow "

        // when
        let normalised = SpokenWords.normalised(typed)

        // then
        #expect(normalised == "delta-pepper-amber-kelp-jasper-meadow")
    }

    @Test func `given the words copied off the Devices tab with its separators then they are the stored form`() {
        // given
        // Exactly what design §5 draws under the QR. The tab separates the words with a middle dot,
        // so a reader who selects the line and pastes it into their phone sends this — and a phone
        // that has just been shown the code it must type would otherwise be refused for typing it.
        let copied = "delta · pepper · amber · kelp · jasper · meadow"

        // when
        let normalised = SpokenWords.normalised(copied)

        // then
        #expect(normalised == "delta-pepper-amber-kelp-jasper-meadow")
    }

    @Test func `given a hyphen iOS turned into an en dash when it is normalised then it is the stored form`() {
        // given
        // Not a hypothetical. Smart punctuation replaces a hyphen between two words as it is typed,
        // so this is what the field produced before it turned that setting off — and it is still
        // what arrives from a paste, which no field setting reaches.
        let typed = "delta–pepper–amber–kelp–jasper–meadow"

        // when
        let normalised = SpokenWords.normalised(typed)

        // then
        #expect(normalised == "delta-pepper-amber-kelp-jasper-meadow")
    }

    @Test func `given an em dash when it is normalised then it is the stored form`() {
        // given
        // The other half of the same keyboard behaviour: two hyphens become one em dash.
        let typed = "delta—pepper—amber—kelp—jasper—meadow"

        // when
        let normalised = SpokenWords.normalised(typed)

        // then
        #expect(normalised == "delta-pepper-amber-kelp-jasper-meadow")
    }

    @Test func `given a newline in the middle of a phrase when it is normalised then it is the stored form`() {
        // given
        // A phrase the Mac wrapped, selected and pasted, or one ended by dictation, or a Return in
        // a field that takes one. Without this the two words either side fuse into a token that is
        // in no list, so the echo shows `harbour⏎lantern` and the screen names a word nobody typed.
        let typed = "delta pepper amber\nkelp jasper meadow"

        // when
        let normalised = SpokenWords.normalised(typed)

        // then
        #expect(normalised == "delta-pepper-amber-kelp-jasper-meadow")
    }

    @Test func `given a phrase wrapped the way a Mac wraps it when it is normalised then it is the stored form`() {
        // given
        // Two line endings rather than one, which is what arrives from a paste that crossed a
        // clipboard rather than a keyboard — and both halves of it have to be a separator or the
        // carriage return stays stuck to a word.
        let typed = "delta·pepper·amber\r\nkelp·jasper·meadow"

        // when
        let normalised = SpokenWords.normalised(typed)

        // then
        #expect(normalised == "delta-pepper-amber-kelp-jasper-meadow")
    }

    @Test func `given a newline splitting a phrase when the words are read then neither neighbour is called unknown`() {
        // given
        // The symptom rather than the mechanism: a fused token is not in the 128, so the reader is
        // accused of a word they never typed and sent back to a Mac that is showing the right one.
        let typed = "cabin cactus camera\ncandle harbour lantern"

        // when
        let unknown = SpokenWords.firstUnknownWord(in: typed)

        // then
        #expect(SpokenWords.words(in: typed) == ["cabin", "cactus", "camera", "candle", "harbour", "lantern"])
        #expect(unknown == nil)
    }

    // MARK: - What the phone echoes back while somebody types

    @Test func `given a partly typed phrase when its words are read then it reports what it recognised`() {
        // given
        let typed = "Cabin cactus-camera"

        // when
        let words = SpokenWords.words(in: typed)

        // then
        // In the order typed, normalised the way the server will read them, so the reader compares
        // this line against the Mac's rather than proofreading their own typing.
        #expect(words == ["cabin", "cactus", "camera"])
    }

    @Test func `given a word that is not in the list when it is complete then it is named`() {
        // given
        // "branch" is a plausible thing to read off a screen and is not one of the 128.
        let typed = "cabin cactus camera branch lantern"

        // when
        let unknown = SpokenWords.firstUnknownWord(in: typed)

        // then
        #expect(unknown == "branch")
    }

    @Test func `given a word still being typed then it is not called unknown`() {
        // given
        // `cand` is three keystrokes from `candle`. Flagging it accuses the reader of a mistake
        // they have not made yet, which is the whole reason the last word is exempt.
        let typed = "cabin cactus camera cand"

        // when
        let unknown = SpokenWords.firstUnknownWord(in: typed)

        // then
        #expect(unknown == nil)
    }

    @Test func `given all six words are typed and the last is not in the list then the last is named`() {
        // given
        // The exemption has to end somewhere, and six words is where: nothing more is coming, so a
        // final word that cannot be right is worth saying before the button is pressed.
        let typed = "cabin cactus camera candle harbour brunch"

        // when
        let unknown = SpokenWords.firstUnknownWord(in: typed)

        // then
        #expect(unknown == "brunch")
    }

    @Test func `given only words from the list when they are checked then nothing is named`() {
        // given
        let typed = "cabin cactus camera candle harbour lantern"

        // when
        let unknown = SpokenWords.firstUnknownWord(in: typed)

        // then
        // Every one of these has to actually be in the list, or this test passes for the wrong
        // reason — so it is asserted rather than assumed.
        #expect(SpokenWords.words(in: typed).allSatisfy(SpokenWords.vocabulary.contains))
        #expect(unknown == nil)
    }

    // MARK: -

    /// Whether two words are one substitution, insertion or deletion apart.
    ///
    /// Written out rather than taken from a library because it is six lines and the alternative is a
    /// fourth external dependency for a test.
    private static func isOneEditApart(_ one: String, _ other: String) -> Bool {
        let short = Array(one.count <= other.count ? one : other)
        let long = Array(one.count <= other.count ? other : one)
        guard long.count - short.count <= 1 else {
            return false
        }
        if short.count == long.count {
            return zip(short, long).filter(!=).count == 1
        }
        return long.indices.contains { Array(long[..<$0] + long[long.index(after: $0)...]) == short }
    }
}
