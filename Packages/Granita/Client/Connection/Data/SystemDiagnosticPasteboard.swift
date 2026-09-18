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
///
/// **Both platforms take a name now, and on iOS that is a fix rather than symmetry.** The UIKit
/// branch wrote `UIPasteboard.general` unconditionally, so the only way to assert it was for a test
/// to save the shared pasteboard, write it, read it back and put it in place again. That test
/// blocked the whole phone snapshot suite indefinitely — the general pasteboard is a system service
/// shared with everything else on the simulator, and reading `items` off it waits on a daemon that
/// does not always answer. A named board is private to this process and cannot wait on anybody.
public struct SystemDiagnosticPasteboard: DiagnosticPasteboard {

    #if canImport(AppKit)
    private let name: NSPasteboard.Name

    public init(name: NSPasteboard.Name = .general) {
        self.name = name
    }
    #elseif canImport(UIKit)
    /// The board to write, or nothing for the one a reader actually pastes from.
    ///
    /// A name rather than a `UIPasteboard`, for the reason the AppKit branch holds one: the instance
    /// is not `Sendable` and this type is, so what travels is the identifier and the board is made
    /// where it is used.
    private let name: UIPasteboard.Name?

    public init(name: UIPasteboard.Name? = nil) {
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
        let name = name
        await MainActor.run {
            // `create: true` because a named board a test asked for may not exist yet, and the
            // fallback is the general one so a name that cannot be made still copies rather than
            // silently doing nothing — this is *Copy Logs*, and a reader pressing it with nothing on
            // their clipboard afterwards is the worst outcome available.
            let pasteboard = name.flatMap { UIPasteboard(name: $0, create: true) } ?? .general
            pasteboard.string = text
        }
        #else
        throw .unavailable
        #endif
    }
}
