import SwiftUI
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

    func testDefaultsToSystemAppearancePreference() {
        let defaults = makeUserDefaults()
        let store = PulseStore(
            userDefaults: defaults,
            launchAtLoginService: makeLoginItemService(),
            reconcileLaunchAtLogin: false
        )

        XCTAssertEqual(store.appearancePreference, .system)
        XCTAssertNil(store.appearancePreference.colorScheme)
    }

    func testTrimsConfiguredDeviceName() {
        let defaults = makeUserDefaults()
        let store = PulseStore(
            userDefaults: defaults,
            launchAtLoginService: makeLoginItemService(),
            deviceName: "  Studio Mac  ",
            reconcileLaunchAtLogin: false
        )

        XCTAssertEqual(store.deviceName, "Studio Mac")
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

    func testPersistsSelectedAppearancePreference() {
        let defaults = makeUserDefaults()
        let store = PulseStore(
            userDefaults: defaults,
            launchAtLoginService: makeLoginItemService(),
            reconcileLaunchAtLogin: false
        )

        store.appearancePreference = .dark

        let reloadedStore = PulseStore(
            userDefaults: defaults,
            launchAtLoginService: makeLoginItemService(),
            reconcileLaunchAtLogin: false
        )
        XCTAssertEqual(reloadedStore.appearancePreference, .dark)
        XCTAssertEqual(reloadedStore.appearancePreference.colorScheme, .dark)
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
        XCTAssertEqual(PulseStrings(language: .english).text(.appearance), "Appearance")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.appearance), "外观")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.lightMode), "浅色模式")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.darkMode), "深色模式")
        XCTAssertEqual(PulseStrings(language: .english).text(.thisMac), "This Mac")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.thisMac), "这台 Mac")
        XCTAssertEqual(PulseStrings(language: .english).text(.monitorOnly), "Monitoring only")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.monitorOnly), "仅监控")
        XCTAssertEqual(PulseStrings(language: .english).text(.minimalPanel), "Minimal panel")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.expandPanel), "展开面板")
        XCTAssertEqual(PulseStrings(language: .chinese).memoryDetail(used: "17 GB", total: "24 GB"), "17 GB / 共 24 GB")
        XCTAssertEqual(PulseStrings(language: .english).pressure(.elevated), "Watch")
        XCTAssertEqual(PulseStrings(language: .chinese).pressure(.elevated), "偏高")
        XCTAssertEqual(PulseStrings(language: .chinese).pressure(.high), "高")
        XCTAssertEqual(PulseStrings(language: .chinese).thermal(.nominal), "正常")
        XCTAssertEqual(PulseStrings(language: .chinese).thermal(.fair), "偏热")
        XCTAssertEqual(PulseStrings(language: .chinese).thermal(.serious), "高温")
        XCTAssertEqual(PulseStrings(language: .chinese).thermal(.critical), "严重高温")
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
            "持续严重高温 45 秒"
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
            "温度较高"
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
        XCTAssertEqual(PulseStrings(language: .chinese).pressureExplanation(memory), "偏高：已用 85%，Swap 572 MB，压缩 1.2 KB。")
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
        XCTAssertEqual(
            PulseStrings(language: .chinese).powerDetail(
                PowerUsage(
                    hasBattery: true,
                    batteryPercentage: 1,
                    isPluggedIn: true,
                    isCharging: false,
                    timeRemaining: nil
                )
            ),
            "外接电源"
        )
        XCTAssertEqual(PulseStrings(language: .english).text(.pluggedIn), "External power")
    }

    func testLaunchAtLoginStringsResolveEnglishAndChineseText() {
        XCTAssertEqual(PulseStrings(language: .english).text(.launchAtLogin), "Open at login")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.launchAtLogin), "开机启动")
        XCTAssertEqual(PulseStrings(language: .english).loginItemStatus(.requiresApproval), "Requires approval")
        XCTAssertEqual(PulseStrings(language: .chinese).loginItemStatus(.enabled), "已开启")
        XCTAssertEqual(PulseStrings(language: .english).updateButtonTitle(), "Update")
        XCTAssertEqual(PulseStrings(language: .chinese).updateButtonTitle(), "更新")
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
