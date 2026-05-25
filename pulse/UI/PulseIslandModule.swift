import Foundation

enum PulseIslandSeedMetric: CaseIterable, Equatable, Sendable {
    case memory
    case cpu
    case power

    static let rotationInterval: TimeInterval = 3
    static let defaultRotationMetrics: [PulseIslandSeedMetric] = [.memory, .cpu]

    static func rotationMetrics(for power: PowerUsage) -> [PulseIslandSeedMetric] {
        guard shouldIncludePower(power) else {
            return defaultRotationMetrics
        }

        return defaultRotationMetrics + [.power]
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

enum PulseIslandCriticalAlert: CaseIterable, Equatable, Hashable, Sendable {
    case power
    case thermal
    case disk
    case memory

    private static let lowDiskAvailableBytes: Int64 = 5_000_000_000
    private static let highDiskUsagePercentage = 0.95

    static func active(
        core: CoreMetricsSnapshot,
        signal: SignalMetricsSnapshot
    ) -> [PulseIslandCriticalAlert] {
        allCases.filter { alert in
            switch alert {
            case .power:
                PulseIslandSeedMetric.shouldPresentCriticalPowerAlert(signal.power)
            case .thermal:
                signal.thermal.condition == .critical
            case .disk:
                shouldPresentDiskAlert(core.disk)
            case .memory:
                signal.memory.pressureLevel == .high
            }
        }
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

enum PulseIslandModule: CaseIterable, Equatable {
    case resourceMonitor
    case applications

    var titleKey: PulseStrings.Key {
        switch self {
        case .resourceMonitor:
            .resourceMonitoring
        case .applications:
            .applications
        }
    }

    var iconAssetName: String {
        switch self {
        case .resourceMonitor:
            "IslandResourceMonitorIcon"
        case .applications:
            "IslandApplicationsIcon"
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
