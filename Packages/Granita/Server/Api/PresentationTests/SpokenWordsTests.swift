import Foundation
import Testing

@testable import ServerApiPresentation

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
