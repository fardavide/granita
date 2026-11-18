import Foundation

import ClientSettingsDomain

@MainActor
public struct UserDefaultsAppIconPreferences: AppIconPreferences {

    private static let scheduleKey = "granita.appIcon.schedule"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func schedule(defaultingTo fallback: AppIconSchedule) -> AppIconSchedule {
        defaults.string(forKey: Self.scheduleKey).flatMap(AppIconSchedule.init(rawValue:)) ?? fallback
    }

    public func remember(_ schedule: AppIconSchedule) {
        defaults.set(schedule.rawValue, forKey: Self.scheduleKey)
    }
}
