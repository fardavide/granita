import ClientConnectionDomain

/// A baseline presses nothing, so this records nothing: what the pane argument selects is asserted in
/// the model's own suite, and what the screens pass it is asserted there too. This exists so a
/// rendered screen has a seam to hold.
struct FakeSystemSettingsOpening: SystemSettingsOpening {

    func open(_ pane: SystemSettingsPane) {}
}
