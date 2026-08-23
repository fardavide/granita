import Testing

import ServerMacDomain

/// What a folder scan refuses to look inside, which is the half of §4 that is policy rather than
/// walking. SPEC §9 names the list and the reason each entry is on it is the same: a directory that
/// routinely holds other people's checkouts, in numbers that would bury the ones a reader filed
/// there on purpose.
@Suite("Repository scan")
struct RepositoryScanTests {

    @Test(arguments: ["node_modules", ".build", "DerivedData", "Pods", "vendor", "target"])
    func `given a directory the specification names when scanning then it is not descended into`(
        name: String
    ) {
        // given - when - then
        #expect(RepositoryScan.descends(into: name) == false)
    }

    @Test
    func `given a hidden directory when scanning then it is not descended into`() {
        // given - when - then — `.Trash`, `.cache`, `.npm`, and every agent's worktree folder. A
        // scan is a person pointing at where they keep their work, and none of it is kept here.
        #expect(RepositoryScan.descends(into: ".Trash") == false)
        #expect(RepositoryScan.descends(into: ".claude") == false)
    }

    @Test
    func `given an ordinary directory when scanning then it is descended into`() {
        // given - when - then
        #expect(RepositoryScan.descends(into: "Developer"))
        #expect(RepositoryScan.descends(into: "experiments"))
    }

    @Test
    func `given a name that merely contains a skipped one when scanning then it is descended into`() {
        // given - when - then — the list is directory names, not substrings. A repository called
        // `vendor-portal` is a repository somebody named, and `targets` is not `target`.
        #expect(RepositoryScan.descends(into: "vendor-portal"))
        #expect(RepositoryScan.descends(into: "targets"))
    }
}
