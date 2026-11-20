import ClientSettingsDomain

@MainActor
final class FakeAppIconPreferences: AppIconPreferences {

    private var storedSchedule: AppIconSchedule?
    private var storedSelection: AppIcon?

    init(storedSchedule: AppIconSchedule? = nil) {
        self.storedSchedule = storedSchedule
    }

    func schedule(migratingFrom legacySchedule: AppIconSchedule) -> AppIconSchedule {
        let schedule = storedSchedule ?? legacySchedule
        storedSchedule = schedule
        return schedule
    }

    func remember(_ schedule: AppIconSchedule) {
        storedSchedule = schedule
    }

    func selection(migratingFrom legacySelection: AppIcon) -> AppIcon {
        let selection = storedSelection ?? legacySelection
        storedSelection = selection
        return selection
    }

    func remember(_ selection: AppIcon) {
        storedSelection = selection
    }
}
