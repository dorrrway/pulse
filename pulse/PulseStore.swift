import Foundation
import Observation

@MainActor
@Observable
final class PulseStore {
    var coreMetrics: CoreMetricsSnapshot = .empty
    var signalMetrics: SignalMetricsSnapshot = .empty
    var processLeaders: ProcessResourceSnapshot = .empty
    var capturedAt: Date = .distantPast
    var deviceName: String?
    var languagePreference: PulseLanguagePreference {
        didSet {
            userDefaults.set(languagePreference.rawValue, forKey: Self.languagePreferenceKey)
        }
    }
    var appearancePreference: PulseAppearancePreference {
        didSet {
            userDefaults.set(appearancePreference.rawValue, forKey: Self.appearancePreferenceKey)
        }
    }
    var launchAtLogin: Bool {
        didSet {
            userDefaults.set(launchAtLogin, forKey: Self.launchAtLoginKey)
        }
    }
    var launchAtLoginStatus: PulseLoginItemStatus
    var launchAtLoginError: PulseLoginItemError?

    private let sampler = SystemSampler()
    private var samplingTask: Task<Void, Never>?
    private let userDefaults: UserDefaults
    private let launchAtLoginService: PulseLoginItemService

    private static let snapshotRefreshInterval: Duration = .seconds(1)
    private static let languagePreferenceKey = "pulse.settings.languagePreference"
    private static let appearancePreferenceKey = "pulse.settings.appearancePreference"
    private static let launchAtLoginKey = "pulse.settings.launchAtLogin"
    private static let launchAtLoginDefaultAppliedKey = "pulse.settings.launchAtLoginDefaultApplied"

    init(
        userDefaults: UserDefaults = .standard,
        launchAtLoginService: PulseLoginItemService = .live,
        deviceName: String? = nil,
        reconcileLaunchAtLogin: Bool? = nil,
        startSamplingImmediately: Bool = false
    ) {
        self.userDefaults = userDefaults
        self.launchAtLoginService = launchAtLoginService
        self.deviceName = Self.normalizedDeviceName(deviceName) ?? Self.currentDeviceName()
        self.languagePreference = Self.loadLanguagePreference(from: userDefaults, key: Self.languagePreferenceKey)
        self.appearancePreference = Self.loadAppearancePreference(from: userDefaults, key: Self.appearancePreferenceKey)
        self.launchAtLogin = Self.loadLaunchAtLogin(
            from: userDefaults,
            key: Self.launchAtLoginKey,
            defaultAppliedKey: Self.launchAtLoginDefaultAppliedKey
        )
        self.launchAtLoginStatus = launchAtLoginService.currentStatus()

        if reconcileLaunchAtLogin ?? !Self.isRunningUnitTests {
            reconcilePreferredLaunchAtLogin()
        }

        if startSamplingImmediately {
            startSampling()
        }
    }

    var strings: PulseStrings {
        PulseStrings(language: languagePreference.resolvedLanguage)
    }

    func startSampling() {
        guard samplingTask == nil else {
            return
        }

        samplingTask = Task { [sampler] in
            while !Task.isCancelled {
                publish(await sampler.sample())

                do {
                    try await Task.sleep(for: Self.snapshotRefreshInterval)
                } catch {
                    return
                }
            }
        }
    }

    private func publish(_ snapshot: ResourceSnapshot) {
        let nextCoreMetrics = CoreMetricsSnapshot(snapshot)
        if Self.shouldPublishCoreMetrics(previous: coreMetrics, next: nextCoreMetrics) {
            coreMetrics = nextCoreMetrics
        }

        let nextSignalMetrics = SignalMetricsSnapshot(snapshot)
        if Self.shouldPublishSignalMetrics(previous: signalMetrics, next: nextSignalMetrics) {
            signalMetrics = nextSignalMetrics
        }

        if processLeaders != snapshot.processes {
            processLeaders = snapshot.processes
        }

        if Self.shouldPublishCapturedAt(previous: capturedAt, next: snapshot.capturedAt) {
            capturedAt = snapshot.capturedAt
        }
    }

