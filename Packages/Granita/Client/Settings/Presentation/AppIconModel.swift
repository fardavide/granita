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
    public private(set) var selection: AppIcon

    private let switcher: any AppIconSwitcher
    private let preferences: any AppIconPreferences
    @ObservationIgnored private var pendingChange = Task<Void, Never> {}

    public init(switcher: any AppIconSwitcher, preferences: any AppIconPreferences) {
        self.switcher = switcher
        self.preferences = preferences
        guard switcher.canChangeIcon else {
            standing = .unavailable
            schedule = .manual
            selection = .default
            return
        }
        let shown = switcher.currentIcon()
        // Before the schedule existed, Ice Cube could only have been selected by the reader.
        let schedule = preferences.schedule(migratingFrom: shown == .iceCube ? .manual : .automatic)
        // The legacy schedule displayed Christmas temporarily, then always returned to Granita.
        let legacySelection = shown == .christmas && schedule == .automatic ? AppIcon.default : shown
        selection = preferences.selection(migratingFrom: legacySelection)
        self.schedule = schedule
        standing = .available(.showing(shown))
    }

    public func refreshSeasonalIcon(on date: Date = .now, in timeZone: TimeZone = .autoupdatingCurrent) async {
        await enqueue(.refresh, on: date, in: timeZone)
    }

    public func chooseSchedule(
        _ schedule: AppIconSchedule, on date: Date = .now, in timeZone: TimeZone = .autoupdatingCurrent
    ) async {
        await enqueue(.schedule(schedule), on: date, in: timeZone)
    }

    public func choose(
        _ icon: AppIcon, on date: Date = .now, in timeZone: TimeZone = .autoupdatingCurrent
    ) async {
        await enqueue(.icon(icon), on: date, in: timeZone)
    }

    /// A foreground refresh and a tap can overlap while UIKit is switching the icon.
    private func enqueue(_ request: Request, on date: Date, in timeZone: TimeZone) async {
        let previous = pendingChange
        let change = Task {
            await previous.value
            await apply(request, on: date, in: timeZone)
        }
        pendingChange = change
        await change.value
    }

    private func apply(_ request: Request, on date: Date, in timeZone: TimeZone) async {
        guard case .available = standing else { return }

        let nextSelection: AppIcon
        let nextSchedule: AppIconSchedule
        switch request {
        case .icon(let icon):
            nextSelection = icon
            nextSchedule = schedule
        case .schedule(let schedule):
            nextSelection = selection
            nextSchedule = schedule
        case .refresh:
            nextSelection = selection
            nextSchedule = schedule
        }

        let desired = nextSchedule.displayedIcon(for: nextSelection, on: date, in: timeZone)
        do {
            if desired != switcher.currentIcon() {
                try await switcher.show(desired)
            }
        } catch {
            standing = .available(.refused(showing: switcher.currentIcon(), reason: error.reason))
            return
        }

        if nextSelection != selection {
            preferences.remember(nextSelection)
            selection = nextSelection
        }
        if nextSchedule != schedule {
            preferences.remember(nextSchedule)
            schedule = nextSchedule
        }
        standing = .available(.showing(switcher.currentIcon()))
    }

    private enum Request {
        case icon(AppIcon)
        case schedule(AppIconSchedule)
        case refresh
    }
}
