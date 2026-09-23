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

    /// How big the code is drawn, in the two halves issue #106 splits it into.
    public private(set) var codeSize: CodeSize

    /// How wide a row of code is on this device, which is what a point size buys its characters out
    /// of.
    ///
    /// **Measured rather than assumed, and held here because two screens need one answer.** The
    /// *Code size* screen states what a size produces in characters and is a sheet, so it cannot see
    /// the diff pane it is describing; the app's root can, because it is the window. Zero until a
    /// first render reports one — an invented 390 would have the screen quote a phone's numbers on
    /// an iPad.
    public private(set) var diffRowWidth: CGFloat = 0

    /// Whether a selector column fits beside the code here, which is what decides whether *Follow
    /// system* is based on eleven points or twelve.
    public private(set) var fitsSelectorColumn = false

    /// What *Follow system* follows. Held here rather than read where it is needed, because the diff
    /// and this sheet are siblings over `Domain` and only one of them may own the mapping onto
    /// SwiftUI's enum.
    public private(set) var textSize = ReaderTextSize.default

    public init(preferences: any AppearancePreferences) {
        self.preferences = preferences
        appearance = preferences.appearance()
        codeTheme = preferences.codeTheme()
        isSideBySide = preferences.isSideBySide()
        codeSize = preferences.codeSize()
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

    /// What the *Code size* screen shows, for both halves at once.
    ///
    /// **Here rather than in the screen that draws it**, because what a point size buys in characters
    /// is arithmetic over the gutter, the gap and the rule — and a composed screen's body is a place
    /// no host test can reach. The model holds all four inputs already, so this is the one line that
    /// puts them together.
    public var codeSizeReadout: CodeSizeReadout {
        CodeSizeReadout(
            codeSize: codeSize,
            textSize: textSize,
            fitsSelectorColumn: fitsSelectorColumn,
            rowWidth: diffRowWidth
        )
    }

    /// Both halves at once, because the screen that sets them holds both and a write per half would
    /// let a crash between the two leave a reader with one setting from each of two decisions.
    public func choose(_ size: CodeSize) {
        codeSize = size
        preferences.remember(size)
    }

    /// What the window is, told by the one view that is the window.
    ///
    /// **The tree's width comes off it wherever a tree could be, open or not** — which is
    /// `DiffPaneLayout`'s own rule taken to its conclusion: a size derived from the folded width
    /// would change every time the fold did, and re-lex the file the reader is halfway down.
    public func note(windowWidth: CGFloat, fitsSelectorColumn: Bool, textSize: ReaderTextSize) {
        diffRowWidth = DiffPaneLayout.diffRowWidth(inWindowWidth: windowWidth, fitsSelectorColumn: fitsSelectorColumn)
        self.fitsSelectorColumn = fitsSelectorColumn
        self.textSize = textSize
    }
}
