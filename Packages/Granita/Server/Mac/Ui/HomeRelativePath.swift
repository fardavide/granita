import Foundation

/// A path as a reader would say it: the home directory as a tilde, and no trailing separator.
///
/// Three panes print a path — the data folder on Advanced, a project's folder on Projects, and the
/// folder a scan was aimed at — and until this existed each spelled it slightly differently.
///
/// **The trailing separator is the one that bites, and it took running the app to see it.** A folder
/// that came back from `NSOpenPanel` is a directory URL and prints as `~/Developer/granita/`, while
/// the same folder read from the store prints without the slash: the same place, spelled two ways,
/// sometimes one line apart. Everything that *stores* a path already trims it, because an identifier
/// is a hash of the string; this is the same rule applied to what is read.
func homeRelative(_ path: String) -> String {
    var trimmed = path
    if trimmed.count > 1, trimmed.hasSuffix("/") { trimmed.removeLast() }
    let home = NSHomeDirectory()
    guard trimmed.hasPrefix(home) else { return trimmed }
    return "~" + trimmed.dropFirst(home.count)
}

func homeRelative(_ url: URL) -> String {
    homeRelative(url.standardizedFileURL.path(percentEncoded: false))
}