    nonisolated static func shouldPublishCoreMetrics(
        previous: CoreMetricsSnapshot,
        next: CoreMetricsSnapshot
    ) -> Bool {
        coreDisplayFingerprint(previous) != coreDisplayFingerprint(next)
    }

    nonisolated static func shouldPublishSignalMetrics(
        previous: SignalMetricsSnapshot,
        next: SignalMetricsSnapshot
    ) -> Bool {
        signalDisplayFingerprint(previous) != signalDisplayFingerprint(next)
    }

    nonisolated static func shouldPublishCapturedAt(previous: Date, next: Date) -> Bool {
        guard previous != .distantPast else {
            return true
        }

        return minuteBucket(previous) != minuteBucket(next)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLogin = enabled
        reconcilePreferredLaunchAtLogin()
    }

    func refreshLaunchAtLoginStatus() {
        launchAtLoginStatus = launchAtLoginService.currentStatus()
    }

    private func reconcilePreferredLaunchAtLogin() {
        do {
            launchAtLoginStatus = try launchAtLoginService.apply(launchAtLogin)
            launchAtLoginError = nil
        } catch let error as PulseLoginItemError {
            launchAtLoginStatus = launchAtLoginService.currentStatus()
            launchAtLoginError = error
        } catch {
            launchAtLoginStatus = launchAtLoginService.currentStatus()
            launchAtLoginError = .serviceError(error.localizedDescription)
        }
    }

    private static func loadLanguagePreference(from userDefaults: UserDefaults, key: String) -> PulseLanguagePreference {
        guard
            let rawValue = userDefaults.string(forKey: key),
            let preference = PulseLanguagePreference(rawValue: rawValue)
        else {
            return .system
        }

        return preference
    }

    private nonisolated static func coreDisplayFingerprint(_ metrics: CoreMetricsSnapshot) -> CoreDisplayFingerprint {
        CoreDisplayFingerprint(
            cpuPercentage: ResourceFormatters.percentage(metrics.cpu.percentage),
            cpuMeter: meterBucket(metrics.cpu.percentage),
            cpuCoreCount: metrics.cpu.coreCount,
            memoryPercentage: ResourceFormatters.percentage(metrics.memory.percentage),
            memoryMeter: meterBucket(metrics.memory.percentage),
            memoryUsed: ResourceFormatters.byteString(bytes: metrics.memory.usedBytes),
            memoryTotal: ResourceFormatters.byteString(bytes: metrics.memory.totalBytes),
            networkIncoming: ResourceFormatters.byteRate(bytesPerSecond: metrics.network.incomingBytesPerSecond),
            networkOutgoing: ResourceFormatters.byteRate(bytesPerSecond: metrics.network.outgoingBytesPerSecond),
            networkMeter: meterBucket(
                ResourceScales.networkActivityProgress(
                    bytesPerSecond: metrics.network.incomingBytesPerSecond + metrics.network.outgoingBytesPerSecond
                )
            ),
            diskPercentage: ResourceFormatters.percentage(metrics.disk.percentage),
            diskMeter: meterBucket(metrics.disk.percentage),
            diskAvailable: ResourceFormatters.storageByteString(bytes: metrics.disk.availableBytes)
        )
    }

    private nonisolated static func signalDisplayFingerprint(_ metrics: SignalMetricsSnapshot) -> SignalDisplayFingerprint {
        SignalDisplayFingerprint(
            memoryPercentage: ResourceFormatters.percentage(metrics.memory.percentage),
            memoryPressure: metrics.memory.pressureLevel,
            memorySwap: ResourceFormatters.byteString(bytes: metrics.memory.swapUsedBytes),
            memoryCompressed: ResourceFormatters.byteString(bytes: metrics.memory.compressedBytes),
            thermalCondition: metrics.thermal.condition,
            thermalDuration: compactDurationBucket(metrics.thermal.stateDuration),
            powerHasBattery: metrics.power.hasBattery,
            powerBatteryPercentage: metrics.power.batteryPercentage.map(ResourceFormatters.percentage),
            powerIsPluggedIn: metrics.power.isPluggedIn,
            powerIsCharging: metrics.power.isCharging,
            powerRemainingMinutes: metrics.power.timeRemaining.map(remainingPowerMinuteBucket),
            diskIORead: ResourceFormatters.byteRate(bytesPerSecond: metrics.diskIO.readBytesPerSecond),
            diskIOWrite: ResourceFormatters.byteRate(bytesPerSecond: metrics.diskIO.writeBytesPerSecond),
            diskIOActivityLevel: diskIOActivityLevel(metrics.diskIO),
            runtimeBootedAt: metrics.runtime.bootedAt,
            runtimeDuration: longDurationBucket(metrics.runtime.elapsedTime)
        )
    }

