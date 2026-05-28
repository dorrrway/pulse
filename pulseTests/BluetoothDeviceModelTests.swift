import AppKit
import XCTest
@testable import pulse

final class BluetoothDeviceModelTests: XCTestCase {
    func testAuthorizationStatusRequiresExplicitRequestBeforeSampling() {
        XCTAssertTrue(BluetoothAuthorizationStatus.notDetermined.needsInitialRequest)
        XCTAssertFalse(BluetoothAuthorizationStatus.notDetermined.canSampleDevices)
        XCTAssertFalse(BluetoothAuthorizationStatus.denied.canSampleDevices)
        XCTAssertTrue(BluetoothAuthorizationStatus.allowed.canSampleDevices)
    }

    func testParsesBatteryPercentageStrings() {
        let level = BluetoothBatteryLevel.parsed(role: .case, value: "34%")

        XCTAssertEqual(level, BluetoothBatteryLevel(role: .case, percentage: 0.34))
    }

    func testAppleHIDBatteryLevelMarksChargingFromExtendedStatusFlags() {
        let charging = BluetoothBatteryLevel.appleHIDDevice(
            percentage: 26,
            supportsExtendedBatteryState: true,
            statusFlags: 3
        )
        let notCharging = BluetoothBatteryLevel.appleHIDDevice(
            percentage: 45,
            supportsExtendedBatteryState: true,
            statusFlags: 4
        )
        let unknown = BluetoothBatteryLevel.appleHIDDevice(
            percentage: 45,
            supportsExtendedBatteryState: false,
            statusFlags: 3
        )

        XCTAssertEqual(charging, BluetoothBatteryLevel(role: .device, percentage: 0.26, isCharging: true))
        XCTAssertFalse(notCharging.isCharging)
        XCTAssertFalse(unknown.isCharging)
    }

    func testBluetoothBatteryLevelDecodesLegacyPayloadWithoutChargingState() throws {
        let data = #"{"role":"device","percentage":0.5}"#.data(using: .utf8)!
        let level = try JSONDecoder().decode(BluetoothBatteryLevel.self, from: data)

        XCTAssertEqual(level, BluetoothBatteryLevel(role: .device, percentage: 0.5))
    }

    func testInfersTrackpadCategoryFromName() {
        XCTAssertEqual(BluetoothDeviceCategory.inferred(name: "Magic Trackpad", minorType: nil), .trackpad)
    }

    func testSortsAirPodsBatteryRolesBeforeDeviceBattery() {
        let device = BluetoothDevice(
            id: "airpods",
            name: "AirPods Pro",
            category: .headphones,
            batteryLevels: [
                BluetoothBatteryLevel(role: .device, percentage: 0.9),
                BluetoothBatteryLevel(role: .case, percentage: 0.34),
                BluetoothBatteryLevel(role: .right, percentage: 0.95),
                BluetoothBatteryLevel(role: .left, percentage: 0.96),
            ]
        )

        XCTAssertEqual(device.batteryLevels.map(\.role), [.left, .right, .case, .device])
    }

    func testAirPodsProUsesSpecificRowAndBatterySymbols() {
        let device = BluetoothDevice(
            id: "airpods-pro",
            name: "Highway's AirPods Pro",
            category: .headphones
        )

        XCTAssertEqual(BluetoothDeviceSymbol.row(for: device).candidates.first, "airpods.pro")
        XCTAssertEqual(BluetoothDeviceSymbol.battery(for: device, role: .left).candidates.first, "airpods.pro.left")
        XCTAssertEqual(BluetoothDeviceSymbol.battery(for: device, role: .right).candidates.first, "airpods.pro.right")
        XCTAssertEqual(BluetoothDeviceSymbol.battery(for: device, role: .case).candidates.first, "airpods.pro.chargingcase.wireless")
        XCTAssertEqual(BluetoothDeviceSymbol.battery(for: device, role: .device).candidates.first, "airpods.pro")
    }

