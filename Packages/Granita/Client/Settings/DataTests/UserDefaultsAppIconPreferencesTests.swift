import Foundation
import Testing

import ClientSettingsData
import ClientSettingsDomain

@Suite("Remembered app icon preferences")
@MainActor
struct UserDefaultsAppIconPreferencesTests {

    @Test
    func `given a legacy choice when preferences are reopened then the migrated icon wins`() throws {
        // given
        let scenario = try Scenario()
        defer { scenario.defaults.removePersistentDomain(forName: scenario.suiteName) }
        #expect(scenario.sut.selection(migratingFrom: .iceCube) == .iceCube)

        // when
        let reopened = UserDefaultsAppIconPreferences(defaults: scenario.defaults)

        // then
        #expect(reopened.selection(migratingFrom: .christmas) == .iceCube)
    }

    @Test
    func `given no saved schedule when it is migrated then future reads keep it`() throws {
        // given
        let scenario = try Scenario()
        defer { scenario.defaults.removePersistentDomain(forName: scenario.suiteName) }
        #expect(scenario.sut.schedule(migratingFrom: .automatic) == .automatic)

        // when
        let reopened = UserDefaultsAppIconPreferences(defaults: scenario.defaults)

        // then
        #expect(reopened.schedule(migratingFrom: .manual) == .automatic)
    }
}

// MARK: -

private struct Scenario {

    let sut: UserDefaultsAppIconPreferences
    let defaults: UserDefaults
    let suiteName: String

    @MainActor
    init() throws {
        suiteName = "granita.tests.app-icons.\(UUID().uuidString)"
        defaults = try #require(UserDefaults(suiteName: suiteName))
        sut = UserDefaultsAppIconPreferences(defaults: defaults)
    }
}
