import XCTest
@testable import pulse

@MainActor
final class LanguagePreferenceTests: XCTestCase {
    func testDefaultsToSystemLanguagePreference() {
        let defaults = makeUserDefaults()
        let store = PulseStore(
            userDefaults: defaults,
            launchAtLoginService: makeLoginItemService(),
            reconcileLaunchAtLogin: false
        )

        XCTAssertEqual(store.languagePreference, .system)
    }

    func testPersistsSelectedLanguagePreference() {
        let defaults = makeUserDefaults()
        let store = PulseStore(
            userDefaults: defaults,
            launchAtLoginService: makeLoginItemService(),
            reconcileLaunchAtLogin: false
        )

        store.languagePreference = .chinese

        let reloadedStore = PulseStore(
            userDefaults: defaults,
            launchAtLoginService: makeLoginItemService(),
            reconcileLaunchAtLogin: false
        )
        XCTAssertEqual(reloadedStore.languagePreference, .chinese)
    }

    func testDefaultsLaunchAtLoginToEnabled() {
        let defaults = makeUserDefaults()
        let store = PulseStore(
            userDefaults: defaults,
            launchAtLoginService: makeLoginItemService(),
            reconcileLaunchAtLogin: false
        )

        XCTAssertTrue(store.launchAtLogin)
    }

    func testPersistsLaunchAtLoginPreferenceAndAppliesServiceState() {
        let defaults = makeUserDefaults()
        var appliedValues: [Bool] = []
        let service = makeLoginItemService(
            apply: { enabled in
                appliedValues.append(enabled)
                return enabled ? .enabled : .notRegistered
            }
        )
        let store = PulseStore(
            userDefaults: defaults,
            launchAtLoginService: service,
            reconcileLaunchAtLogin: false
        )

        store.setLaunchAtLogin(false)

        let reloadedStore = PulseStore(
            userDefaults: defaults,
            launchAtLoginService: makeLoginItemService(status: .notRegistered),
            reconcileLaunchAtLogin: false
        )
        XCTAssertEqual(appliedValues, [false])
        XCTAssertFalse(reloadedStore.launchAtLogin)
        XCTAssertEqual(store.launchAtLoginStatus, .notRegistered)
        XCTAssertNil(store.launchAtLoginError)
    }

    func testLaunchAtLoginErrorKeepsPreferredStateVisible() {
        let defaults = makeUserDefaults()
        let service = makeLoginItemService(
            status: .notRegistered,
            apply: { _ in
                throw PulseLoginItemError.requiresInstalledApplication
            }
        )
        let store = PulseStore(
            userDefaults: defaults,
            launchAtLoginService: service,
            reconcileLaunchAtLogin: false
        )

        store.setLaunchAtLogin(true)

        XCTAssertTrue(store.launchAtLogin)
        XCTAssertEqual(store.launchAtLoginStatus, .notRegistered)
        XCTAssertEqual(store.launchAtLoginError, .requiresInstalledApplication)
    }

    func testLanguageStringsResolveEnglishAndChineseText() {
        XCTAssertEqual(PulseStrings(language: .english).text(.language), "Language")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.language), "语言")
        XCTAssertEqual(PulseStrings(language: .english).text(.monitorOnly), "Monitoring only")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.monitorOnly), "仅监控")
        XCTAssertEqual(PulseStrings(language: .chinese).memoryDetail(used: "17 GB", total: "24 GB"), "17 GB / 共 24 GB")
        XCTAssertEqual(PulseStrings(language: .english).pressure(.elevated), "Watch")
        XCTAssertEqual(PulseStrings(language: .chinese).thermal(.serious), "受限")
        XCTAssertEqual(
            PulseStrings(language: .chinese).thermalDetail(
                ThermalUsage(condition: .nominal, stateDuration: 780)
            ),
            "持续稳定 13 分钟"
        )
        XCTAssertEqual(
            PulseStrings(language: .chinese).thermalDetail(
                ThermalUsage(condition: .critical, stateDuration: 45)
            ),
            "严重受限 45 秒"
        )
        XCTAssertEqual(
            PulseStrings(language: .english).thermalDetail(
                ThermalUsage(condition: .fair, stateDuration: 4)
            ),
            "Just warm"
        )
        XCTAssertEqual(
            PulseStrings(language: .chinese).thermalDetail(
                ThermalUsage(condition: .serious, stateDuration: 4)
            ),
            "受限中"
        )
        let memory = MemoryUsage(
            totalBytes: 10_000,
            usedBytes: 8_500,
            availableBytes: 1_500,
            compressedBytes: 1_200,
            swapUsedBytes: 600_000_000,
            swapTotalBytes: 2_000_000_000
        )
        XCTAssertEqual(PulseStrings(language: .chinese).pressureDetail(memory), "Swap 572 MB · 压缩 1.2 KB")
        XCTAssertEqual(PulseStrings(language: .english).pressureExplanation(memory), "Watch: 85% used, swap 572 MB, compressed 1.2 KB.")
        XCTAssertEqual(
            PulseStrings(language: .english).powerDetail(
                PowerUsage(
                    hasBattery: true,
                    batteryPercentage: 0.5,
                    isPluggedIn: false,
                    isCharging: false,
                    timeRemaining: 7_800
                )
            ),
            "2h 10m left"
        )
    }

    func testLaunchAtLoginStringsResolveEnglishAndChineseText() {
        XCTAssertEqual(PulseStrings(language: .english).text(.launchAtLogin), "Open at login")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.launchAtLogin), "登录时打开")
        XCTAssertEqual(PulseStrings(language: .english).loginItemStatus(.requiresApproval), "Requires approval")
        XCTAssertEqual(PulseStrings(language: .chinese).loginItemStatus(.enabled), "已开启")
        XCTAssertEqual(
            PulseStrings(language: .english).loginItemError(.requiresInstalledApplication),
            "Install Pulse in /Applications or ~/Applications before enabling launch at login."
        )
    }

    private func makeUserDefaults() -> UserDefaults {
        let suiteName = "pulse.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeLoginItemService(
        status: PulseLoginItemStatus = .enabled,
        apply: @escaping @MainActor (Bool) throws -> PulseLoginItemStatus = { enabled in
            enabled ? .enabled : .notRegistered
        }
    ) -> PulseLoginItemService {
        PulseLoginItemService(
            currentStatus: { status },
            apply: apply
        )
    }
}
