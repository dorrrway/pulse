import AppKit
import Carbon
import SwiftUI
import XCTest
@testable import pulse

final class LanguagePreferenceTests: XCTestCase {
    @MainActor
    func testDefaultsToSystemLanguagePreference() {
        let defaults = makeUserDefaults()
        let store = PulseStore(
            userDefaults: defaults,
            launchAtLoginService: makeLoginItemService(),
            reconcileLaunchAtLogin: false
        )

        XCTAssertEqual(store.languagePreference, .system)
    }

    @MainActor
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

    @MainActor
    func testDefaultsToHidingPulseDuringScreenshots() {
        let defaults = makeUserDefaults()
        let store = PulseStore(
            userDefaults: defaults,
            launchAtLoginService: makeLoginItemService(),
            reconcileLaunchAtLogin: false
        )

        XCTAssertTrue(store.hidePulseDuringScreenshots)
    }

    @MainActor
    func testDefaultsToHidingCursorDuringScreenRecordings() {
        let defaults = makeUserDefaults()
        let store = PulseStore(
            userDefaults: defaults,
            launchAtLoginService: makeLoginItemService(),
            reconcileLaunchAtLogin: false
        )

        XCTAssertTrue(store.hideCursorDuringScreenRecordings)
    }

    @MainActor
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

    @MainActor
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

    func testSystemLanguageUsesPreferredLanguagesBeforeLocaleFallback() {
        XCTAssertEqual(
            PulseLanguage.resolveSystemLanguage(
                preferredLanguages: ["zh-Hans-US", "en-US"],
                fallbackLanguageCode: "en"
            ),
            .chinese
        )

        XCTAssertEqual(
            PulseLanguage.resolveSystemLanguage(
                preferredLanguages: ["ja-JP", "zh-Hans-US", "en-US"],
                fallbackLanguageCode: "en"
            ),
            .chinese
        )

        XCTAssertEqual(
            PulseLanguage.resolveSystemLanguage(
                preferredLanguages: ["fr-FR"],
                fallbackLanguageCode: "zh"
            ),
            .chinese
        )
    }

    @MainActor
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

    @MainActor
    func testPersistsHidePulseDuringScreenshotsPreference() {
        let defaults = makeUserDefaults()
        let store = PulseStore(
            userDefaults: defaults,
            launchAtLoginService: makeLoginItemService(),
            reconcileLaunchAtLogin: false
        )

        store.setHidePulseDuringScreenshots(false)

        let reloadedStore = PulseStore(
            userDefaults: defaults,
            launchAtLoginService: makeLoginItemService(),
            reconcileLaunchAtLogin: false
        )
        XCTAssertFalse(reloadedStore.hidePulseDuringScreenshots)
    }

    @MainActor
    func testPersistsHideCursorDuringScreenRecordingsPreference() {
        let defaults = makeUserDefaults()
        let store = PulseStore(
            userDefaults: defaults,
            launchAtLoginService: makeLoginItemService(),
            reconcileLaunchAtLogin: false
        )

        store.setHideCursorDuringScreenRecordings(false)

        let reloadedStore = PulseStore(
            userDefaults: defaults,
            launchAtLoginService: makeLoginItemService(),
            reconcileLaunchAtLogin: false
        )
        XCTAssertFalse(reloadedStore.hideCursorDuringScreenRecordings)
    }

