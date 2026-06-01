import Foundation

enum PulseIslandSeedMetric: Equatable, Hashable, Sendable {
    case memory
    case cpu
    case power
    case bluetoothBattery(BluetoothBatteryAlert)

    static let rotationInterval: TimeInterval = 3
    static let defaultRotationMetrics: [PulseIslandSeedMetric] = [.memory, .cpu]

    static func rotationMetrics(for power: PowerUsage) -> [PulseIslandSeedMetric] {
        rotationMetrics(for: power, bluetoothDevices: [])
    }

    static func rotationMetrics(
        for power: PowerUsage,
        bluetoothDevices: [BluetoothDevice]
    ) -> [PulseIslandSeedMetric] {
        var metrics = defaultRotationMetrics

        if shouldIncludePower(power) {
            metrics.append(.power)
        }

        metrics += BluetoothBatteryAlert.active(devices: bluetoothDevices).map(Self.bluetoothBattery)

        return metrics
    }

    static func shouldIncludePower(_ power: PowerUsage) -> Bool {
        guard
            power.hasBattery,
            let percentage = power.batteryPercentage
        else {
            return false
        }

        return percentage <= 0.2 && (!power.isPluggedIn || power.isCharging)
    }

    static func shouldPresentCriticalPowerAlert(_ power: PowerUsage) -> Bool {
        guard
            power.hasBattery,
            !power.isPluggedIn,
            let percentage = power.batteryPercentage
        else {
            return false
        }

        return percentage <= 0.1
    }

    static func current(
        elapsedTime: TimeInterval,
        interval: TimeInterval = rotationInterval,
        metrics: [PulseIslandSeedMetric] = defaultRotationMetrics
    ) -> PulseIslandSeedMetric {
        let metrics = normalized(metrics)
        let safeInterval = max(interval, 1)
        let elapsed = max(elapsedTime, 0)
        let index = Int(elapsed / safeInterval) % metrics.count
        return metrics[index]
    }

    var next: PulseIslandSeedMetric {
        next(in: Self.defaultRotationMetrics)
    }

    func next(in metrics: [PulseIslandSeedMetric]) -> PulseIslandSeedMetric {
        let metrics = Self.normalized(metrics)
        guard let currentIndex = metrics.firstIndex(of: self) else {
            return metrics[0]
        }

        return metrics[(currentIndex + 1) % metrics.count]
    }

    func normalized(in metrics: [PulseIslandSeedMetric]) -> PulseIslandSeedMetric {
        let metrics = Self.normalized(metrics)
        return metrics.contains(self) ? self : metrics[0]
    }

    private static func normalized(_ metrics: [PulseIslandSeedMetric]) -> [PulseIslandSeedMetric] {
        metrics.isEmpty ? defaultRotationMetrics : metrics
    }

    func compactIconAssetName(power: PowerUsage) -> String {
        switch self {
        case .memory:
            "IslandMemoryIcon"
        case .cpu:
            "IslandCPUIcon"
        case .power:
            Self.compactPowerIconAssetName(power)
        case .bluetoothBattery(let alert):
            alert.severity == .critical ? "IslandBattery10Icon" : "IslandBattery20Icon"
        }
    }

    static func compactPowerIconAssetName(_ power: PowerUsage) -> String {
        if power.isCharging {
            return "IslandBatteryChargingIcon"
        }

        guard let percentage = power.batteryPercentage else {
            return "IslandBattery20Icon"
        }

        return percentage <= 0.1 ? "IslandBattery10Icon" : "IslandBattery20Icon"
    }
}

enum PulseIslandCriticalAlert: Equatable, Hashable, Sendable {
    case power
    case bluetoothBattery(BluetoothBatteryAlert)
    case thermal
    case disk
    case memory

    private static let lowDiskAvailableBytes: Int64 = 5_000_000_000
    private static let highDiskUsagePercentage = 0.95
    #if DEBUG
    static let previewBluetoothBattery = PulseIslandCriticalAlert.bluetoothBattery(.previewAirPodsProLeftCritical)
    static let previewCases: [PulseIslandCriticalAlert] = [
        .power,
        previewBluetoothBattery,
        .thermal,
        .disk,
        .memory,
    ]
    #endif

    static func active(
        core: CoreMetricsSnapshot,
        signal: SignalMetricsSnapshot,
        bluetoothDevices: [BluetoothDevice] = []
    ) -> [PulseIslandCriticalAlert] {
        var alerts = [PulseIslandCriticalAlert]()

        if PulseIslandSeedMetric.shouldPresentCriticalPowerAlert(signal.power) {
            alerts.append(.power)
        }

        alerts += BluetoothBatteryAlert.active(devices: bluetoothDevices).map(Self.bluetoothBattery)

        if signal.thermal.condition == .critical {
            alerts.append(.thermal)
        }

        if shouldPresentDiskAlert(core.disk) {
            alerts.append(.disk)
        }

        if signal.memory.pressureLevel == .high {
            alerts.append(.memory)
        }

        return alerts
    }

    static func shouldPresentDiskAlert(_ disk: DiskUsage) -> Bool {
        guard disk.totalBytes > 0 else {
            return false
        }

        return disk.availableBytes <= lowDiskAvailableBytes || disk.percentage >= highDiskUsagePercentage
    }

    func iconAssetName(power: PowerUsage) -> String {
        switch self {
        case .power:
            PulseIslandSeedMetric.compactPowerIconAssetName(power)
        case .bluetoothBattery(let alert):
            alert.severity == .critical ? "IslandBattery10Icon" : "IslandBattery20Icon"
        case .thermal:
            "IslandThermalIcon"
        case .disk:
            "IslandStorageIcon"
        case .memory:
            "IslandMemoryIcon"
        }
    }
}

#if DEBUG
struct PulseIslandCriticalAlertPreviewRequest: Equatable, Sendable {
    var id = UUID()
    var alerts: [PulseIslandCriticalAlert]
}
#endif

enum PulseIslandModule: CaseIterable, Equatable, Hashable {
    case resourceMonitor
    case applications
    case clipboard
    case memos
    case screenshots
    case bluetooth
    #if DEBUG
    case translation
    #endif

    static var allCases: [PulseIslandModule] {
        #if DEBUG
        [.resourceMonitor, .applications, .clipboard, .memos, .screenshots, .bluetooth, .translation]
        #else
        [.resourceMonitor, .applications, .clipboard, .memos, .screenshots, .bluetooth]
        #endif
    }

    var titleKey: PulseStrings.Key {
        switch self {
        case .resourceMonitor:
            .resourceMonitoring
        case .applications:
            .applications
        case .clipboard:
            .clipboard
        case .memos:
            .memos
        case .screenshots:
            .screenshots
        case .bluetooth:
            .bluetooth
        #if DEBUG
        case .translation:
            .translation
        #endif
        }
    }

    var iconAssetName: String {
        switch self {
        case .resourceMonitor:
            "IslandResourceMonitorIcon"
        case .applications:
            "IslandApplicationsIcon"
        case .clipboard:
            "IslandClipboardIcon"
        case .memos:
            "ClipboardTextFilterIcon"
        case .screenshots:
            "IslandScreenshotIcon"
        case .bluetooth:
            "IslandBluetoothIcon"
        #if DEBUG
        case .translation:
            "IslandTranslateIcon"
        #endif
        }
    }

    func shifted(by offset: Int) -> PulseIslandModule {
        let modules = Self.allCases
        guard let currentIndex = modules.firstIndex(of: self) else {
            return self
        }

        let nextIndex = (currentIndex + offset + modules.count) % modules.count
        return modules[nextIndex]
    }
}
