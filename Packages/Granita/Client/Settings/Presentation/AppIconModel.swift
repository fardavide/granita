import Foundation
import Observation

import ClientSettingsDomain

/// Which icon the Home Screen shows, and the one setting in the *Appearance* section that can fail.
///
/// **Its own model rather than a fifth value on `AppearanceModel`**, split by what it wraps: that one
/// wraps this device's defaults and is documented as unable to fail, and this one wraps the system,
/// which can refuse. Folding it in would make the other model's central promise untrue.
///
/// **Made once for the life of the app**, like `AppearanceModel`: the icon is a fact about this device,
/// not about the Mac the sheet was opened from.
@Observable
public final class AppIconModel {

    public private(set) var standing: AppIconStanding
    public private(set) var schedule: AppIconSchedule

    private let switcher: any AppIconSwitcher
    private let preferences: any AppIconPreferences
    @ObservationIgnored private var pendingChange = Task<Void, Never> {}

    public init(switcher: any AppIconSwitcher, preferences: any AppIconPreferences) {
        self.switcher = switcher
        self.preferences = preferences
        guard switcher.canChangeIcon else {
            standing = .unavailable
            schedule = .manual
            return
        }
        let shown = switcher.currentIcon()
        standing = .available(.showing(shown))
        // Before the schedule existed, Ice Cube could only have been selected by the reader.
        schedule = preferences.schedule(defaultingTo: shown == .iceCube ? .manual : .automatic)
    }

    public func refreshSeasonalIcon(on date: Date = .now, in timeZone: TimeZone = .autoupdatingCurrent) async {
        await enqueue(.refresh(date, timeZone))
    }

    public func chooseSchedule(
        _ schedule: AppIconSchedule, on date: Date = .now, in timeZone: TimeZone = .autoupdatingCurrent
    ) async {
        await enqueue(.schedule(schedule, date, timeZone))
    }

    /// Asks the system for `icon`, and moves the checkmark only once it agrees.
    ///
    /// **No saving state.** The change takes a moment and iOS confirms it with its own alert, so a
    /// spinner would stand in front of the system's answer for a fraction of a second and then be
    /// covered by it.
    public func choose(_ icon: AppIcon) async {
        await enqueue(.icon(icon))
    }

    /// A foreground refresh and a tap can overlap while UIKit is switching the icon.
    private func enqueue(_ request: Request) async {
        let previous = pendingChange
        let change = Task {
            await previous.value
            await apply(request)
        }
        pendingChange = change
        await change.value
    }

    private func apply(_ request: Request) async {
        guard case .available(let choice) = standing else { return }

        switch request {
        case .icon(let icon):
            guard icon != choice.shown, await show(icon, replacing: choice.shown) else { return }
            schedule = .manual
            preferences.remember(.manual)
        case .schedule(let schedule, let date, let timeZone):
            self.schedule = schedule
            preferences.remember(schedule)
            await applySeason(on: date, in: timeZone, showing: choice.shown)
        case .refresh(let date, let timeZone):
            await applySeason(on: date, in: timeZone, showing: choice.shown)
        }
    }

    private func applySeason(on date: Date, in timeZone: TimeZone, showing shown: AppIcon) async {
        guard schedule == .automatic else { return }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let month = calendar.component(.month, from: date)
        let isChristmas = month == 12 || (month == 1 && calendar.component(.day, from: date) <= 7)
        let icon: AppIcon = isChristmas ? .christmas : .granita
        guard icon != shown else { return }
        await show(icon, replacing: shown)
    }

    @discardableResult
    private func show(_ icon: AppIcon, replacing shown: AppIcon) async -> Bool {
        do {
            try await switcher.show(icon)
            standing = .available(.showing(icon))
            return true
        } catch {
            standing = .available(.refused(showing: shown, reason: error.reason))
            return false
        }
    }

    private enum Request {
        case icon(AppIcon)
        case schedule(AppIconSchedule, Date, TimeZone)
        case refresh(Date, TimeZone)
    }
}
