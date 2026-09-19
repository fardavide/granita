import ClientViewerDomain

/// Which appearance the reader has asked the app to draw in.
///
/// **`system` is the default and it is a real answer rather than the absence of one**, which is why
/// it is a case rather than an optional: a reader who has never opened this screen has chosen to
/// follow their phone, and a reader who chooses it back has made the same choice deliberately. An
/// optional would make those two states indistinguishable and would put the word *System* on a
/// segment that means *nil*.
///
/// A domain spelling rather than SwiftUI's `ColorScheme?`, for the reason `HighlightAppearance` is
/// one too: what this is stored as, and what it does to the lexer, are decided in places that have no
/// view.
public enum AppAppearance: String, Hashable, Sendable, CaseIterable {

    case system
    case light
    case dark

    public static let `default` = AppAppearance.system

    /// What the segment says.
    public var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// Which half of a pair this appearance is drawing, or nothing when the phone decides.
    ///
    /// **`nil` for `system` rather than a guess**, because the answer then belongs to an environment
    /// no domain type can read. The preview's *in use* marker resolves it against the live
    /// `colorScheme` at the point where one exists — which is the whole reason this returns an
    /// optional rather than defaulting to light.
    public var highlightAppearance: HighlightAppearanceChoice {
        switch self {
        case .system: .followsTheSystem
        case .light: .forced(.light)
        case .dark: .forced(.dark)
        }
    }
}

/// Whether the appearance is settled here or settled by the phone.
///
/// A two-case enum rather than an optional, so that a caller that forgets the environment cannot
/// quietly treat *follows the system* as *light* — `SPEC.md` has one of those already and it cost
/// four releases of a preview drawn in the wrong half.
public enum HighlightAppearanceChoice: Hashable, Sendable {

    case followsTheSystem
    case forced(HighlightAppearance)

    /// Which half is being drawn, given what the environment currently reports.
    public func resolved(whenFollowing system: HighlightAppearance) -> HighlightAppearance {
        switch self {
        case .followsTheSystem: system
        case .forced(let appearance): appearance
        }
    }
}
