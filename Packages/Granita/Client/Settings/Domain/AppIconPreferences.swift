/// Whether the Home Screen icon follows the Christmas calendar or stays on the reader's choice.
public enum AppIconSchedule: String, Hashable, Sendable {
    case automatic
    case manual
}

/// Stores the selection policy. The system still owns the icon currently shown.
@MainActor
public protocol AppIconPreferences: Sendable {
    func schedule(defaultingTo fallback: AppIconSchedule) -> AppIconSchedule
    func remember(_ schedule: AppIconSchedule)
}
