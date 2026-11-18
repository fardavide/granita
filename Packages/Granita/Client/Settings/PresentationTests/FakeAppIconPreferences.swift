import ClientSettingsDomain

@MainActor
final class FakeAppIconPreferences: AppIconPreferences {

    private var storedSchedule: AppIconSchedule?

    func schedule(defaultingTo fallback: AppIconSchedule) -> AppIconSchedule {
        storedSchedule ?? fallback
    }

    func remember(_ schedule: AppIconSchedule) {
        storedSchedule = schedule
    }
}
