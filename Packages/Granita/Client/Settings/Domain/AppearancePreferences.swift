import ClientViewerDomain

/// Where this device keeps the three things it decides for itself.
///
/// **Device-local and deliberately not the Mac's.** The Mac owns what a review *says*; this phone
/// owns what this device *shows*. Neither of these travels on the wire, neither is in
/// `StoreDocument`, neither bumps the schema and neither has a compatibility answer to give — which
/// is why the section that sets them is the only one on that sheet with no queued state, no refusal
/// and no amber dot. A closed laptop cannot make either of them wrong.
///
/// **Global rather than per-Mac**, which the section's own footer wording already allows for: a
/// reader who prefers GitHub's colours prefers them for every Mac they read from.
///
/// Synchronous because it is a local read that answers from memory, the same shape
/// `WorktreeListPreferences` already has. A protocol rather than `UserDefaults` in the model because
/// a model that reaches for a global is one no test can set up twice.
public protocol AppearancePreferences: Sendable {

    func appearance() -> AppAppearance
    func remember(_ appearance: AppAppearance)

    func codeTheme() -> CodeTheme
    func remember(_ theme: CodeTheme)

    /// Whether a paired run opens into two columns, which is design §4.5's call 6.
    ///
    /// **Global, device-local and remembered**, for exactly the reasons the two above it are: it is
    /// how *this reader* reads rather than a fact about the review, so there is no `StoreDocument`
    /// field, no wire, and no compatibility answer for an older Mac. Per-file was rejected as eleven
    /// decisions in an eleven-file pass; per-worktree as making the reader restate a posture they
    /// have already stated every time they open the next worktree.
    ///
    /// It is a setting rather than an action, which is what makes it legal to leave live on a change
    /// set with no paired run in it: pressing it then draws nothing different and still records how
    /// the next change set should open. Davide settled that on 22 September 2026.
    func isSideBySide() -> Bool
    func remember(isSideBySide: Bool)
}
