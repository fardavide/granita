import ClientConnectionDomain

/// A baseline presses nothing, so this records nothing: what the pane argument selects is asserted in
/// the model's own suite, and what the screens pass it is asserted there too. This exists so a
/// rendered screen has a seam to hold.
struct FakeSystemSettingsOpening: SystemSettingsOpening {

    // Spelled out because this target has no default isolation of its own, unlike the package's view
    // layers: the requirement is main-actor and a nonisolated method cannot satisfy it.
    @MainActor
    func open(_ pane: SystemSettingsPane) {}
}