    private nonisolated static func meterBucket(_ value: Double) -> Int {
        Int((min(max(value, 0), 1) * 18).rounded())
    }

    private nonisolated static func compactDurationBucket(_ duration: TimeInterval) -> Int {
        let totalSeconds = max(Int(duration.rounded(.down)), 0)
        if totalSeconds < 10 {
            return 0
        }
        if totalSeconds < 60 {
            return totalSeconds
        }
        if totalSeconds < 60 * 60 {
            return totalSeconds / 60
        }

        return totalSeconds / (60 * 60)
    }

    private nonisolated static func longDurationBucket(_ duration: TimeInterval) -> Int {
        max(Int(duration.rounded(.down)) / 60, 0)
    }

    private nonisolated static func remainingPowerMinuteBucket(_ duration: TimeInterval) -> Int {
        max(Int(duration.rounded(.down)) / 60, 1)
    }

    private nonisolated static func minuteBucket(_ date: Date) -> Int {
        Int(date.timeIntervalSince1970.rounded(.down)) / 60
    }

    private nonisolated static func diskIOActivityLevel(_ usage: DiskIOUsage) -> Int {
        let totalBytesPerSecond = max(usage.readBytesPerSecond, 0) + max(usage.writeBytesPerSecond, 0)
        return totalBytesPerSecond >= 50_000_000 ? 1 : 0
    }

    private static func loadAppearancePreference(from userDefaults: UserDefaults, key: String) -> PulseAppearancePreference {
        guard
            let rawValue = userDefaults.string(forKey: key),
            let preference = PulseAppearancePreference(rawValue: rawValue)
        else {
            return .system
        }

        return preference
    }

    private static func loadLaunchAtLogin(
        from userDefaults: UserDefaults,
        key: String,
        defaultAppliedKey: String
    ) -> Bool {
        if userDefaults.object(forKey: defaultAppliedKey) as? Bool == true,
           let value = userDefaults.object(forKey: key) as? Bool {
            return value
        }

        userDefaults.set(true, forKey: key)
        userDefaults.set(true, forKey: defaultAppliedKey)
        return userDefaults.object(forKey: key) as? Bool ?? true
    }

    private static func currentDeviceName() -> String? {
        normalizedDeviceName(Host.current().localizedName)
            ?? normalizedDeviceName(ProcessInfo.processInfo.hostName)
    }

    private static func normalizedDeviceName(_ name: String?) -> String? {
        guard let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }

        return trimmed
    }

    private static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}

private nonisolated struct CoreDisplayFingerprint: Equatable {
    var cpuPercentage: String
    var cpuMeter: Int
    var cpuCoreCount: Int
    var memoryPercentage: String
    var memoryMeter: Int
    var memoryUsed: String
    var memoryTotal: String
    var networkIncoming: String
    var networkOutgoing: String
    var networkMeter: Int
    var diskPercentage: String
    var diskMeter: Int
    var diskAvailable: String
}

private nonisolated struct SignalDisplayFingerprint: Equatable {
    var memoryPercentage: String
    var memoryPressure: PressureLevel
    var memorySwap: String
    var memoryCompressed: String
    var thermalCondition: ThermalCondition
    var thermalDuration: Int
    var powerHasBattery: Bool
    var powerBatteryPercentage: String?
    var powerIsPluggedIn: Bool
    var powerIsCharging: Bool
    var powerRemainingMinutes: Int?
    var diskIORead: String
    var diskIOWrite: String
    var diskIOActivityLevel: Int
    var runtimeBootedAt: Date?
    var runtimeDuration: Int
}
