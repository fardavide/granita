import Synchronization

import ClientSettingsDomain

/// The Home Screen's icon, in memory.
///
/// **It records what it was asked to show**, because one thing the model must get right is not asking
/// at all: iOS answers every successful change with an alert, so a tap on the icon already shown would
/// interrupt the reader to announce that nothing changed.
final class FakeAppIconSwitcher: AppIconSwitcher, Sendable {

    private let state: Mutex<State>

    init(canChangeIcon: Bool = true, current: AppIcon = .default, refusal: AppIconRefusal? = nil) {
        state = Mutex(State(canChangeIcon: canChangeIcon, current: current, refusal: refusal, shown: []))
    }

    var canChangeIcon: Bool { state.withLock { $0.canChangeIcon } }

    /// Every icon the model asked for, in order.
    var requested: [AppIcon] { state.withLock { $0.shown } }

    /// The system recovering, so the next change goes through.
    func stopRefusing() {
        state.withLock { $0.refusal = nil }
    }

    func currentIcon() -> AppIcon { state.withLock { $0.current } }

    func show(_ icon: AppIcon) async throws(AppIconRefusal) {
        let refusal = state.withLock { state in
            state.shown.append(icon)
            if state.refusal == nil { state.current = icon }
            return state.refusal
        }
        if let refusal { throw refusal }
    }

    // MARK: -

    private struct State {
        var canChangeIcon: Bool
        var current: AppIcon
        var refusal: AppIconRefusal?
        var shown: [AppIcon]
    }
}
