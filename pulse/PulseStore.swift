import Foundation
import Observation

@MainActor
@Observable
final class PulseStore {
    var snapshot: ResourceSnapshot = .empty
    var deviceName: String?
    var languagePreference: PulseLanguagePreference {
        didSet {
            userDefaults.set(languagePreference.rawValue, forKey: Self.languagePreferenceKey)
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

    private static let languagePreferenceKey = "pulse.settings.languagePreference"
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
                snapshot = await sampler.sample()

                do {
                    try await Task.sleep(for: .seconds(2))
                } catch {
                    return
                }
            }
        }
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
