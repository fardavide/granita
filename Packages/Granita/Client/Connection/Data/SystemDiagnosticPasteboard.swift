#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

import ClientConnectionDomain

/// The system pasteboard, which is the whole of what *Copy Logs* does.
///
/// **It used to refuse on macOS, and that refusal was a premise rather than a behaviour**: the phone
/// was the only shell that constructed this, so the branch stood for *nobody can get here*. Issue #73
/// gave the Client a Mac destination and made the premise false, which turned a documented
/// impossibility into an error screen a reader could reach by pressing a button that works everywhere
/// else. `DiagnosticCopyFailure.unavailable` survives for a host with neither framework — the one
/// place the original sentence is still true.
///
/// **The pasteboard is named rather than assumed**, which is the one difference from the viewer's
/// sibling and the reason this one is tested rather than exempt: a suite may not write the
/// developer's clipboard on every `make test`, so a test names its own and reads it back.
public struct SystemDiagnosticPasteboard: DiagnosticPasteboard {

    #if canImport(AppKit)
    private let name: NSPasteboard.Name

    public init(name: NSPasteboard.Name = .general) {
        self.name = name
    }
    #else
    public init() {}
    #endif

    public func copy(_ text: String) async throws(DiagnosticCopyFailure) {
        #if canImport(AppKit)
        let name = name
        await MainActor.run {
            let pasteboard = NSPasteboard(name: name)
            // Required before every write: `NSPasteboard` accumulates types, so a `setString` onto a
            // board still holding an older declaration is refused rather than appended.
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        }
        #elseif canImport(UIKit)
        await MainActor.run {
            UIPasteboard.general.string = text
        }
        #else
        throw .unavailable
        #endif
    }
}
