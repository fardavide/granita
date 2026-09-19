import Synchronization

import ClientSettingsDomain
import ClientViewerDomain

/// This device's two settings, in memory, remembering what it was told.
///
/// **It records rather than only answers**, because what the model has to get right is that a choice
/// reaches the defaults at the moment it is made: a picker that moved the value on screen and wrote
/// nothing would look correct until the app was relaunched, which is the one failure no snapshot and
/// no on-screen assertion can see.
final class FakeAppearancePreferences: AppearancePreferences, Sendable {

    private let state: Mutex<State>

    init(appearance: AppAppearance = .default, codeTheme: CodeTheme = .default) {
        state = Mutex(State(appearance: appearance, codeTheme: codeTheme))
    }

    func appearance() -> AppAppearance { state.withLock { $0.appearance } }

    func remember(_ appearance: AppAppearance) {
        state.withLock { $0.appearance = appearance }
    }

    func codeTheme() -> CodeTheme { state.withLock { $0.codeTheme } }

    func remember(_ theme: CodeTheme) {
        state.withLock { $0.codeTheme = theme }
    }

    // MARK: -

    private struct State {
        var appearance: AppAppearance
        var codeTheme: CodeTheme
    }
}
