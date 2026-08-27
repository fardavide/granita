import CoreDiffDomain

/// Which files the one continuous scroll asks the Mac for next.
///
/// **This is the whole of `SPEC.md` §10's trap, expressed as an ordering.** A lazy stack estimates
/// the height of everything it has not drawn; when a placeholder becomes real content its height
/// changes and everything after it moves. Below the viewport that is invisible and estimates need
/// only be reasonable. *Above* the viewport it is the visible content jumping under the reader's
/// finger, which is the defect that kills naive implementations of this screen.
///
/// So loading is strictly forward. Nothing behind the reader is ever fetched, and a file that was
/// skipped stays skipped — a gap above the viewport is a placeholder whose estimate nobody will
/// contradict, and that is a better screen than one that reflows to correct it.
public enum ContinuousDiffLoading {

    /// How far ahead of the file being read to fetch, and it is a count of *files* rather than of
    /// positions: one already in hand costs nothing to step over.
    ///
    /// Five, from `SPEC.md` §8, and it has to stay under the twenty identifiers `/diffs` accepts in
    /// one request — the refusal for exceeding that arrives from the other machine, so the bound is
    /// asserted on this side.
    public static let filesAhead = 5

    /// The next files worth asking for, in document order, or nothing when there is no work.
    ///
    /// - Parameters:
    ///   - visible: The index of the file the reader is on. Clamped rather than trusted: a
    ///     rubber-band above the first row is a real reading, and a change set replaced under a
    ///     scroll that has not been told yet is a real index past the end.
    ///   - files: Every changed file, in the order the scroll draws them.
    ///   - held: What is already in hand. A measured height is sticky for the session, so this
    ///     never shrinks and a file is never fetched twice.
    ///   - inFlight: What has been asked for and not answered. Scrolling produces a position update
    ///     per frame, and without this every frame would re-ask for the same file.
    ///   - deferred: Files the scroll is drawing shut. **Unlike `held`, this shrinks**: a reader
    ///     opening a bar takes a file out of it, which is what makes the bar's own *Load diff* true
    ///     rather than a label on something that was fetched anyway. `SPEC.md` §10 asks for that
    ///     affordance by name on a file over 500 diff lines, and a phone that had already spent a
    ///     batch slot on 1,558 lines nobody asked to see would be offering to do what it had done.
    public static func next(
        from visible: Int,
        of files: [FileID],
        held: Set<FileID>,
        inFlight: Set<FileID>,
        deferred: Set<FileID>
    ) -> [FileID] {
        guard files.isEmpty == false, visible < files.count else { return [] }
        return files[max(0, visible)...]
            .filter { file in
                held.contains(file) == false
                    && inFlight.contains(file) == false
                    && deferred.contains(file) == false
            }
            .prefix(filesAhead)
            .map { $0 }
    }
}
