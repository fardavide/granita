import SwiftUI

import ClientViewerDomain

public extension EnvironmentValues {

    /// Which pair of stylesheets the code is lexed in, for every screen below the one that set it.
    ///
    /// **The environment rather than an initialiser parameter, because the reader can change it while
    /// a diff is open.** `WorktreeDiffScreen` pins its model in `@State` — it has to, or the iPad's
    /// split view swaps a running model out from under its own task — so a theme handed in at
    /// construction would be the theme that was current when the screen was first built and would stay
    /// that way for the life of it. An environment value read in `body` is the one path that both
    /// survives that pinning and re-evaluates.
    ///
    /// **Read beside `\.colorScheme` and for the same reason.** The two together are what the lexer is
    /// asked for, they are both facts about the surroundings rather than about the worktree, and the
    /// screen already reports one of them to its model on every change.
    ///
    /// Defaulted to Xcode's pair rather than left optional: a screen rendered without a root that sets
    /// this is a snapshot subject or a preview, and what both want is the colours the app ships with
    /// rather than an absence to branch on.
    @Entry var codeTheme: CodeTheme = .default
}
