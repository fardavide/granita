import Testing

@testable import CoreDiffDomain

/// Whether a changed file is an image is decided from its path and nowhere else, so both halves have
/// to agree about it without asking each other.
@Suite("Image diff")
struct ImageDiffTests {

    // MARK: - Which paths claim an image

    @Test
    func `given a path with an image extension when asking its format then it names one`() {
        // given - when - then — spelled out rather than looped, so a table edited wrongly fails here.
        #expect(ImageFormat.forPath("Apps/Snapshots/home-iPhone-light.png") == .png)
        #expect(ImageFormat.forPath("Art/cover.jpg") == .jpeg)
        #expect(ImageFormat.forPath("Art/cover.jpeg") == .jpeg)
        #expect(ImageFormat.forPath("docs/demo.gif") == .gif)
        #expect(ImageFormat.forPath("shots/IMG_0041.HEIC") == .heic)
        #expect(ImageFormat.forPath("shots/IMG_0041.heif") == .heic)
        #expect(ImageFormat.forPath("scan.tif") == .tiff)
        #expect(ImageFormat.forPath("scan.tiff") == .tiff)
        #expect(ImageFormat.forPath("legacy.bmp") == .bmp)
        #expect(ImageFormat.forPath("web/hero.webp") == .webp)
    }

    @Test
    func `given a path with no image extension when asking its format then it names none`() {
        // given - when - then
        #expect(ImageFormat.forPath("Sources/App/main.swift") == nil)
        #expect(ImageFormat.forPath("README") == nil)
        #expect(ImageFormat.forPath("Package.resolved") == nil)
    }

    @Test
    func `given a vector image when asking its format then it names none`() {
        // given - when - then — an SVG is text, diffs as text, and reading it as bytes would replace
        // a diff a reader can act on with a picture they cannot.
        #expect(ImageFormat.forPath("Art/icon.svg") == nil)
    }

    @Test
    func `given a dotfile named like an extension when asking its format then it names none`() {
        // given - when - then — `.png` is a file called png with no extension at all.
        #expect(ImageFormat.forPath(".png") == nil)
    }

    @Test
    func `given a directory that looks like an extension when asking its format then it names none`() {
        // given - when - then — the same trap `LanguageHint` documents: without the separator check
        // this path claims an extension of `2/hero`.
        #expect(ImageFormat.forPath("assets/v1.2/hero") == nil)
    }

    // MARK: - What a format is served as

    @Test
    func `given a format when asking its media type then it is the one the phone decodes it by`() {
        // given - when - then
        #expect(ImageFormat.png.mediaType == "image/png")
        #expect(ImageFormat.jpeg.mediaType == "image/jpeg")
        #expect(ImageFormat.gif.mediaType == "image/gif")
        #expect(ImageFormat.heic.mediaType == "image/heic")
        #expect(ImageFormat.tiff.mediaType == "image/tiff")
        #expect(ImageFormat.bmp.mediaType == "image/bmp")
        #expect(ImageFormat.webp.mediaType == "image/webp")
    }

    // MARK: - Which sides a reader can be shown

    @Test
    func `given a file that arrived when asking its sides then only the working copy has one`() {
        // given - when - then
        #expect(ImageSides.forStatus(.added) == .onlyNew)
        #expect(ImageSides.forStatus(.untracked) == .onlyNew)
        #expect(ImageSides.onlyNew.sides == [.new])
    }

    @Test
    func `given a file that was removed when asking its sides then only the committed one has one`() {
        // given - when - then
        #expect(ImageSides.forStatus(.deleted) == .onlyOld)
        #expect(ImageSides.onlyOld.sides == [.old])
    }

    @Test
    func `given a file that was replaced when asking its sides then both have one`() {
        // given - when - then
        #expect(ImageSides.forStatus(.modified) == .both)
        #expect(ImageSides.forStatus(.renamed) == .both)
        #expect(ImageSides.forStatus(.typeChanged) == .both)
        #expect(ImageSides.forStatus(.conflicted) == .both)
        // Old first, because the diff reads left to right and so does the card.
        #expect(ImageSides.both.sides == [.old, .new])
    }

    @Test
    func `given any sides when asking whether a side is in them then it answers from the same list`() {
        // given - when - then — the card asks this per side rather than walking the list.
        #expect(ImageSides.onlyNew.contains(.new))
        #expect(ImageSides.onlyNew.contains(.old) == false)
        #expect(ImageSides.both.contains(.old))
    }
}
