/// The five panes of the Settings window, in the order design §2 puts them.
///
/// Advanced is last because that is where every Mac app puts it, and because of what shares it:
/// `Reset All Data`. Leaving the connection log there would have put the panel opened while annoyed
/// one mis-click from the button that unpairs every device.
///
/// A `Domain` type rather than one the window keeps to itself, because two other surfaces name a
/// particular pane: a refused row in the connection log offers `Pair…`, and the menu bar's *Pair a
/// device…* opens this window on Devices. Which pane is up is a fact about the app rather than a
/// piece of one view's state, and holding it in a `@State` is what makes "the control did nothing"
/// unassertable.
public enum SettingsTab: Hashable, Sendable, CaseIterable {
    case general
    case projects
    case devices
    case connections
    case advanced
}
