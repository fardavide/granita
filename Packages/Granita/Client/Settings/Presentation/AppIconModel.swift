import Observation

import ClientSettingsDomain

/// Which icon the Home Screen shows, and the one setting in the *Appearance* section that can fail.
///
/// **Its own model rather than a fifth value on `AppearanceModel`**, split by what it wraps: that one
/// wraps this device's defaults and is documented as unable to fail, and this one wraps the system,
/// which can refuse. Folding it in would make the other model's central promise untrue.
///
/// **Made once for the life of the app**, like `AppearanceModel`: the icon is a fact about this device,
/// not about the Mac the sheet was opened from.
@Observable
public final class AppIconModel {

    public private(set) var standing: AppIconStanding

    private let switcher: any AppIconSwitcher

    public init(switcher: any AppIconSwitcher) {
        self.switcher = switcher
        standing = switcher.canChangeIcon ? .available(.showing(switcher.currentIcon())) : .unavailable
    }

    /// Asks the system for `icon`, and moves the checkmark only once it agrees.
    ///
    /// **No saving state.** The change takes a moment and iOS confirms it with its own alert, so a
    /// spinner would stand in front of the system's answer for a fraction of a second and then be
    /// covered by it.
    public func choose(_ icon: AppIcon) async {
        guard case .available(let choice) = standing else { return }
        // Tapping the ticked row asks nothing: iOS answers every change with an alert, and this one
        // would interrupt the reader to announce that nothing happened.
        guard icon != choice.shown else { return }
        do {
            try await switcher.show(icon)
            standing = .available(.showing(icon))
        } catch {
            standing = .available(.refused(showing: choice.shown, reason: error.reason))
        }
    }
}
