#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

import ClientViewerDomain

/// The system pasteboard, which is the whole of what *Copy review* does.
///
/// **On macOS this used to be an empty `#if`**, on the argument that the review is a phone screen and
/// the Mac's shell does not link this module. Issue #73 made the second half false: the Client has a
/// Mac destination now, so the same filled indigo button that turns green for two seconds was
/// reporting a copy that had not happened — a control that looks like it worked and did nothing,
/// which this project treats as worse than a crash.
///
/// **Fire and forget, and it still does not answer.** `ReviewPasteboard` is deliberately sync and
/// non-throwing: neither framework can refuse, and a `Bool` nobody could produce a `false` for would
/// be a state no screen could draw. The decidable half is `ReviewFeedback.document`, which is pure and
/// asserted to the byte; this puts it somewhere.
///
/// **The pasteboard is named rather than assumed**, which is what took this file out of the set the
/// coverage report has to excuse: a suite may not write the developer's clipboard on every
/// `make test`, so a test names its own board and reads it back.
public struct SystemReviewPasteboard: ReviewPasteboard {

    #if canImport(AppKit)
    private let name: NSPasteboard.Name

    public init(name: NSPasteboard.Name = .general) {
        self.name = name
    }
    #else
    public init() {}
    #endif

    public func copy(_ text: String) {
        #if canImport(AppKit)
        let pasteboard = NSPasteboard(name: name)
        // Required before every write: `NSPasteboard` accumulates types, so a `setString` onto a board
        // still holding an older declaration is refused rather than appended.
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        #elseif canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
    }
}
