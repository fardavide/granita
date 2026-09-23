import SwiftUI

import ClientViewerDomain

public extension EnvironmentValues {

    /// What *Follow system* follows, as the domain's own spelling of `DynamicTypeSize`.
    ///
    /// **Carried rather than read from `dynamicTypeSize` here, because the mapping onto it can only
    /// exist once.** Two features need the reader's text size — this one to draw the code, and the
    /// settings sheet to say what the code size buys in characters — and they are siblings over
    /// `Domain` rather than a pipeline, so neither may import the other's `Ui`. The composition root
    /// is the one module that may see both, so the switch lives on the settings side and the answer
    /// travels here.
    @Entry var readerTextSize = ReaderTextSize.default

    /// How big the reader has asked the code to be, in the two halves issue #106 splits it into.
    ///
    /// **Read-only here, like the code theme and unlike the split mode**: this one is set two
    /// navigations away on a Settings screen rather than by a control standing on the diff, so there
    /// is no setter to travel with it. The environment rather than an initialiser parameter for
    /// `codeTheme`'s reason exactly — `WorktreeDiffScreen` pins its model in `@State`, so anything
    /// handed in at construction is frozen at the moment the screen was first built, and this is a
    /// value the reader changes and comes back to a live diff with.
    ///
    /// Defaulted to both halves following the system, which at Large is what shipped before the
    /// setting existed: a screen rendered without a root that sets this is a snapshot subject or a
    /// preview, and both want the design's own numbers.
    @Entry var codeSize = CodeSize.default
}
