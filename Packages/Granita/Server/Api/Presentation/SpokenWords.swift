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
enum SpokenWords {

    static let all = [
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
    static let wordsInACode = 6

    static func code() -> String {
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
    static func normalised(_ typed: String) -> String {
        typed
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: separators.contains)
            .joined(separator: "-")
    }

    private static let separators: Set<Character> = [" ", "-", "\t", "·"]
}
