import Foundation

/// What the menu bar app was told on the command line.
///
/// **Both flags exist so that a behavioural test can drive this app without driving the reader's
/// own document**, and that is the whole justification. Granita has no window until its menu is
/// opened and no store but the one in Application Support, so a UI test with neither flag would
/// switch a real repository on, on a real Mac, and leave it that way.
///
/// `--store` is spelled exactly as `granita-server` already spells it, and is not gated behind a
/// debug build. Two reasons: the shipped executable has taken this flag since M2, so a released
/// Granita already honours it on the other side of the same document; and a branch a release build
/// never executes is a branch nobody has run when it matters. It grants nothing either — anything
/// able to pass this app an argument can write the document directly.
public struct MacLaunchOptions: Hashable, Sendable {

    /// Where the JSON document lives, when something said. `nil` is the ordinary launch, and the
    /// fallback deliberately stays in the composition root rather than being defaulted here: this
    /// type reports what it was told, and where the document lives when nobody said is a fact about
    /// how the app is installed.
    public let storeUrl: URL?

    /// Whether to put Settings on screen without waiting for the menu.
    ///
    /// The menu is otherwise the only route in, and a test that has to click a status item is a test
    /// that fails for a reason having nothing to do with what it is asserting.
    public let opensSettingsAtLaunch: Bool

    public init(_ arguments: some Sequence<String>) {
        let arguments = Array(arguments)
        // Unknown arguments are ignored rather than refused, and that is not laxity: XCTest appends
        // its own argv to every launch it makes, so a parser that objected to what it did not
        // recognise would refuse every launch a UI test performs.
        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
            return arguments[index + 1]
        }
        storeUrl = value(after: "--store").map { URL(filePath: $0) }
        opensSettingsAtLaunch = arguments.contains("--open-settings")
    }
}
