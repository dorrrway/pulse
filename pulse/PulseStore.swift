import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class PulseStore {
    var coreMetrics: CoreMetricsSnapshot = .empty
    var signalMetrics: SignalMetricsSnapshot = .empty
    var processLeaders: ProcessResourceSnapshot = .empty
    var installedApplications: [InstalledApplication] = []
    var isRefreshingInstalledApplications = false
    var installedApplicationsRefreshedAt: Date?
    var runningApplications: RunningApplicationState
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
    var installedAppsDisplayMode: PulseInstalledAppsDisplayMode {
        didSet {
            userDefaults.set(installedAppsDisplayMode.rawValue, forKey: Self.installedAppsDisplayModeKey)
        }
    }
    var favoriteApplicationPaths: [String] {
        didSet {
            userDefaults.set(favoriteApplicationPaths, forKey: Self.favoriteApplicationPathsKey)
        }
    }
    var launchAtLoginStatus: PulseLoginItemStatus
    var launchAtLoginError: PulseLoginItemError?

    private let sampler = SystemSampler()
    private let installedAppCatalog: InstalledAppCatalog
    private var samplingTask: Task<Void, Never>?
    private var installedApplicationsRefreshTask: Task<Void, Never>?
    private let userDefaults: UserDefaults
    private let launchAtLoginService: PulseLoginItemService
    @ObservationIgnored private var runningApplicationObservationTokens: [NSObjectProtocol] = []

    private static let snapshotRefreshInterval: Duration = .seconds(1)
    private static let installedApplicationsRefreshInterval: TimeInterval = 300
    private static let languagePreferenceKey = "pulse.settings.languagePreference"
    private static let appearancePreferenceKey = "pulse.settings.appearancePreference"
    private static let launchAtLoginKey = "pulse.settings.launchAtLogin"
    private static let launchAtLoginDefaultAppliedKey = "pulse.settings.launchAtLoginDefaultApplied"
    private static let installedAppsDisplayModeKey = "pulse.settings.installedApps.displayMode"
    private static let favoriteApplicationPathsKey = "pulse.settings.installedApps.favoritePaths"

    init(
        userDefaults: UserDefaults = .standard,
        launchAtLoginService: PulseLoginItemService = .live,
        installedAppCatalog: InstalledAppCatalog = InstalledAppCatalog(),
        deviceName: String? = nil,
        reconcileLaunchAtLogin: Bool? = nil,
        startSamplingImmediately: Bool = false
    ) {
        self.userDefaults = userDefaults
        self.launchAtLoginService = launchAtLoginService
        self.installedAppCatalog = installedAppCatalog
        let isRunningUnitTests = Self.isRunningUnitTests
        self.deviceName = Self.normalizedDeviceName(deviceName) ?? Self.currentDeviceName()
        self.languagePreference = Self.loadLanguagePreference(from: userDefaults, key: Self.languagePreferenceKey)
        self.appearancePreference = Self.loadAppearancePreference(from: userDefaults, key: Self.appearancePreferenceKey)
        self.launchAtLogin = Self.loadLaunchAtLogin(
            from: userDefaults,
            key: Self.launchAtLoginKey,
            defaultAppliedKey: Self.launchAtLoginDefaultAppliedKey
        )
        self.installedAppsDisplayMode = Self.loadInstalledAppsDisplayMode(
            from: userDefaults,
            key: Self.installedAppsDisplayModeKey
        )
        self.favoriteApplicationPaths = Self.loadFavoriteApplicationPaths(
            from: userDefaults,
            key: Self.favoriteApplicationPathsKey
        )
        self.launchAtLoginStatus = launchAtLoginService.currentStatus()
        self.runningApplications = isRunningUnitTests ? .empty : Self.currentRunningApplicationState()

        if reconcileLaunchAtLogin ?? !isRunningUnitTests {
            reconcilePreferredLaunchAtLogin()
        }

        if !isRunningUnitTests {
            observeRunningApplications()
        }

        if startSamplingImmediately {
            startSampling()
        }
    }

    var strings: PulseStrings {
        PulseStrings(language: languagePreference.resolvedLanguage)
    }

    var favoriteApplications: [InstalledApplication] {
        Self.favoriteApplications(
            from: installedApplications,
            favoritePaths: favoriteApplicationPaths
        )
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

    nonisolated static func favoriteApplications(
        from applications: [InstalledApplication],
        favoritePaths: [String]
    ) -> [InstalledApplication] {
        var applicationsByPath: [String: InstalledApplication] = [:]
        for application in applications {
            guard let path = normalizedApplicationPath(application.bundlePath), applicationsByPath[path] == nil else {
                continue
            }

            applicationsByPath[path] = application
        }

        return sanitizedFavoriteApplicationPaths(favoritePaths)
            .compactMap { applicationsByPath[$0] }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLogin = enabled
        reconcilePreferredLaunchAtLogin()
    }

    func setInstalledAppsDisplayMode(_ mode: PulseInstalledAppsDisplayMode) {
        installedAppsDisplayMode = mode
    }

    func isFavoriteApplication(_ application: InstalledApplication) -> Bool {
        isFavoriteApplication(bundlePath: application.bundlePath)
    }

    func isFavoriteApplication(bundlePath: String) -> Bool {
        guard let path = Self.normalizedApplicationPath(bundlePath) else {
            return false
        }

        return favoriteApplicationPaths.contains(path)
    }

    func isApplicationRunning(_ application: InstalledApplication) -> Bool {
        runningApplications.contains(application)
    }

    func toggleFavoriteApplication(_ application: InstalledApplication) {
        if isFavoriteApplication(application) {
            removeFavoriteApplication(application)
        } else {
            addFavoriteApplication(application)
        }
    }

    @discardableResult
    func addFavoriteApplication(_ application: InstalledApplication) -> Bool {
        addFavoriteApplication(bundlePath: application.bundlePath)
    }

    @discardableResult
    func addFavoriteApplication(bundlePath: String) -> Bool {
        guard
            let path = Self.normalizedApplicationPath(bundlePath),
            installedApplications.contains(where: { Self.normalizedApplicationPath($0.bundlePath) == path })
        else {
            return false
        }

        if !favoriteApplicationPaths.contains(path) {
            favoriteApplicationPaths.append(path)
        }

        return true
    }

    @discardableResult
    func addOrMoveFavoriteApplication(bundlePath: String, before targetBundlePath: String?) -> Bool {
        addOrMoveFavoriteApplication(bundlePath: bundlePath, targetBundlePath: targetBundlePath) { targetIndex in
            targetIndex
        }
    }

    @discardableResult
    func addOrMoveFavoriteApplication(bundlePath: String, after targetBundlePath: String?) -> Bool {
        addOrMoveFavoriteApplication(bundlePath: bundlePath, targetBundlePath: targetBundlePath) { targetIndex in
            targetIndex + 1
        }
    }

    @discardableResult
    func addOrMoveFavoriteApplication(bundlePath: String, atFavoriteIndex index: Int) -> Bool {
        guard
            let path = Self.normalizedApplicationPath(bundlePath),
            installedApplications.contains(where: { Self.normalizedApplicationPath($0.bundlePath) == path })
        else {
            return false
        }

        let originalPaths = Self.sanitizedFavoriteApplicationPaths(favoriteApplicationPaths)
        var insertionIndex = min(max(index, 0), originalPaths.count)
        if let sourceIndex = originalPaths.firstIndex(of: path), sourceIndex < insertionIndex {
            insertionIndex -= 1
        }

        var paths = originalPaths.filter { $0 != path }
        paths.insert(path, at: min(insertionIndex, paths.count))
        favoriteApplicationPaths = paths
        return true
    }

    func removeFavoriteApplication(_ application: InstalledApplication) {
        removeFavoriteApplication(bundlePath: application.bundlePath)
    }

    func removeFavoriteApplication(bundlePath: String) {
        guard let path = Self.normalizedApplicationPath(bundlePath) else {
            return
        }

        favoriteApplicationPaths.removeAll { $0 == path }
    }

    @discardableResult
    private func addOrMoveFavoriteApplication(
        bundlePath: String,
        targetBundlePath: String?,
        insertionIndex: (Int) -> Int
    ) -> Bool {
        guard
            let path = Self.normalizedApplicationPath(bundlePath),
            installedApplications.contains(where: { Self.normalizedApplicationPath($0.bundlePath) == path })
        else {
            return false
        }

        let targetPath = targetBundlePath.flatMap(Self.normalizedApplicationPath)
        guard targetPath != path else {
            return true
        }

        var paths = favoriteApplicationPaths.filter { $0 != path }
        if let targetPath, let targetIndex = paths.firstIndex(of: targetPath) {
            paths.insert(path, at: min(paths.count, max(0, insertionIndex(targetIndex))))
        } else {
            paths.append(path)
        }

        favoriteApplicationPaths = Self.sanitizedFavoriteApplicationPaths(paths)
        return true
    }

    func refreshLaunchAtLoginStatus() {
        launchAtLoginStatus = launchAtLoginService.currentStatus()
    }

    func refreshInstalledApplicationsIfNeeded(force: Bool = false) {
        if isRefreshingInstalledApplications {
            return
        }

        if
            !force,
            !installedApplications.isEmpty,
            let installedApplicationsRefreshedAt,
            Date().timeIntervalSince(installedApplicationsRefreshedAt) < Self.installedApplicationsRefreshInterval
        {
            return
        }

        refreshInstalledApplications()
    }

    func refreshInstalledApplications() {
        installedApplicationsRefreshTask?.cancel()
        isRefreshingInstalledApplications = true

        installedApplicationsRefreshTask = Task { [installedAppCatalog] in
            let applications = await installedAppCatalog.applications()
            guard !Task.isCancelled else {
                return
            }

            installedApplications = applications
            installedApplicationsRefreshedAt = Date()
            isRefreshingInstalledApplications = false
        }
    }

    func refreshRunningApplications() {
        runningApplications = Self.currentRunningApplicationState()
    }

    private func observeRunningApplications() {
        guard runningApplicationObservationTokens.isEmpty else {
            return
        }

        let notificationCenter = NSWorkspace.shared.notificationCenter
        runningApplicationObservationTokens = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
        ].map { name in
            notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshRunningApplications()
                }
            }
        }
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

    private static func loadInstalledAppsDisplayMode(
        from userDefaults: UserDefaults,
        key: String
    ) -> PulseInstalledAppsDisplayMode {
        guard
            let rawValue = userDefaults.string(forKey: key),
            let displayMode = PulseInstalledAppsDisplayMode(rawValue: rawValue)
        else {
            return .icon
        }

        return displayMode
    }

    private static func loadFavoriteApplicationPaths(from userDefaults: UserDefaults, key: String) -> [String] {
        sanitizedFavoriteApplicationPaths(userDefaults.stringArray(forKey: key) ?? [])
    }

    private nonisolated static func sanitizedFavoriteApplicationPaths(_ paths: [String]) -> [String] {
        var seenPaths: Set<String> = []
        var sanitizedPaths: [String] = []

        for path in paths {
            guard let normalizedPath = normalizedApplicationPath(path), !seenPaths.contains(normalizedPath) else {
                continue
            }

            seenPaths.insert(normalizedPath)
            sanitizedPaths.append(normalizedPath)
        }

        return sanitizedPaths
    }

    private nonisolated static func normalizedApplicationPath(_ path: String) -> String? {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            return nil
        }

        return URL(fileURLWithPath: trimmedPath).standardizedFileURL.path
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

    private static func currentRunningApplicationState() -> RunningApplicationState {
        let runningApplications = NSWorkspace.shared.runningApplications
        return RunningApplicationState(
            bundleIdentifiers: runningApplications.compactMap(\.bundleIdentifier),
            bundlePaths: runningApplications.compactMap { $0.bundleURL?.path }
        )
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

nonisolated struct RunningApplicationState: Equatable, Sendable {
    static let empty = RunningApplicationState(bundleIdentifiers: [], bundlePaths: [])

    var bundleIdentifiers: Set<String>
    var bundlePaths: Set<String>

    init(bundleIdentifiers: some Sequence<String>, bundlePaths: some Sequence<String>) {
        self.bundleIdentifiers = Set(bundleIdentifiers.compactMap(Self.normalizedIdentifier))
        self.bundlePaths = Set(bundlePaths.compactMap(Self.normalizedPath))
    }

    func contains(_ application: InstalledApplication) -> Bool {
        if let path = Self.normalizedPath(application.bundlePath), bundlePaths.contains(path) {
            return true
        }

        guard let bundleIdentifier = application.bundleIdentifier.flatMap(Self.normalizedIdentifier) else {
            return false
        }

        return bundleIdentifiers.contains(bundleIdentifier)
    }

    private static func normalizedIdentifier(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func normalizedPath(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        return URL(fileURLWithPath: trimmed).standardizedFileURL.path
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
