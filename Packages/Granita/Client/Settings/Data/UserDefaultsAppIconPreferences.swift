import Foundation

import ClientSettingsDomain

@MainActor
public struct UserDefaultsAppIconPreferences: AppIconPreferences {

    private static let scheduleKey = "granita.appIcon.schedule"
    private static let selectionKey = "granita.appIcon.selection"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func schedule(migratingFrom legacySchedule: AppIconSchedule) -> AppIconSchedule {
        if let storedSchedule = defaults.string(forKey: Self.scheduleKey).flatMap(AppIconSchedule.init(rawValue:)) {
            return storedSchedule
        }
        remember(legacySchedule)
        return legacySchedule
    }

    public func remember(_ schedule: AppIconSchedule) {
        defaults.set(schedule.rawValue, forKey: Self.scheduleKey)
    }

    public func selection(migratingFrom legacySelection: AppIcon) -> AppIcon {
        if let storedSelection = defaults.string(forKey: Self.selectionKey).flatMap(AppIcon.init(rawValue:)) {
            return storedSelection
        }
        remember(legacySelection)
        return legacySelection
    }

    public func remember(_ selection: AppIcon) {
        defaults.set(selection.rawValue, forKey: Self.selectionKey)
    }
}
