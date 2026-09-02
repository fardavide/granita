import Testing

@testable import ClientViewerDomain

/// The two halves of a path, because the file header now draws them on separate lines.
///
/// **This is the review's sixth fault.** One line of head-truncated path renders
/// `…out/Presentation/Models/AboutState.swift`, which deletes the module — and the module is the one
/// thing that tells eleven files apart when three of them live in a folder called `Models`. Split in
/// two, the filename is never truncated at all and the directory can truncate in the middle, so both
/// of its ends survive.
///
/// Splitting on `/` rather than going through `URL`: `FileChange.path` is the wire's POSIX path for a
/// file on another machine, and a filesystem type over a string that deliberately never touches this
/// device's filesystem answers questions nobody asked.
@Suite("Diff file path")
struct DiffFilePathTests {

    @Test
    func `given a nested path when it is split then the name is the last component`() {
        // given - when - then
        #expect(DiffFilePath.name(of: "SwiftlyCore/Sources/About/Presentation/Models/AboutState.swift")
            == "AboutState.swift")
    }

    @Test
    func `given a nested path when it is split then the directory is everything above the name`() {
        // given - when - then — no trailing slash, because the line below the filename is a place
        // rather than a prefix of it.
        #expect(DiffFilePath.directory(of: "SwiftlyCore/Sources/About/Presentation/Models/AboutState.swift")
            == "SwiftlyCore/Sources/About/Presentation/Models")
    }

    @Test
    func `given a file at the root when it is split then the name is the whole path`() {
        // given — a real case in this repository: README.md and SPEC.md both live at the top.
        // when - then
        #expect(DiffFilePath.name(of: "README.md") == "README.md")
    }

    @Test
    func `given a file at the root when it is split then it has no directory to show`() {
        // given — empty rather than "/" or ".", so the header can drop the second line entirely
        // instead of drawing a line that says nothing.
        // when - then
        #expect(DiffFilePath.directory(of: "README.md") == "")
    }

    @Test
    func `given a path one folder deep when it is split then both halves survive`() {
        // given - when - then
        #expect(DiffFilePath.name(of: "Scripts/make-fixture-repo.sh") == "make-fixture-repo.sh")
        #expect(DiffFilePath.directory(of: "Scripts/make-fixture-repo.sh") == "Scripts")
    }

    @Test
    func `given an empty path when it is split then neither half invents anything`() {
        // given — not something the Mac sends, and the alternative to answering it is a crash on
        // `last` in a view body.
        // when - then
        #expect(DiffFilePath.name(of: "") == "")
        #expect(DiffFilePath.directory(of: "") == "")
    }
}
