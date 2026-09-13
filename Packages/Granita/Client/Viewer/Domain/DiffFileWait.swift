/// What the one row inside a reserved card says, which is three words' worth of difference.
///
/// **Three pictures rather than one, which is the whole of design §9.** A file still coming, a file
/// that arrived with nothing and a file that failed and is never coming all drew the same blank
/// card — which is how 0.6.2's corrupted argument vector was found by hand rather than by looking.
/// Motion separates the first from the other two before any word is read, and the sentence
/// separates the second from the third.
///
/// Lower case, because this is the collapsed bar's register: a fact about the file, like `viewed`
/// or `binary · no diff to show`, rather than a sentence addressed to the reader.
public enum DiffFileWait: Hashable, Sendable, CaseIterable {

    case reading
    case stillReading
    case failed

    /// How long a batch is in flight before the row adds its second word.
    ///
    /// **One word changes, once, and then nothing moves** — which is a reversal of the elapsed clock
    /// the loading screen got. That was right where there was one wait and one spinner; here five
    /// files are in flight, so a clock would be five stopwatches ticking in a scroll.
    public static let longWait = Duration.seconds(10)

    public var sentence: String {
        switch self {
        case .reading: "reading from your Mac"
        case .stillReading: "still reading from your Mac"
        case .failed: "couldn’t read this file"
        }
    }

    /// Whether the row carries the marker column's third word, and its bars have stopped.
    public var isFailed: Bool {
        switch self {
        case .reading, .stillReading: false
        case .failed: true
        }
    }
}