    func testAirPodsGenerationSymbolsUseCanonicalSFNames() {
        let airPods3 = BluetoothDevice(id: "airpods-3", name: "AirPods 3", category: .headphones)
        let airPods4 = BluetoothDevice(id: "airpods-4", name: "AirPods 4", category: .headphones)

        XCTAssertEqual(BluetoothDeviceSymbol.row(for: airPods3).candidates.first, "airpods.gen3")
        XCTAssertEqual(BluetoothDeviceSymbol.battery(for: airPods3, role: .left).candidates.first, "airpod.gen3.left")
        XCTAssertEqual(BluetoothDeviceSymbol.battery(for: airPods3, role: .right).candidates.first, "airpod.gen3.right")
        XCTAssertEqual(BluetoothDeviceSymbol.battery(for: airPods3, role: .case).candidates.first, "airpods.gen3.chargingcase.wireless")

        XCTAssertEqual(BluetoothDeviceSymbol.row(for: airPods4).candidates.first, "airpods.gen4")
        XCTAssertEqual(BluetoothDeviceSymbol.battery(for: airPods4, role: .left).candidates.first, "airpods.gen4.left")
        XCTAssertEqual(BluetoothDeviceSymbol.battery(for: airPods4, role: .right).candidates.first, "airpods.gen4.right")
        XCTAssertEqual(BluetoothDeviceSymbol.battery(for: airPods4, role: .case).candidates.first, "airpods.gen4.chargingcase.wireless")
    }

    func testKnownAudioSymbolPrimaryCandidatesResolveOnCurrentSystem() throws {
        let devices = [
            BluetoothDevice(id: "airpods-pro", name: "AirPods Pro", category: .headphones),
            BluetoothDevice(id: "airpods-3", name: "AirPods 3", category: .headphones),
            BluetoothDevice(id: "airpods-4", name: "AirPods 4", category: .headphones),
            BluetoothDevice(id: "beats-fit-pro", name: "Beats Fit Pro", category: .headphones),
        ]

        let primaryCandidates = devices.flatMap { device in
            [
                BluetoothDeviceSymbol.row(for: device).candidates.first,
                BluetoothDeviceSymbol.battery(for: device, role: .left).candidates.first,
                BluetoothDeviceSymbol.battery(for: device, role: .right).candidates.first,
                BluetoothDeviceSymbol.battery(for: device, role: .case).candidates.first,
            ]
        }

        for candidate in primaryCandidates {
            let name = try XCTUnwrap(candidate)
            XCTAssertNotNil(NSImage(systemSymbolName: name, accessibilityDescription: nil), name)
        }
    }

    func testAirPodsMaxDoesNotUseGenericHeadphonesFirst() {
        let device = BluetoothDevice(
            id: "airpods-max",
            name: "AirPods Max",
            category: .headphones
        )

        XCTAssertEqual(BluetoothDeviceSymbol.row(for: device).candidates.first, "airpods.max")
    }

    func testCommonBluetoothDevicesUseSpecificSymbolsBeforeFallbacks() {
        let trackpad = BluetoothDevice(id: "trackpad", name: "Magic Trackpad", category: .trackpad)
        let mouse = BluetoothDevice(id: "mouse", name: "Magic Mouse", category: .mouse)
        let keyboard = BluetoothDevice(id: "keyboard", name: "Magic Keyboard", category: .keyboard)
        let beats = BluetoothDevice(id: "beats", name: "Beats Fit Pro", category: .headphones)

        XCTAssertEqual(BluetoothDeviceSymbol.row(for: trackpad).candidates.first, "trackpad")
        XCTAssertEqual(BluetoothDeviceSymbol.row(for: mouse).candidates.first, "magicmouse")
        XCTAssertEqual(BluetoothDeviceSymbol.row(for: keyboard).candidates.first, "keyboard")
        XCTAssertEqual(BluetoothDeviceSymbol.row(for: beats).candidates.first, "beats.fitpro")
        XCTAssertEqual(BluetoothDeviceSymbol.battery(for: beats, role: .left).candidates.first, "beats.fitpro.left")
    }

