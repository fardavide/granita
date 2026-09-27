/// Which drawing the Home Screen shows for this app.
///
/// **The glass is the app's own icon and the cube is an alternate**, which is the whole of the
/// difference between them: the system shows the glass until it is told otherwise, and a Mac shows
/// nothing else, because macOS has no alternate icons for Finder to follow.
public enum AppIcon: String, Hashable, Sendable, CaseIterable {

    /// A glass of granita whose syrup layers are a diff's rows.
    case granita

    /// The diff frozen in an ice cube with a straw in it — the wintry one. Davide, 27 September 2026:
    /// *"more of a Christmas version"*.
    case iceCube

    public static let `default` = AppIcon.granita

    /// What the chooser says beside the drawing.
    public var displayName: String {
        switch self {
        case .granita: "Granita"
        case .iceCube: "Ice Cube"
        }
    }
}

/// Whether this device can change its icon at all, and what the chooser shows if it can.
///
/// **Two levels rather than one flat enum**, so the chooser can take what it draws without a case it
/// could never be opened in: a device that cannot change its icon has no row to push from.
public enum AppIconStanding: Hashable, Sendable {

    /// A Mac. The row is **absent** rather than disabled: there is nothing a reader could do about it,
    /// and Finder would keep the shipped icon whatever was chosen, which is a control that visibly
    /// does nothing.
    case unavailable

    case available(AppIconChoice)
}

/// What the Home Screen is showing, and whether the last attempt to change it was refused.
public enum AppIconChoice: Hashable, Sendable {

    case showing(AppIcon)

    /// **The icon the system kept, not the one asked for.** The checkmark has to stay where the Home
    /// Screen is; the reason is the system's own words, shown underneath as small print.
    case refused(showing: AppIcon, reason: String)

    /// Which row carries the checkmark.
    public var shown: AppIcon {
        switch self {
        case .showing(let icon), .refused(showing: let icon, reason: _): icon
        }
    }
}
