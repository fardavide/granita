/// What a reader can be shown of a file whose bytes are a picture.
///
/// **Decided from the path and from nothing else**, which is what lets both halves answer it without
/// asking each other. Git's own binary flag cannot: it is absent for an untracked file — the change
/// set builds those from `ls-files` and never diffs them — so a screenshot an agent has just written
/// would be the one image the phone refused to draw. An extension is also the only thing either side
/// knows before any bytes have been read, and the whole point is to decide whether to read them.
///
/// Nothing on the wire carries it. A `FileChange` already names the path, so a field here would be a
/// second answer to a question the client can put to itself — and a wire field is a version skew
/// where a shared function is a compile error.
public enum ImageFormat: String, Codable, Hashable, Sendable, CaseIterable {

    case png
    case jpeg
    case gif
    case heic
    case tiff
    case bmp
    case webp

    /// What the Mac serves these bytes under, and what the phone hands its image decoder.
    ///
    /// Stated rather than derived from the case name: `jpeg` and `heic` each answer for two
    /// extensions, and `image/tif` is not a type anything accepts.
    public var mediaType: String {
        switch self {
        case .png: "image/png"
        case .jpeg: "image/jpeg"
        case .gif: "image/gif"
        case .heic: "image/heic"
        case .tiff: "image/tiff"
        case .bmp: "image/bmp"
        case .webp: "image/webp"
        }
    }

    /// The format this path claims, or nothing when it claims none.
    ///
    /// **A claim rather than a fact**, and the difference is where the failure surfaces: a `.png`
    /// holding something else is refused by the decoder on the phone, which is one card saying so
    /// rather than the Mac deciding for a reader it cannot show the bytes to.
    ///
    /// **SVG is deliberately absent.** It is text, git diffs it as text, and reading it as bytes
    /// would replace a diff a reader can act on with a picture they cannot.
    public static func forPath(_ path: String) -> ImageFormat? {
        guard let dot = path.lastIndex(of: "."), dot != path.startIndex else { return nil }
        let fileExtension = path[path.index(after: dot)...].lowercased()
        // The separator check keeps `assets/v1.2/hero` from claiming an extension of `2/hero`, which
        // is the trap `LanguageHint` documents for the same reason.
        guard fileExtension.contains("/") == false else { return nil }
        return byExtension[fileExtension]
    }

    private static let byExtension: [String: ImageFormat] = [
        "png": .png,
        "jpg": .jpeg, "jpeg": .jpeg,
        "gif": .gif,
        "heic": .heic, "heif": .heic,
        "tif": .tiff, "tiff": .tiff,
        "bmp": .bmp,
        "webp": .webp
    ]
}

/// Which sides of an image file exist to be fetched.
///
/// **Three cases rather than a pair of optionals or a set**, because the fourth combination — a
/// changed file with neither side — is not a thing that can happen, and a type that can express it
/// is a card that draws two empty frames. It also decides what the full-screen view may offer: the
/// hold that swaps variants is absent on the two one-sided cases rather than present and inert,
/// which is this product's rule about controls that do nothing.
public enum ImageSides: Hashable, Sendable, CaseIterable {

    /// The file arrived, so there is nothing committed to compare it against.
    case onlyNew

    /// The file is gone, so the only copy is the committed one.
    case onlyOld

    /// The file was replaced, renamed, retyped or conflicted — two pictures.
    case both

    public static func forStatus(_ status: FileStatus) -> ImageSides {
        switch status {
        case .added, .untracked: .onlyNew
        case .deleted: .onlyOld
        case .modified, .renamed, .typeChanged, .conflicted: .both
        }
    }

    /// In the order the card draws them, which is the order the diff reads in: what was there, then
    /// what is there now.
    public var sides: [DiffSide] {
        switch self {
        case .onlyNew: [.new]
        case .onlyOld: [.old]
        case .both: [.old, .new]
        }
    }

    public func contains(_ side: DiffSide) -> Bool {
        sides.contains(side)
    }
}
