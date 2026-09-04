#if canImport(UIKit)
import UIKit
#endif

import ClientViewerDomain

/// The system pasteboard, which on the phone is the whole of what *Copy review* does.
///
/// **Every line here is a call on the running application**, which is the bar the two Keychain
/// stores and the Mac's `AppKitSystemGestures` met before it: executing this in a test process means
/// writing into the developer's own pasteboard, and asserting it means reading the pasteboard back —
/// so it is exempt in the coverage report rather than untested. The decidable part was taken out
/// first, which is what makes that exemption honest: `ReviewFeedback.document` builds the string and
/// is asserted to the byte, and this puts it somewhere.
///
/// The package compiles for macOS so `make test` can run with no simulator, and on that platform the
/// call does nothing — not as a stub, but because nothing there can reach it: the review is a phone
/// screen, `ClientAppMain` is the only module that constructs this, and the Mac's shell does not link
/// it. An `NSPasteboard` branch here would be a second implementation that no code path enters.
public struct UiKitReviewPasteboard: ReviewPasteboard {

    public init() {}

    public func copy(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
    }
}
