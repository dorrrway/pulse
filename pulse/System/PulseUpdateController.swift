import Foundation
import Observation
import Sparkle

struct PulseAvailableUpdate: Equatable, Sendable {
    var version: String
}

@MainActor
@Observable
final class PulseUpdateController {
    var availableUpdate: PulseAvailableUpdate?
    var canCheckForUpdates = false

    @ObservationIgnored private let updaterDelegate: PulseUpdateDelegate?
    @ObservationIgnored private let updaterController: SPUStandardUpdaterController?
    @ObservationIgnored private var canCheckObservation: NSKeyValueObservation?
    @ObservationIgnored private var refreshTask: Task<Void, Never>?

    private static let initialProbeDelay: Duration = .seconds(3)
    private static let probeInterval: Duration = .seconds(24 * 60 * 60)

    init(startingUpdater: Bool = true) {
        guard startingUpdater else {
            updaterDelegate = nil
            updaterController = nil
            return
        }

        let delegate = PulseUpdateDelegate()
        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: delegate,
            userDriverDelegate: nil
        )
        updaterDelegate = delegate
        updaterController = controller

        delegate.controller = self
        observeCanCheckForUpdates(updater: controller.updater)
        startAutomaticProbeLoop()
    }

    deinit {
        refreshTask?.cancel()
        canCheckObservation?.invalidate()
    }

    func installAvailableUpdate() {
        guard let updater = updaterController?.updater, updater.canCheckForUpdates else {
            return
        }

        updater.checkForUpdates()
    }

    private func refreshAvailableUpdate() {
        guard let updater = updaterController?.updater, updater.canCheckForUpdates else {
            return
        }

        updater.checkForUpdateInformation()
    }

    private func observeCanCheckForUpdates(updater: SPUUpdater) {
        canCheckObservation = updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            Task { @MainActor [weak self] in
                self?.canCheckForUpdates = updater.canCheckForUpdates
            }
        }
    }

    private func startAutomaticProbeLoop() {
        refreshTask = Task { [weak self] in
            try? await Task.sleep(for: Self.initialProbeDelay)

            while !Task.isCancelled {
                self?.refreshAvailableUpdate()
                try? await Task.sleep(for: Self.probeInterval)
            }
        }
    }
}

@MainActor
private final class PulseUpdateDelegate: NSObject, SPUUpdaterDelegate {
    weak var controller: PulseUpdateController?

    func allowedSystemProfileKeys(for updater: SPUUpdater) -> [String]? {
        []
    }

    func updaterShouldPromptForPermissionToCheck(forUpdates updater: SPUUpdater) -> Bool {
        false
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        controller?.availableUpdate = PulseAvailableUpdate(version: item.displayVersionString)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: any Error) {
        controller?.availableUpdate = nil
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        controller?.availableUpdate = nil
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
        controller?.availableUpdate = nil
    }
}
