/// The six panes of the Settings window, in the order design §2 puts them.
///
/// Advanced is last because that is where every Mac app puts it, and because of what shares it:
/// `Reset All Data`. Leaving the connection log there would have put the panel opened while annoyed
/// one mis-click from the button that unpairs every device.
///
/// **Review is fourth, and it is the same departure again.** `SPEC.md` §9 fixes this window at four
/// tabs; five ship, because the connection log earned its own on the argument above. The review's
/// two settings earn one on the same terms: they are their own subject, they are the only values in
/// this window a phone both reads and writes, and they are the first thing here that is not about
/// serving. The alternatives were General — whose subject is this Mac's address and whether anything
/// is listening, and which a reader opens when something is wrong — and Advanced, which would put a
/// text field about the wording of a document beside *Reset All Data*.
///
/// A `Domain` type rather than one the window keeps to itself, because two other surfaces name a
/// particular pane: a refused row in the connection log offers `Pair…`, and the menu bar's *Pair a
/// device…* opens this window on Devices. Which pane is up is a fact about the app rather than a
/// piece of one view's state, and holding it in a `@State` is what makes "the control did nothing"
/// unassertable.
///
/// The raw values are written down between launches, so they are spelled out rather than derived
/// from the case names: a rename that changed one would send a reader back to a pane they were not
/// on, silently and only on the machines that had already stored the old word.
public enum SettingsTab: String, Hashable, Sendable, CaseIterable {
    case general = "general"
    case projects = "projects"
    case devices = "devices"
    case review = "review"
    case connections = "connections"
    case advanced = "advanced"
}