    @MainActor
    func testApplyingSystemAppearanceResolvesCurrentSystemStyle() {
        let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 200, height: 120), styleMask: [], backing: .buffered, defer: false)
        window.contentView = NSView(frame: window.contentView?.frame ?? .zero)

        PulseAppearancePreference.dark.apply(to: window)

        XCTAssertEqual(window.appearance?.name, .darkAqua)
        XCTAssertEqual(window.contentView?.appearance?.name, .darkAqua)

        PulseAppearancePreference.system.apply(to: window)

        let expectedAppearanceName = PulseAppearancePreference.system.nsAppearance?.name
        XCTAssertEqual(window.appearance?.name, expectedAppearanceName)
        XCTAssertEqual(window.contentView?.appearance?.name, expectedAppearanceName)
    }

    @MainActor
    func testDefaultsLaunchAtLoginToEnabled() {
        let defaults = makeUserDefaults()
        let store = PulseStore(
            userDefaults: defaults,
            launchAtLoginService: makeLoginItemService(),
            reconcileLaunchAtLogin: false
        )

        XCTAssertTrue(store.launchAtLogin)
    }

    @MainActor
    func testPersistsInstalledAppsDisplayMode() {
        let defaults = makeUserDefaults()
        let store = PulseStore(
            userDefaults: defaults,
            launchAtLoginService: makeLoginItemService(),
            reconcileLaunchAtLogin: false
        )

        XCTAssertEqual(store.installedAppsDisplayMode, .icon)

        store.setInstalledAppsDisplayMode(.list)

        let reloadedStore = PulseStore(
            userDefaults: defaults,
            launchAtLoginService: makeLoginItemService(),
            reconcileLaunchAtLogin: false
        )
        XCTAssertEqual(reloadedStore.installedAppsDisplayMode, .list)
    }

    @MainActor
    func testPersistsWakeShortcuts() {
        let defaults = makeUserDefaults()
        let clipboardShortcut = PulseKeyboardShortcut(
            keyCode: UInt16(kVK_ANSI_C),
            modifierFlags: [.command, .option],
            keyEquivalent: "C"
        )
        let applicationsShortcut = PulseKeyboardShortcut(
            keyCode: UInt16(kVK_ANSI_A),
            modifierFlags: [.control, .option],
            keyEquivalent: "A"
        )
        let fullScreenShortcut = PulseKeyboardShortcut(
            keyCode: UInt16(kVK_ANSI_1),
            modifierFlags: [.command, .shift],
            keyEquivalent: "1"
        )
        let windowShortcut = PulseKeyboardShortcut(
            keyCode: UInt16(kVK_ANSI_2),
            modifierFlags: [.command, .shift],
            keyEquivalent: "2"
        )
        let selectionShortcut = PulseKeyboardShortcut(
            keyCode: UInt16(kVK_ANSI_3),
            modifierFlags: [.command, .shift],
            keyEquivalent: "3"
        )
        let recordingFullScreenShortcut = PulseKeyboardShortcut(
            keyCode: UInt16(kVK_ANSI_4),
            modifierFlags: [.command, .shift],
            keyEquivalent: "4"
        )
        let recordingWindowShortcut = PulseKeyboardShortcut(
            keyCode: UInt16(kVK_ANSI_5),
            modifierFlags: [.command, .shift],
            keyEquivalent: "5"
        )
        let recordingSelectionShortcut = PulseKeyboardShortcut(
            keyCode: UInt16(kVK_ANSI_6),
            modifierFlags: [.command, .shift],
            keyEquivalent: "6"
        )
        let store = PulseStore(
            userDefaults: defaults,
            launchAtLoginService: makeLoginItemService(),
            reconcileLaunchAtLogin: false
        )

        store.setShortcut(clipboardShortcut, for: .wakeClipboard)
        store.setShortcut(applicationsShortcut, for: .wakeApplications)
        store.setShortcut(fullScreenShortcut, for: .captureFullScreen)
        store.setShortcut(windowShortcut, for: .captureWindow)
        store.setShortcut(selectionShortcut, for: .captureSelection)
        store.setShortcut(recordingFullScreenShortcut, for: .recordFullScreen)
        store.setShortcut(recordingWindowShortcut, for: .recordWindow)
        store.setShortcut(recordingSelectionShortcut, for: .recordSelection)

        let reloadedStore = PulseStore(
            userDefaults: defaults,
            launchAtLoginService: makeLoginItemService(),
            reconcileLaunchAtLogin: false
        )
        XCTAssertEqual(reloadedStore.wakeClipboardShortcut, clipboardShortcut)
        XCTAssertEqual(reloadedStore.wakeApplicationsShortcut, applicationsShortcut)
        XCTAssertEqual(reloadedStore.captureFullScreenShortcut, fullScreenShortcut)
        XCTAssertEqual(reloadedStore.captureWindowShortcut, windowShortcut)
        XCTAssertEqual(reloadedStore.captureSelectionShortcut, selectionShortcut)
        XCTAssertEqual(reloadedStore.recordFullScreenShortcut, recordingFullScreenShortcut)
        XCTAssertEqual(reloadedStore.recordWindowShortcut, recordingWindowShortcut)
        XCTAssertEqual(reloadedStore.recordSelectionShortcut, recordingSelectionShortcut)
        XCTAssertEqual(reloadedStore.shortcutPreferences.wakeClipboard?.displayTitle, "⌥⌘C")
        XCTAssertEqual(reloadedStore.shortcutPreferences.captureSelection?.displayTitle, "⇧⌘3")
        XCTAssertEqual(reloadedStore.shortcutPreferences.recordSelection?.displayTitle, "⇧⌘6")
    }

    @MainActor
    func testKeyboardShortcutsAllowUnmodifiedKeys() throws {
        let letterEvent = try XCTUnwrap(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "a",
                charactersIgnoringModifiers: "a",
                isARepeat: false,
                keyCode: UInt16(kVK_ANSI_A)
            )
        )
        let functionEvent = try XCTUnwrap(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "",
                charactersIgnoringModifiers: "",
                isARepeat: false,
                keyCode: UInt16(kVK_F13)
            )
        )
        let escapeEvent = try XCTUnwrap(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "\u{1b}",
                charactersIgnoringModifiers: "\u{1b}",
                isARepeat: false,
                keyCode: UInt16(kVK_Escape)
            )
        )

        XCTAssertEqual(PulseKeyboardShortcut(event: letterEvent)?.displayTitle, "A")
        XCTAssertEqual(PulseKeyboardShortcut(event: functionEvent)?.displayTitle, "F13")
        XCTAssertEqual(PulseKeyboardShortcut(event: escapeEvent)?.displayTitle, "Esc")
    }

    @MainActor
    func testDuplicateShortcutMovesToMostRecentAction() {
        let defaults = makeUserDefaults()
        let shortcut = PulseKeyboardShortcut(
            keyCode: UInt16(kVK_ANSI_C),
            modifierFlags: [.command, .option],
            keyEquivalent: "C"
        )
        let store = PulseStore(
            userDefaults: defaults,
            launchAtLoginService: makeLoginItemService(),
            reconcileLaunchAtLogin: false
        )

        store.setShortcut(shortcut, for: .wakeClipboard)
        store.setShortcut(shortcut, for: .recordSelection)

        XCTAssertNil(store.wakeClipboardShortcut)
        XCTAssertEqual(store.recordSelectionShortcut, shortcut)
    }

    @MainActor
    func testPersistsFavoriteApplications() {
        let defaults = makeUserDefaults()
        let alpha = makeInstalledApplication(name: "Alpha", path: "/Applications/Alpha.app")
        let beta = makeInstalledApplication(name: "Beta", path: "/Applications/Beta.app")
        let store = PulseStore(
            userDefaults: defaults,
            launchAtLoginService: makeLoginItemService(),
            reconcileLaunchAtLogin: false
        )
        store.installedApplications = [alpha, beta]

        XCTAssertTrue(store.addFavoriteApplication(alpha))
        XCTAssertTrue(store.addFavoriteApplication(beta))
        XCTAssertTrue(store.addFavoriteApplication(alpha))

        let reloadedStore = PulseStore(
            userDefaults: defaults,
            launchAtLoginService: makeLoginItemService(),
            reconcileLaunchAtLogin: false
        )
        reloadedStore.installedApplications = [alpha, beta]

        XCTAssertEqual(reloadedStore.favoriteApplicationPaths, [alpha.bundlePath, beta.bundlePath])
        XCTAssertEqual(reloadedStore.favoriteApplications.map(\.name), ["Alpha", "Beta"])
    }

    @MainActor
    func testFavoriteApplicationsSkipMissingApplicationsAndPreserveOrder() {
        let alpha = makeInstalledApplication(name: "Alpha", path: "/Applications/Alpha.app")
        let beta = makeInstalledApplication(name: "Beta", path: "/Applications/Beta.app")

        let favorites = PulseStore.favoriteApplications(
            from: [alpha, beta],
            favoritePaths: [
                "/Applications/Missing.app",
                beta.bundlePath,
                alpha.bundlePath,
                beta.bundlePath
            ]
        )

        XCTAssertEqual(favorites.map(\.name), ["Beta", "Alpha"])
    }

    @MainActor
    func testMovesFavoriteApplicationsByBundlePath() {
        let defaults = makeUserDefaults()
        let alpha = makeInstalledApplication(name: "Alpha", path: "/Applications/Alpha.app")
        let beta = makeInstalledApplication(name: "Beta", path: "/Applications/Beta.app")
        let gamma = makeInstalledApplication(name: "Gamma", path: "/Applications/Gamma.app")
        let store = PulseStore(
            userDefaults: defaults,
            launchAtLoginService: makeLoginItemService(),
            reconcileLaunchAtLogin: false
        )
        store.installedApplications = [alpha, beta, gamma]

        XCTAssertTrue(store.addFavoriteApplication(alpha))
        XCTAssertTrue(store.addFavoriteApplication(gamma))
        XCTAssertTrue(store.addOrMoveFavoriteApplication(bundlePath: beta.bundlePath, before: gamma.bundlePath))
        XCTAssertEqual(store.favoriteApplications.map(\.name), ["Alpha", "Beta", "Gamma"])

        XCTAssertTrue(store.addOrMoveFavoriteApplication(bundlePath: alpha.bundlePath, after: gamma.bundlePath))
        XCTAssertEqual(store.favoriteApplications.map(\.name), ["Beta", "Gamma", "Alpha"])

        XCTAssertTrue(store.addOrMoveFavoriteApplication(bundlePath: gamma.bundlePath, before: gamma.bundlePath))
        XCTAssertEqual(store.favoriteApplications.map(\.name), ["Beta", "Gamma", "Alpha"])
    }

    @MainActor
    func testMovesFavoriteApplicationsToInsertionIndex() {
        let defaults = makeUserDefaults()
        let alpha = makeInstalledApplication(name: "Alpha", path: "/Applications/Alpha.app")
        let beta = makeInstalledApplication(name: "Beta", path: "/Applications/Beta.app")
        let gamma = makeInstalledApplication(name: "Gamma", path: "/Applications/Gamma.app")
        let delta = makeInstalledApplication(name: "Delta", path: "/Applications/Delta.app")
        let store = PulseStore(
            userDefaults: defaults,
            launchAtLoginService: makeLoginItemService(),
            reconcileLaunchAtLogin: false
        )
        store.installedApplications = [alpha, beta, gamma, delta]
        for application in [alpha, beta, gamma, delta] {
            XCTAssertTrue(store.addFavoriteApplication(application))
        }

        XCTAssertTrue(store.addOrMoveFavoriteApplication(bundlePath: alpha.bundlePath, atFavoriteIndex: 3))
        XCTAssertEqual(store.favoriteApplications.map(\.name), ["Beta", "Gamma", "Alpha", "Delta"])

        XCTAssertTrue(store.addOrMoveFavoriteApplication(bundlePath: delta.bundlePath, atFavoriteIndex: 1))
        XCTAssertEqual(store.favoriteApplications.map(\.name), ["Beta", "Delta", "Gamma", "Alpha"])

        XCTAssertTrue(store.addOrMoveFavoriteApplication(bundlePath: gamma.bundlePath, atFavoriteIndex: 3))
        XCTAssertEqual(store.favoriteApplications.map(\.name), ["Beta", "Delta", "Gamma", "Alpha"])
    }

    @MainActor
    func testRemovesFavoriteApplicationsByBundlePath() {
        let defaults = makeUserDefaults()
        let alpha = makeInstalledApplication(name: "Alpha", path: "/Applications/Alpha.app")
        let beta = makeInstalledApplication(name: "Beta", path: "/Applications/Beta.app")
        let store = PulseStore(
            userDefaults: defaults,
            launchAtLoginService: makeLoginItemService(),
            reconcileLaunchAtLogin: false
        )
        store.installedApplications = [alpha, beta]

        XCTAssertTrue(store.addFavoriteApplication(alpha))
        XCTAssertTrue(store.addFavoriteApplication(beta))
        XCTAssertTrue(store.isFavoriteApplication(bundlePath: beta.bundlePath))

        store.removeFavoriteApplication(bundlePath: beta.bundlePath)

        XCTAssertFalse(store.isFavoriteApplication(bundlePath: beta.bundlePath))
        XCTAssertEqual(store.favoriteApplications.map(\.name), ["Alpha"])
    }

    func testDetectsRunningApplicationsByBundlePathAndIdentifier() {
        let alpha = makeInstalledApplication(name: "Alpha", path: "/Applications/Alpha.app")
        let beta = makeInstalledApplication(
            name: "Beta",
            path: "/Applications/Beta.app",
            bundleIdentifier: "com.example.not-running-beta"
        )
        let gamma = makeInstalledApplication(name: "Gamma", path: "/Applications/Gamma.app")
        let state = RunningApplicationState(
            bundleIdentifiers: ["com.example.alpha"],
            bundlePaths: ["/Applications/Beta.app"]
        )

        XCTAssertTrue(state.contains(alpha))
        XCTAssertTrue(state.contains(beta))
        XCTAssertFalse(state.contains(gamma))
    }

    @MainActor
    func testInstalledApplicationOpenActionCollapsesAfterLaunchRequest() {
        let application = makeInstalledApplication(name: "Alpha", path: "/Applications/Alpha.app")
        var launchedApplication: InstalledApplication?
        var events: [String] = []

        let openAction = InstalledApplicationOpenAction(
            launch: { application in
                launchedApplication = application
                events.append("launch")
            },
            afterLaunch: {
                events.append("collapse")
            }
        )

        openAction(application)

        XCTAssertEqual(launchedApplication, application)
        XCTAssertEqual(events, ["launch", "collapse"])
    }

    @MainActor
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

    @MainActor
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

    @MainActor
    func testLanguageStringsResolveEnglishAndChineseText() {
        XCTAssertEqual(PulseStrings(language: .english).text(.language), "Language")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.language), "语言")
        XCTAssertEqual(PulseStrings(language: .english).text(.appearance), "Appearance")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.appearance), "外观")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.lightMode), "浅色模式")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.darkMode), "深色模式")
        XCTAssertEqual(PulseStrings(language: .english).text(.thisMac), "This Mac")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.thisMac), "这台 Mac")
        XCTAssertEqual(PulseStrings(language: .english).text(.minimalPanel), "Minimal panel")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.expandPanel), "展开面板")
        XCTAssertEqual(PulseStrings(language: .english).text(.topIsland), "Pulse Dynamic Island-style entry")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.topIsland), "Pulse 灵动岛入口")
        XCTAssertEqual(PulseStrings(language: .english).text(.applications), "Applications")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.applications), "应用程序")
        XCTAssertEqual(PulseStrings(language: .english).text(.memos), "Memo")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.memos), "备忘")
        XCTAssertEqual(PulseStrings(language: .english).memoFilterTitle(.todo), "Todo")
        XCTAssertEqual(PulseStrings(language: .chinese).memoTaskSummary(active: 2, completed: 1), "2 个待办 · 1 个完成")
        XCTAssertEqual(PulseStrings(language: .english).text(.screenshots), "Capture")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.screenshots), "截屏录屏")
        XCTAssertEqual(PulseStrings(language: .english).text(.recordFullScreenShortcut), "Record Full Screen")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.recordFullScreenShortcut), "全屏录屏")
        XCTAssertEqual(PulseStrings(language: .english).text(.bluetooth), "Bluetooth")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.bluetooth), "蓝牙")
        XCTAssertEqual(
            PulseStrings(language: .english).text(.bluetoothAuthorizationTitle),
            "Pulse needs Bluetooth access"
        )
        XCTAssertEqual(PulseStrings(language: .chinese).text(.authorizeBluetoothDeviceAccess), "授权")
        XCTAssertEqual(PulseStrings(language: .english).text(.openBluetoothSettings), "Bluetooth Settings")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.openBluetoothSettings), "蓝牙设置")
        XCTAssertEqual(PulseStrings(language: .english).text(.bluetoothPoweredOffTitle), "Bluetooth is off")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.bluetoothPoweredOffTitle), "蓝牙已关闭")
        XCTAssertEqual(PulseStrings(language: .english).text(.turnOnBluetooth), "Turn On")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.turnOnBluetooth), "开启")
        XCTAssertEqual(PulseStrings(language: .english).text(.connectBluetoothDevice), "Connect")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.disconnectBluetoothDevice), "断开")
        XCTAssertEqual(PulseStrings(language: .english).text(.bluetoothDisconnectConfirmationTitle), "Disconnect device")
        XCTAssertEqual(
            PulseStrings(language: .chinese).bluetoothDisconnectConfirmationMessage(deviceName: "AirPods Pro"),
            "要断开 AirPods Pro 吗？"
        )
        XCTAssertEqual(PulseStrings(language: .english).bluetoothDeviceCount(1), "1 device")
        XCTAssertEqual(PulseStrings(language: .chinese).bluetoothDeviceCount(3), "3 个设备")
        XCTAssertEqual(
            PulseStrings(language: .chinese).bluetoothBatteryLabel(
                BluetoothBatteryLevel(role: .left, percentage: 0.96)
            ),
            "左耳电量 96%"
        )
        XCTAssertEqual(
            PulseStrings(language: .english).bluetoothBatteryLabel(
                BluetoothBatteryLevel(role: .device, percentage: 0.26, isCharging: true)
            ),
            "Battery 26%, charging"
        )
        let airPodsLeftLowBattery = BluetoothBatteryAlert(
            deviceID: "airpods",
            deviceName: "AirPods Pro",
            category: .headphones,
            role: .left,
            percentage: 0.09,
            severity: .critical,
            isConnected: false
        )
        XCTAssertEqual(
            PulseStrings(language: .chinese).bluetoothBatteryAlertTitle(airPodsLeftLowBattery),
            "AirPods Pro 左耳"
        )
        XCTAssertEqual(
            PulseStrings(language: .english).bluetoothBatteryAlertDetail(airPodsLeftLowBattery),
            "Left battery critically low · charge soon"
        )
        XCTAssertEqual(PulseStrings(language: .english).text(.screenshotCaptured), "Screenshot")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.screenshotCaptured), "截图")
        XCTAssertEqual(PulseStrings(language: .english).text(.screenshotSaveAction), "Save")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.screenshotShareAction), "分享")
        XCTAssertEqual(PulseStrings(language: .english).text(.screenshotRecognizeTextAction), "Recognize Text")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.screenshotTextCopied), "文字已复制")
        XCTAssertEqual(PulseStrings(language: .english).text(.capturePreviewCloseAction), "Close preview")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.capturePreviewCloseAction), "关闭预览")
        XCTAssertEqual(PulseStrings(language: .english).text(.screenshotAuthorizeScreenRecording), "Authorize")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.screenshotAuthorizeScreenRecording), "授权")
        XCTAssertEqual(
            PulseStrings(language: .english).text(.screenshotHidePulseDuringCapture),
            "Hide Pulse"
        )
        XCTAssertEqual(PulseStrings(language: .chinese).text(.screenshotHidePulseDuringCapture), "隐藏 pulse 界面")
        XCTAssertTrue(
            PulseStrings(language: .chinese)
                .text(.screenshotHidePulseDuringCaptureDetail)
                .contains("录屏")
        )
        XCTAssertEqual(PulseStrings(language: .english).text(.screenshotSectionTitle), "Screenshots")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.screenshotSectionTitle), "截屏")
        XCTAssertEqual(PulseStrings(language: .english).text(.screenRecordingSectionTitle), "Recordings")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.screenRecordingSectionTitle), "录屏")
        XCTAssertEqual(PulseStrings(language: .english).text(.screenRecordingPreviewTitle), "Recording")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.screenRecordingPreviewAction), "预览")
        XCTAssertEqual(PulseStrings(language: .english).text(.screenRecordingDiscardAction), "Discard")
        XCTAssertEqual(PulseStrings(language: .english).text(.screenRecordingHideCursorDuringCapture), "Hide Mouse")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.screenRecordingHideCursorDuringCapture), "隐藏鼠标")
        XCTAssertEqual(PulseStrings(language: .english).text(.screenshotEditAction), "Edit")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.screenshotEditAction), "编辑")
        XCTAssertEqual(PulseStrings(language: .english).text(.screenshotEditorMove), "Move")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.screenshotEditorMove), "移动")
        XCTAssertEqual(PulseStrings(language: .chinese).screenshotEditorToolTitle(.mosaic), "马赛克")
        XCTAssertEqual(PulseStrings(language: .chinese).screenshotEditorToolTitle(.ellipse), "圆形")
        XCTAssertEqual(PulseStrings(language: .english).screenshotEditorToolTitle(.pen), "Pen")
        XCTAssertEqual(PulseStrings(language: .chinese).screenshotEditorToolTitle(.text), "文字")
        XCTAssertTrue(
            PulseStrings(language: .chinese)
                .text(.screenshotScreenRecordingPermissionNotice)
                .contains("屏幕录制权限")
        )
        XCTAssertEqual(PulseStrings(language: .english).text(.captureFullScreenShortcut), "Capture Full Screen")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.captureSelectionShortcut), "区域截图")
        XCTAssertEqual(PulseStrings(language: .english).screenshotModeTitle(.window), "Window")
        XCTAssertEqual(PulseStrings(language: .chinese).screenshotModeTitle(.selection), "自定义区域")
        XCTAssertEqual(PulseStrings(language: .english).screenRecordingModeTitle(.fullScreen), "Record Full Screen")
        XCTAssertEqual(PulseStrings(language: .chinese).screenRecordingModeTitle(.selection), "区域录屏")
        XCTAssertEqual(PulseStrings(language: .english).text(.applicationsListView), "List view")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.applicationsIconView), "图标视图")
        XCTAssertEqual(PulseStrings(language: .english).text(.favoriteApplications), "Favorite Apps")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.favoriteApplications), "常用应用")
        XCTAssertEqual(
            PulseStrings(language: .english).text(.favoriteApplicationsEmptyHint),
            "Add or drag favorite apps here"
        )
        XCTAssertEqual(
            PulseStrings(language: .chinese).text(.favoriteApplicationsEmptyHint),
            "添加、拖拽常用软件到此处"
        )
        XCTAssertEqual(PulseStrings(language: .english).text(.applicationRunning), "Running")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.applicationRunning), "正在运行")
        XCTAssertEqual(
            PulseStrings(language: .english).addFavoriteApplicationHelp("Safari"),
            "Add Safari to Favorite Apps"
        )
        XCTAssertEqual(
            PulseStrings(language: .chinese).removeFavoriteApplicationHelp("Safari"),
            "从常用应用移除 Safari"
        )
        XCTAssertEqual(PulseStrings(language: .english).applicationCount(1), "1 application")
        XCTAssertEqual(PulseStrings(language: .english).applicationCount(3), "3 applications")
        XCTAssertEqual(PulseStrings(language: .chinese).applicationCount(3), "3 个应用程序")
        XCTAssertEqual(PulseStrings(language: .english).installedApplicationSource(.system), "System")
        XCTAssertEqual(PulseStrings(language: .chinese).installedApplicationSource(.user), "用户")
        XCTAssertEqual(PulseStrings(language: .english).text(.systemRuntime), "System Runtime")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.systemRuntime), "开机时长")
        XCTAssertEqual(PulseStrings(language: .english).text(.appVersion), "Version")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.appVersion), "版本")
        XCTAssertEqual(PulseStrings(language: .english).text(.memory), "Memory")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.memory), "内存")
        XCTAssertEqual(PulseStrings(language: .english).text(.memoryPressure), "Memory Pressure")
        XCTAssertEqual(PulseStrings(language: .chinese).text(.memoryPressure), "内存压力")
        XCTAssertEqual(PulseStrings(language: .english).islandBatteryLevelTitle(), "Battery")
        XCTAssertEqual(PulseStrings(language: .chinese).islandBatteryLevelTitle(), "电量")
        XCTAssertEqual(PulseStrings(language: .chinese).memoryDetail(used: "17 GB", total: "24 GB"), "17 GB / 共 24 GB")
        XCTAssertEqual(PulseStrings(language: .english).pressure(.elevated), "Watch")
        XCTAssertEqual(PulseStrings(language: .chinese).pressure(.elevated), "偏高")
        XCTAssertEqual(PulseStrings(language: .chinese).pressure(.high), "高")
        XCTAssertEqual(PulseStrings(language: .english).thermal(.nominal), "Normal")
        XCTAssertEqual(PulseStrings(language: .english).thermal(.serious), "Hot")
        XCTAssertEqual(PulseStrings(language: .english).thermal(.critical), "Very Hot")
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
            "Body warm"
        )
        XCTAssertEqual(
            PulseStrings(language: .english).thermalDetail(
                ThermalUsage(condition: .critical, stateDuration: 45)
            ),
            "Very hot for 45 sec"
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
        XCTAssertEqual(PulseStrings(language: .english).pressureDetail(memory), "Swap 572 MB · Comp 1.2 KB")
        XCTAssertEqual(PulseStrings(language: .english).pressureExplanation(memory), "Watch: 85% used, swap 572 MB, compressed 1.2 KB.")
        XCTAssertEqual(PulseStrings(language: .chinese).pressureExplanation(memory), "偏高：已用 85%，Swap 572 MB，压缩 1.2 KB。")
        XCTAssertEqual(
            PulseStrings(language: .english).thermalExplanation(
                ThermalUsage(condition: .critical, stateDuration: 45)
            ),
            "Very Hot: Very hot for 45 sec."
        )
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
            PulseStrings(language: .english).powerExplanation(
                PowerUsage(
                    hasBattery: true,
                    batteryPercentage: 0.5,
                    isPluggedIn: false,
                    isCharging: false,
                    timeRemaining: 7_800
                )
            ),
            "On battery: 50%, 2h 10m left."
        )
        XCTAssertEqual(
            PulseStrings(language: .chinese).criticalPowerIslandDetail(
                PowerUsage(
                    hasBattery: true,
                    batteryPercentage: 0.09,
                    isPluggedIn: false,
                    isCharging: false,
                    timeRemaining: 1_080
                )
            ),
            "约剩余 18 分钟 · 请尽快接入电源"
        )
        XCTAssertEqual(
            PulseStrings(language: .chinese).criticalPowerIslandDetail(
                PowerUsage(
                    hasBattery: true,
                    batteryPercentage: 0.09,
                    isPluggedIn: false,
                    isCharging: false,
                    timeRemaining: nil
                )
            ),
            "请尽快接入电源"
        )
        XCTAssertEqual(
            PulseStrings(language: .english).criticalPowerIslandDetail(
                PowerUsage(
                    hasBattery: true,
                    batteryPercentage: 0.09,
                    isPluggedIn: false,
                    isCharging: false,
                    timeRemaining: 1_080
                )
            ),
            "About 18m left · Connect power soon"
        )
        XCTAssertEqual(
            PulseStrings(language: .chinese).criticalThermalIslandDetail(
                ThermalUsage(condition: .critical, stateDuration: 12)
            ),
            "建议降低负载或加强散热"
        )
        XCTAssertEqual(
            PulseStrings(language: .english).criticalThermalIslandDetail(
                ThermalUsage(condition: .critical, stateDuration: 12)
            ),
            "Reduce load or improve cooling"
        )
        XCTAssertEqual(
            PulseStrings(language: .chinese).criticalDiskIslandDetail(
                DiskUsage(totalBytes: 100_000_000_000, availableBytes: 4_900_000_000)
            ),
            "剩余 4.9 GB · 请尽快清理空间"
        )
        XCTAssertEqual(
            PulseStrings(language: .english).criticalDiskIslandDetail(
                DiskUsage(totalBytes: 100_000_000_000, availableBytes: 4_900_000_000)
            ),
            "4.9 GB free · Free up storage soon"
        )
        XCTAssertEqual(
            PulseStrings(language: .chinese).criticalMemoryIslandDetail(
                MemoryUsage(
                    totalBytes: 100_000_000_000,
                    usedBytes: 91_000_000_000,
                    availableBytes: 9_000_000_000,
                    compressedBytes: 0,
                    swapUsedBytes: 0,
                    swapTotalBytes: 0
                )
            ),
            "建议关闭部分 App 或浏览器标签"
        )
        XCTAssertEqual(
            PulseStrings(language: .english).criticalMemoryIslandDetail(
                MemoryUsage(
                    totalBytes: 100_000_000_000,
                    usedBytes: 91_000_000_000,
                    availableBytes: 9_000_000_000,
                    compressedBytes: 0,
                    swapUsedBytes: 0,
                    swapTotalBytes: 0
                )
            ),
            "Close some apps or browser tabs"
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
        let diskIO = DiskIOUsage(
            readBytesPerSecond: 52_000,
            writeBytesPerSecond: 249_000,
            totalReadBytes: 0,
            totalWrittenBytes: 0
        )
        XCTAssertEqual(PulseStrings(language: .chinese).diskIOExplanation(diskIO), "磁盘 I/O：读取 51 KB/s，写入 243 KB/s。")
    }

    @MainActor
    func testRuntimeSummaryUsesBootElapsedTime() {
        let runtime = SystemRuntimeUsage(
            bootedAt: Date(timeIntervalSince1970: 1_777_777_777),
            elapsedTime: 93_900
        )

        XCTAssertTrue(PulseStrings(language: .english).runtimeSummary(runtime).hasPrefix("Running 1d 2h · Last boot: "))
        XCTAssertTrue(PulseStrings(language: .chinese).runtimeSummary(runtime).hasPrefix("持续运行：1天2小时 · 上次开机："))
        XCTAssertEqual(PulseStrings(language: .english).runtimeSummary(.empty), "Runtime unavailable")
        XCTAssertEqual(PulseStrings(language: .chinese).runtimeSummary(.empty), "开机时长暂不可用")
    }

    @MainActor
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

    @MainActor
    private func makeUserDefaults() -> UserDefaults {
        let suiteName = "pulse.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @MainActor
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

    private func makeInstalledApplication(
        name: String,
        path: String,
        bundleIdentifier: String? = nil
    ) -> InstalledApplication {
        InstalledApplication(
            name: name,
            bundleIdentifier: bundleIdentifier ?? "com.example.\(name.lowercased())",
            version: "1.0",
            bundlePath: path,
            source: .local
        )
    }
}
