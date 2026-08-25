/// The vocabulary the six-word fallback code is drawn from.
///
/// **128 words, six of them, is 42 bits.** That is the number this list exists to produce, and it
/// is why the list is this long rather than the sixteen words an earlier draft had: sixteen words
/// is 24 bits, which five guesses a minute would still take years to walk but which a hundred
/// source addresses on one network would not.
///
/// Chosen to be readable aloud and typeable from memory: nothing homophonous, nothing that differs
/// from a neighbour by one letter, no plurals, and nothing whose spelling is contested between
/// English and American — the person typing these is reading them off a Mac across the room.
///
/// **In `Core` because it is the wire contract**, not for tidiness. The Mac mints a code from this
/// list and the phone spends one against it, and design §5 asks the phone to say *"branch" is not
/// one of the words* before a round trip is spent. A second copy on the client would make an edit to
/// the list a version skew that nothing catches until somebody across a room reads six words aloud
/// and is refused — the same argument `CoreApiDomain` already won for `ApiErrorCode`.
public enum SpokenWords {

    public static let all = [
        "amber", "anchor", "apple", "arrow", "autumn", "bacon", "badge", "bamboo",
        "banjo", "barley", "basil", "beetle", "bison", "blanket", "bonus", "bottle",
        "boulder", "bracket", "bronze", "bucket", "cabin", "cactus", "camera", "candle",
        "canvas", "carbon", "cargo", "carpet", "cedar", "cello", "cement", "chapel",
        "cherry", "chisel", "cinder", "circus", "citrus", "cobalt", "cocoa", "comet",
        "copper", "coral", "cotton", "coyote", "cricket", "crimson", "crystal", "cymbal",
        "dagger", "dahlia", "daisy", "damson", "delta", "denim", "diamond", "dolphin",
        "domino", "donkey", "dragon", "drummer", "dynamo", "eagle", "emerald", "engine",
        "fabric", "falcon", "fennel", "fiddle", "filter", "flannel", "flint", "forest",
        "fossil", "fountain", "foxglove", "fresco", "frigate", "galaxy", "gallon", "garlic",
        "gazebo", "ginger", "glacier", "granite", "gravel", "gremlin", "guitar", "hammer",
        "hamster", "harbour", "harvest", "hazel", "helmet", "hermit", "hickory", "hollow",
        "hornet", "indigo", "ingot", "ivory", "jasmine", "jasper", "jigsaw", "jungle",
        "juniper", "kayak", "kettle", "kingdom", "kitten", "ladder", "lagoon", "lantern",
        "lattice", "lemon", "lentil", "lilac", "linen", "lobster", "locket", "lotus",
        "lumber", "magnet", "mammoth", "marble", "marigold", "meadow", "mercury", "mineral"
    ]

    /// How many words one code is made of. Six is SPEC §8's.
    public static let wordsInACode = 6

    /// Membership, answered without a linear scan of an array the phone consults on every keystroke.
    public static let vocabulary = Set(all)

    public static func code() -> String {
        // `randomElement` draws from the system generator, which is seeded from the kernel's
        // entropy pool on Apple platforms rather than from anything predictable.
        (0..<wordsInACode)
            .map { _ in all.randomElement() ?? all[0] }
            .joined(separator: "-")
    }

    /// What somebody typed, in the shape this file stores.
    ///
    /// Nobody types the hyphens, and somebody reading six words off a screen across the room will
    /// capitalise the first one. Refusing either would make the fallback useless in exactly the
    /// situation it exists for — no camera, and a code being read out.
    ///
    /// The middle dot is here because the Devices tab draws the words separated by one. A code shown
    /// in a form the server will not accept is worse than no fallback at all: everything looks
    /// right, and the pairing is refused with a reason that names the code rather than the dots.
    ///
    /// **The dashes are here because iOS types one nobody chose.** Smart punctuation turns a hyphen
    /// between two words into an en dash, so a reader typing the code exactly as the Mac shows it
    /// would be refused for punctuation the keyboard picked. The phone's field turns that setting
    /// off, which covers typing; this covers **paste**, which no field setting reaches and which is
    /// how the same-device case will actually be solved.
    ///
    /// **And the line endings, for the same reason and a worse symptom.** A phrase the Mac wrapped
    /// carries one in the middle of it, dictation ends one with it, and any field that takes a
    /// Return inserts it. Without them the two words either side fuse into a single token that is
    /// in no list — so the echo reads `amber⏎badge`, the phone names a word the reader never typed,
    /// and the remedy it offers is to go and check the Mac, which is showing the right words.
    /// Trimming the ends is not enough: the damage is always in the middle.
    public static func normalised(_ typed: String) -> String {
        typed
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: separators.contains)
            .joined(separator: "-")
    }

    /// The words a phone recognised in what has been typed so far, in the order they were typed.
    ///
    /// What design §5's echo line is drawn from: the reader compares this against the Mac's line
    /// rather than proofreading their own typing, which is a different and much easier task. It
    /// reports what was *read*, including words that are not in the list — deciding which of those
    /// is wrong is the caller's job, and a reader whose fifth word vanished from the echo would have
    /// no way to tell a typo from a parser that stopped.
    public static func words(in typed: String) -> [String] {
        normalised(typed).split(separator: "-").map(String.init)
    }

    /// The first word typed that no code could contain, or nothing.
    ///
    /// **Only ever the first**, and only ever complete words: flagging every unknown word at once
    /// puts three red lines under somebody mid-phrase, and flagging the word still being typed
    /// accuses the reader of a mistake they are three keystrokes from not making. So the last word
    /// is exempt unless the phrase is already the full six.
    public static func firstUnknownWord(in typed: String) -> String? {
        let typed = words(in: typed)
        let settled = typed.count >= wordsInACode ? typed[...] : typed.dropLast()
        return settled.first { vocabulary.contains($0) == false }
    }

    /// **`\r\n` is in here as well as its two halves, and it is not redundant.** A `Character` is an
    /// extended grapheme cluster, and a carriage return followed by a line feed is *one* of them —
    /// so a set holding only the two separately matches neither half of the pair that a Windows-
    /// authored or clipboard-round-tripped phrase actually carries.
    private static let separators: Set<Character> = [
        " ", "-", "\t", "\n", "\r", "\r\n", "·", "\u{2013}", "\u{2014}"
    ]
}
