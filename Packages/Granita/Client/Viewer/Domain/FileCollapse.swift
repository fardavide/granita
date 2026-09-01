import CoreDiffDomain

/// Why a file in the continuous scroll is drawn as a bar rather than as a diff.
///
/// **Design §4 calls this the one thing the specification does not name**, and makes the case for it
/// plainly: without the reason the reader has to open a file to learn there was nothing in it, which
/// is the exact cost collapsing was supposed to save. With it, a run of six bars is readable at a
/// glance and three of the six never need opening.
public enum CollapsedFileReason: Hashable, Sendable {

    /// The reader's own mark, which is the one this whole product is for. `SPEC.md` §10: a file
    /// marked viewed renders collapsed.
    case viewed

    /// Longer than this client fetches unasked, so the bar is also the affordance that fetches it.
    case tooLong(lines: Int)

    /// Nothing behind it, ever.
    case binary

    /// A file that moved and did not change. Carries the **filename** it moved from rather than the
    /// path: the reader is being told which file this used to be, and in the ordinary case the
    /// directory it left is the one it arrived in.
    case renamedWithNoContentChange(from: String)
}

/// Whether a file's diff is drawn, and whether the reader may change that.
///
/// The three answers travel together because they are read together: a bar draws its chevron from
/// the second and its sentence from the third, and a bar that offers a chevron over nothing is the
/// smallest possible lie design §4 refuses.
public struct FileCollapse: Hashable, Sendable {

    public let isCollapsed: Bool

    /// Whether there is anything behind the bar. False for a binary file and for a rename that
    /// changed nothing — both get **no chevron at all** rather than a dimmed one.
    public let isCollapsible: Bool

    /// What the bar says under the path, and `nil` when there is nothing true to put there.
    ///
    /// Absent while the file is open, because a reason is a thing a bar prints and there is no bar;
    /// and absent for a file the reader shut by hand, because telling them they shut it is a line
    /// that says nothing.
    public let reason: CollapsedFileReason?

    public init(isCollapsed: Bool, isCollapsible: Bool, reason: CollapsedFileReason?) {
        self.isCollapsed = isCollapsed
        self.isCollapsible = isCollapsible
        self.reason = reason
    }
}

/// Which files the scroll draws shut, from what the change set says about them and what the reader
/// has since said back.
///
/// A pure function in `Domain` rather than a property on the model, for the reason `FileSelector`
/// and `ContinuousDiffLoading` are: this is what a specification section is about, and a policy
/// buried in a model is a policy nobody tests directly.
public enum FileCollapsing {

    /// Where `SPEC.md` §10's "files over 500 diff lines start collapsed" puts the line.
    ///
    /// It is also what the loader defers on, so the number decides two things rather than one: how
    /// big a file has to be before the reader is asked whether they want it, and how big before this
    /// phone stops spending a batch slot on it unasked.
    public static let longDiffLineCount = 500

    /// - Parameter openedByTheReader: The reader's own answer where they have given one, and `nil`
    ///   where they have not. **Not a `Bool` defaulting to the automatic answer**: the difference
    ///   between "the reader wants this open" and "nobody has said" is what makes marking a file
    ///   read able to shut it again afterwards.
    public static func state(of file: FileChange, openedByTheReader: Bool?) -> FileCollapse {
        let reason = automaticReason(of: file)
        switch reason {
        case .binary, .renamedWithNoContentChange:
            // Shut, and with nothing to press: these two are why `isCollapsible` exists.
            return FileCollapse(isCollapsed: true, isCollapsible: false, reason: reason)
        case .viewed, .tooLong, nil:
            let isCollapsed = if let openedByTheReader { openedByTheReader == false } else { reason != nil }
            return FileCollapse(
                isCollapsed: isCollapsed,
                isCollapsible: true,
                reason: isCollapsed ? reason : nil
            )
        }
    }

    /// The reason the app would shut this file for, whatever the reader has said since.
    ///
    /// **Ordered by which one is worth reading**, not by which is checked most cheaply. The two that
    /// mean "there is nothing behind this" come first, because they tell the reader not to open the
    /// file; the mark comes next, because it is this product's one job and a reader who has read a
    /// long file does not need to be told how long it was.
    private static func automaticReason(of file: FileChange) -> CollapsedFileReason? {
        if file.isBinary {
            return .binary
        }
        if file.status == .renamed,
           file.stats.insertions == 0,
           file.stats.deletions == 0,
           // A rename the Mac could not name is a sentence with a hole in it, and shutting a file
           // behind one is worse than opening a diff with nothing in it.
           let oldPath = file.oldPath {
            return .renamedWithNoContentChange(from: DiffFilePath.name(of: oldPath))
        }
        if file.isViewed {
            return .viewed
        }
        if file.estimatedLineCount > longDiffLineCount {
            return .tooLong(lines: file.estimatedLineCount)
        }
        return nil
    }

}
