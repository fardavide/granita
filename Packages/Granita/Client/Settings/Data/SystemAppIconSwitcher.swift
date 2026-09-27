import Foundation
#if canImport(UIKit)
import UIKit
#endif

import ClientSettingsDomain

/// The Home Screen icon, as `UIApplication` keeps it — and, on a Mac, the one icon there is.
///
/// **A Mac answers that the icon cannot change.** macOS has no alternate app icons: a running app can
/// repaint its Dock tile, but Finder, Spotlight and the Dock at rest keep the icon in the bundle, so a
/// chooser there would change one of four places and look broken in the other three. Davide's call,
/// 27 September 2026: the Mac ships the glass and has no setting.
public struct SystemAppIconSwitcher: AppIconSwitcher {

    public init() {}

    /// What the system calls `icon`: `nil` for the app's own icon, otherwise the name of an alternate
    /// icon set in the asset catalog. **A storage contract with `project.yml` and `make icons`**, which
    /// build the set under this name — spelled once, here.
    public static func alternateName(for icon: AppIcon) -> String? {
        switch icon {
        case .granita: nil
        case .iceCube: "AppIcon-IceCube"
        }
    }

    /// Which icon a name the system reports means. A name this build does not know means the icon it
    /// ships as its own, which is also what the Home Screen falls back to when a set is missing.
    public static func icon(forAlternateName name: String?) -> AppIcon {
        AppIcon.allCases.first { alternateName(for: $0) == name } ?? .default
    }

    #if canImport(UIKit)
    public var canChangeIcon: Bool {
        UIApplication.shared.supportsAlternateIcons
    }

    public func currentIcon() -> AppIcon {
        Self.icon(forAlternateName: UIApplication.shared.alternateIconName)
    }

    public func show(_ icon: AppIcon) async throws(AppIconRefusal) {
        do {
            try await UIApplication.shared.setAlternateIconName(Self.alternateName(for: icon))
        } catch {
            // The system's words with its code appended, for the small print the chooser draws under
            // its own sentence — never in place of it.
            let failure = error as NSError
            throw AppIconRefusal(reason: "\(failure.localizedDescription) (\(failure.domain) \(failure.code))")
        }
    }
    #else
    public var canChangeIcon: Bool { false }

    public func currentIcon() -> AppIcon { .default }

    public func show(_ icon: AppIcon) async throws(AppIconRefusal) {
        throw AppIconRefusal(reason: "This device shows the icon Granita was built with.")
    }
    #endif
}