    func testBuildsLowBatteryAlertsAtWarningAndCriticalThresholds() {
        let device = BluetoothDevice(
            id: "airpods",
            name: "AirPods Pro",
            category: .headphones,
            connectionState: .disconnected,
            batteryLevels: [
                BluetoothBatteryLevel(role: .left, percentage: 0.2),
                BluetoothBatteryLevel(role: .right, percentage: 0.1),
                BluetoothBatteryLevel(role: .case, percentage: 0.21),
            ]
        )

        let alerts = device.lowBatteryAlerts

        XCTAssertEqual(alerts.map(\.role), [.left, .right])
        XCTAssertEqual(alerts.map(\.severity), [.low, .critical])
    }

    func testChargingBluetoothBatteryDoesNotBuildLowBatteryAlert() {
        let device = BluetoothDevice(
            id: "trackpad",
            name: "Magic Trackpad",
            category: .trackpad,
            connectionState: .connected,
            batteryLevels: [
                BluetoothBatteryLevel(role: .device, percentage: 0.09, isCharging: true),
            ]
        )

        XCTAssertTrue(device.lowBatteryAlerts.isEmpty)
    }

    #if DEBUG
    func testPreviewBluetoothBatteryAlertUsesFakeAirPodsCriticalBattery() {
        let alert = BluetoothBatteryAlert.previewAirPodsProLeftCritical

        XCTAssertEqual(alert.deviceID, "debug-airpods-pro")
        XCTAssertEqual(alert.deviceName, "AirPods Pro")
        XCTAssertEqual(alert.category, .headphones)
        XCTAssertEqual(alert.role, .left)
        XCTAssertEqual(alert.percentage, 0.09)
        XCTAssertEqual(alert.severity, .critical)
        XCTAssertTrue(alert.isConnected)
    }
    #endif

    func testBatteryAlertIdentityIgnoresPercentageButKeepsSeverity() {
        let warning = BluetoothBatteryAlert(
            deviceID: "keyboard",
            deviceName: "Keyboard",
            category: .keyboard,
            role: .device,
            percentage: 0.19,
            severity: .low,
            isConnected: true
        )
        let lowerWarning = BluetoothBatteryAlert(
            deviceID: "keyboard",
            deviceName: "Keyboard",
            category: .keyboard,
            role: .device,
            percentage: 0.18,
            severity: .low,
            isConnected: true
        )
        let critical = BluetoothBatteryAlert(
            deviceID: "keyboard",
            deviceName: "Keyboard",
            category: .keyboard,
            role: .device,
            percentage: 0.1,
            severity: .critical,
            isConnected: true
        )

        XCTAssertEqual(warning, lowerWarning)
        XCTAssertNotEqual(warning, critical)
    }

    func testMergingPrefersAvailableBatteryAndConnectedState() {
        let disconnected = BluetoothDevice(
            id: "keyboard",
            name: "Keyboard",
            address: "38:09:fb:23:9d:14",
            category: .keyboard,
            connectionState: .disconnected
        )
        let connectedWithBattery = BluetoothDevice(
            id: "keyboard",
            name: "Keyboard",
            address: "38:09:fb:23:9d:14",
            category: .unknown,
            connectionState: .connected,
            batteryLevels: [
                BluetoothBatteryLevel(role: .device, percentage: 0.47),
            ]
        )

        let merged = disconnected.merged(with: connectedWithBattery)

        XCTAssertEqual(merged.connectionState, .connected)
        XCTAssertEqual(merged.category, .keyboard)
        XCTAssertEqual(merged.batteryLevels, connectedWithBattery.batteryLevels)
    }
}
