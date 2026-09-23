import SwiftUI

/// Whether a paired run opens into two columns, and how the reader changes it.
///
/// **A value and its setter together, because the control that reads this is the control that writes
/// it.** The code theme's environment entry is read-only and set on a Settings sheet two navigations
/// away; this one is a toolbar toggle sitting on the screen it changes, so splitting the read from
/// the write would put half of one control in the environment and half in a callback.
public struct SideBySideSetting {

    public let isOn: Bool

    /// How to change it, or **nothing at all where no composition root has set one**.
    ///
    /// Optional rather than a no-op default, and that is the whole reason this type exists rather
    /// than a plain `Bool`. A default that silently discarded the reader's tap would be a toolbar
    /// item that looks operable and does nothing — the defect this project shipped for eight
    /// releases and now refuses. Absent instead, the toggle is not rendered at all, which is the
    /// first of the permitted answers and the one a missing wiring should give.
    public let choose: ((Bool) -> Void)?

    public init(isOn: Bool, choose: ((Bool) -> Void)? = nil) {
        self.isOn = isOn
        self.choose = choose
    }
}

public extension EnvironmentValues {

    /// The split mode, for every screen below the one that set it.
    ///
    /// **The environment rather than an initialiser parameter, for the reason `codeTheme` carries in
    /// full**: `WorktreeDiffScreen` pins its model in `@State`, so anything handed in at construction
    /// is frozen at the moment the screen was first built — and this is a value the reader changes
    /// while a diff is open.
    ///
    /// Defaulted to off with no setter: a screen rendered without a root that sets this is a snapshot
    /// subject or a preview, and neither has anywhere to write a preference to.
    @Entry var sideBySide = SideBySideSetting(isOn: false)
}
