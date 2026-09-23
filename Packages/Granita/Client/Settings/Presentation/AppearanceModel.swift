import Observation
import SwiftUI

import ClientSettingsDomain
import ClientViewerDomain

/// What this device has decided about how it draws, and the only settings in the app that cannot fail.
///
/// **Nothing here is asked of a Mac, so nothing here has a standing.** There is no `load()`, no
/// in-flight state, no refusal and no queue: both values are read from this device's defaults when the
/// model is made and written back the moment the reader changes one. The sheet's other three sections
/// carry a footer sentence about what this phone and that Mac disagree about; this one carries a
/// sentence saying there is nothing to disagree about.
///
/// **Made once for the life of the app rather than per Mac**, because the reader who prefers Stack
/// Overflow's colours prefers them for every Mac they read from — and because the scene root reads the
/// appearance to decide what the whole app draws in.
@MainActor
@Observable
public final class AppearanceModel {

    private let preferences: any AppearancePreferences

    public private(set) var appearance: AppAppearance
    public private(set) var codeTheme: CodeTheme

    /// Whether a paired run opens into two columns. Design §4.5's call 6 — one flag beside the
    /// appearance and the code theme, read once and written straight through like both of them.
    public private(set) var isSideBySide: Bool

    public init(preferences: any AppearancePreferences) {
        self.preferences = preferences
        appearance = preferences.appearance()
        codeTheme = preferences.codeTheme()
        isSideBySide = preferences.isSideBySide()
    }

    /// What the whole app draws in, or nothing where the phone decides.
    ///
    /// **`nil` is what makes *System* work**, rather than a third branch that reads the environment:
    /// `preferredColorScheme(nil)` is SwiftUI's own spelling of *do not override*, so following the
    /// phone costs no code and a sunset keeps working.
    public var colorScheme: ColorScheme? {
        switch appearance {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    /// Applied here first and written straight through.
    ///
    /// Not `async` and with nothing to await: a local write answers from memory, and the alternative —
    /// a task per segment tap — would be a round trip to nowhere. This is the whole reason the section
    /// has no saving state to draw.
    public func choose(_ appearance: AppAppearance) {
        self.appearance = appearance
        preferences.remember(appearance)
    }

    public func choose(_ theme: CodeTheme) {
        codeTheme = theme
        preferences.remember(theme)
    }

    /// **Recorded whether or not anything on screen changes**, which is what makes it a setting
    /// rather than an action. A change set of nothing but new files has no paired run, so the rows
    /// draw the same either way — and the reader has still said how they want the *next* one to
    /// open. Davide, 22 September 2026.
    public func chooseSideBySide(_ isOn: Bool) {
        isSideBySide = isOn
        preferences.remember(isSideBySide: isOn)
    }
}
