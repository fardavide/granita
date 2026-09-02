/// A path split into the filename and the place it lives, because the file header draws them on
/// separate lines.
///
/// **The review's sixth fault is what this exists for.** One line of head-truncated path renders
/// `…out/Presentation/Models/AboutState.swift` — which deletes the module, and the module is the one
/// thing that tells eleven files apart when three of them live in a folder called `Models`. On two
/// lines the filename is never truncated and the directory truncates in the middle, so both of its
/// ends survive.
///
/// Split on `/` rather than through `URL`: `FileChange.path` is a POSIX path for a file on another
/// machine, and a filesystem type over a string that deliberately never touches this device's
/// filesystem answers questions nobody asked.
public enum DiffFilePath {

    /// The last component, which is what identifies the file.
    public static func name(of path: String) -> String {
        String(path.split(separator: "/").last ?? "")
    }

    /// Everything above the name, with no trailing separator — the line under the filename is a
    /// place, not a prefix of it.
    ///
    /// Empty for a file at the repository root, so the header can drop the second line entirely
    /// rather than draw one that says nothing.
    public static func directory(of path: String) -> String {
        path.split(separator: "/").dropLast().joined(separator: "/")
    }
}
