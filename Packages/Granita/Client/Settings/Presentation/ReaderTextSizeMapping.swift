import SwiftUI

import ClientViewerDomain

public extension ReaderTextSize {

    /// SwiftUI's twelve steps, as the domain's own.
    ///
    /// **The mapping exists because `Domain` may not see SwiftUI**, which is the same split
    /// `HighlightAppearance` makes against `ColorScheme`. **It exists in this feature because it can
    /// only exist once**: the diff needs the reader's text size to draw the code and this sheet needs
    /// it to say what a size buys, and the two features are siblings over `Domain` rather than a
    /// pipeline — so the one that gathers this device's reading context owns the switch, and the
    /// composition root carries the answer across.
    ///
    /// **In `Presentation` rather than in `Ui`, and the coverage gate is the reason.** Nothing
    /// renders this — it is read at the app's root and handed on — so twelve cases in a view layer
    /// would be twelve regions no baseline can execute, and the Snapshot row is measured over
    /// exactly those files. Here it is a named function the Unit row judges and a test calls.
    ///
    /// It is total over the cases that exist and carries an `@unknown default` because
    /// `DynamicTypeSize` is another module's non-frozen enum — the one place this project's
    /// no-`default:` rule cannot reach, since nothing can enumerate what a later iOS adds. A
    /// thirteenth step reads as Large, which is the size every measurement in design §4 was taken
    /// at.
    init(_ size: DynamicTypeSize) {
        switch size {
        case .xSmall: self = .xSmall
        case .small: self = .small
        case .medium: self = .medium
        case .large: self = .large
        case .xLarge: self = .xLarge
        case .xxLarge: self = .xxLarge
        case .xxxLarge: self = .xxxLarge
        case .accessibility1: self = .accessibility1
        case .accessibility2: self = .accessibility2
        case .accessibility3: self = .accessibility3
        case .accessibility4: self = .accessibility4
        case .accessibility5: self = .accessibility5
        @unknown default: self = .default
        }
    }
}
