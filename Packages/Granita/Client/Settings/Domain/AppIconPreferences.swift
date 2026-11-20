import Foundation

/// Whether the Home Screen icon follows the Christmas calendar or stays on the reader's choice.
public enum AppIconSchedule: String, Hashable, Sendable {
    case automatic
    case manual

    public func displayedIcon(for selection: AppIcon, on date: Date, in timeZone: TimeZone) -> AppIcon {
        guard self == .automatic else { return selection }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let month = calendar.component(.month, from: date)
        let isChristmas = month == 12 || (month == 1 && calendar.component(.day, from: date) <= 7)
        return isChristmas ? .christmas : selection
    }
}

/// Stores the usual icon and the schedule. The system owns the icon currently shown.
@MainActor
public protocol AppIconPreferences: Sendable {
    func schedule(migratingFrom legacySchedule: AppIconSchedule) -> AppIconSchedule
    func remember(_ schedule: AppIconSchedule)
    func selection(migratingFrom legacySelection: AppIcon) -> AppIcon
    func remember(_ selection: AppIcon)
}
