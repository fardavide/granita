import ClientViewerDomain

/// Where this device keeps the two things it decides for itself.
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
}
