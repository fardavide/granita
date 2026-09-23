import Synchronization

import ClientSettingsDomain
import ClientViewerDomain

/// This device's three settings, in memory, remembering what it was told.
///
/// **It records rather than only answers**, because what the model has to get right is that a choice
/// reaches the defaults at the moment it is made: a picker that moved the value on screen and wrote
/// nothing would look correct until the app was relaunched, which is the one failure no snapshot and
/// no on-screen assertion can see.
final class FakeAppearancePreferences: AppearancePreferences, Sendable {

    private let state: Mutex<State>

    init(
        appearance: AppAppearance = .default,
        codeTheme: CodeTheme = .default,
        isSideBySide: Bool = false
    ) {
        state = Mutex(State(appearance: appearance, codeTheme: codeTheme, isSideBySide: isSideBySide))
    }

    func appearance() -> AppAppearance { state.withLock { $0.appearance } }

    func remember(_ appearance: AppAppearance) {
        state.withLock { $0.appearance = appearance }
    }

    func codeTheme() -> CodeTheme { state.withLock { $0.codeTheme } }

    func remember(_ theme: CodeTheme) {
        state.withLock { $0.codeTheme = theme }
    }

    func isSideBySide() -> Bool { state.withLock { $0.isSideBySide } }

    func remember(isSideBySide: Bool) {
        state.withLock { $0.isSideBySide = isSideBySide }
    }

    // MARK: -

    private struct State {
        var appearance: AppAppearance
        var codeTheme: CodeTheme
        var isSideBySide: Bool
    }
}
