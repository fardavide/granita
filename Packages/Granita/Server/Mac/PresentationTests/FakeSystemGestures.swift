import Foundation

import ServerMacDomain

/// A folder picker with nobody at the keyboard.
///
/// The whole reason the picker is behind a protocol: what a reader chose, and whether they chose at
/// all, is the branch every one of these flows turns on — and it used to be an `NSOpenPanel` call in
/// a view body, where no test could supply either answer.
actor FakeFolderPicking: FolderPicking {

    private(set) var prompts: [String] = []

    private let folder: URL?

    /// `nil` is the reader changing their mind, which is the case worth being the default: it is the
    /// one a test forgets to write and the one that must leave everything alone.
    init(folder: URL?) {
        self.folder = folder
    }

    func pickFolder(prompt: String, message: String) -> URL? {
        prompts.append(prompt)
        return folder
    }
}

/// The system around the app, recorded rather than performed.
actor FakeSystemGestures: SystemGestures {

    private(set) var copied: [String] = []
    private(set) var revealed: [URL] = []
    private(set) var opened: [SystemSettingsPane] = []

    /// Counted rather than flagged, because *Open in Console* is a button a reader presses twice
    /// when the first press appeared to do nothing — and a `Bool` cannot tell those apart.
    private(set) var consoleOpenings = 0

    /// Counted rather than performed, which is the only way this one can be tested at all: the real
    /// conformer ends the process.
    private(set) var quits = 0

    func copyToPasteboard(_ text: String) {
        copied.append(text)
    }

    func revealInFinder(_ url: URL) {
        revealed.append(url)
    }

    func openSystemSettings(_ pane: SystemSettingsPane) {
        opened.append(pane)
    }

    func openConsole() {
        consoleOpenings += 1
    }

    func quit() {
        quits += 1
    }
}
