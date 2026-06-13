import Foundation
import IOKit
import Observation

@MainActor
@Observable
final class BluetoothDeviceStore {
    var devices: [BluetoothDevice] = []
    var isRefreshing = false
    var lastRefreshedAt: Date?
    var issue: BluetoothDeviceIssue?
    var authorizationStatus = BluetoothAuthorizationStatus.current
    var powerState = BluetoothPowerState.unknown
    var activeActionDeviceID: BluetoothDevice.ID?

    @ObservationIgnored private let sampler: BluetoothDeviceSampler
    @ObservationIgnored private var powerMonitor: BluetoothPowerMonitor?
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var monitoringTask: Task<Void, Never>?
    @ObservationIgnored private var monitoringCadence: BluetoothMonitoringCadence?
    @ObservationIgnored private var isBackgroundMonitoringEnabled = false
    @ObservationIgnored private var foregroundMonitoringCount = 0

    fileprivate static let foregroundRefreshInterval: Duration = .seconds(8)
    fileprivate static let backgroundRefreshInterval: Duration = .seconds(60)

    init(sampler: BluetoothDeviceSampler = BluetoothDeviceSampler()) {
        self.sampler = sampler
    }

    var needsInitialAuthorization: Bool {
        authorizationStatus.needsInitialRequest
    }

    var isBluetoothPoweredOff: Bool {
        powerState == .poweredOff
    }

    func startBackgroundMonitoring() {
        isBackgroundMonitoringEnabled = true
        reconcileMonitoring()
    }

    func stopBackgroundMonitoring() {
        isBackgroundMonitoringEnabled = false
        reconcileMonitoring()
    }

    func startMonitoring() {
        foregroundMonitoringCount += 1
        reconcileMonitoring()
    }

    func stopMonitoring() {
        foregroundMonitoringCount = max(foregroundMonitoringCount - 1, 0)
        reconcileMonitoring()
    }

    func stopAllMonitoring() {
        isBackgroundMonitoringEnabled = false
        foregroundMonitoringCount = 0
        cancelMonitoringTask()
        stopPowerMonitoring()
        refreshTask?.cancel()
        refreshTask = nil
        isRefreshing = false
    }

    func refresh() {
        refreshAuthorizationStatus()
        guard authorizationStatus.canSampleDevices else {
            stopPowerMonitoring()
            publishAuthorizationBlock()
            return
        }

        guard powerState.canSampleDevices else {
            publishPowerBlock()
            return
        }

        guard refreshTask == nil else {
            return
        }

        isRefreshing = true
        refreshTask = Task { @MainActor [weak self, sampler] in
            let snapshot = await sampler.snapshot()
            guard !Task.isCancelled else {
                return
            }

            self?.refreshAuthorizationStatus()
            self?.publish(snapshot)
        }
    }

    func connect(_ device: BluetoothDevice) {
        performConnectionAction(device, action: .connect)
    }

    func disconnect(_ device: BluetoothDevice) {
        performConnectionAction(device, action: .disconnect)
    }

    private func publish(_ snapshot: BluetoothDeviceSnapshot) {
        devices = snapshot.devices
        lastRefreshedAt = snapshot.capturedAt
        issue = snapshot.errorMessage.map(BluetoothDeviceIssue.permission) ?? issue?.nonActionIssue
        isRefreshing = false
        refreshTask = nil
    }

    private func refreshAuthorizationStatus() {
        authorizationStatus = .current
    }

    private var desiredMonitoringCadence: BluetoothMonitoringCadence? {
        if foregroundMonitoringCount > 0 {
            return .foreground
        }

        return isBackgroundMonitoringEnabled ? .background : nil
    }

    private func reconcileMonitoring() {
        refreshAuthorizationStatus()

        guard let cadence = desiredMonitoringCadence else {
            cancelMonitoringTask()
            stopPowerMonitoring()
            return
        }

        guard authorizationStatus.canSampleDevices else {
            stopPowerMonitoring()
            cancelMonitoringTask()
            publishAuthorizationBlock()
            return
        }

        startPowerMonitoring()
        guard powerState.canSampleDevices else {
            cancelMonitoringTask()
            publishPowerBlock()
            return
        }

        guard monitoringTask == nil || monitoringCadence != cadence else {
            refresh()
            return
        }

        cancelMonitoringTask()
        monitoringCadence = cadence
        refresh()
        monitoringTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: cadence.refreshInterval)
                } catch {
                    return
                }

                self?.refresh()
            }
        }
    }

    private func cancelMonitoringTask() {
        monitoringTask?.cancel()
        monitoringTask = nil
        monitoringCadence = nil
    }

    private func publishAuthorizationBlock() {
        devices = []
        isRefreshing = false
        refreshTask = nil
        issue = authorizationStatus.isBlocked
            ? .permission("Bluetooth permission is not available.")
            : nil
    }

    private func startPowerMonitoring() {
        guard powerMonitor == nil else {
            return
        }

        let monitor = BluetoothPowerMonitor { [weak self] state in
            self?.publishPowerState(state)
        }
        powerMonitor = monitor
        monitor.start()
    }

    private func stopPowerMonitoring() {
        powerMonitor?.stop()
        powerMonitor = nil
        powerState = .unknown
    }

    private func publishPowerState(_ state: BluetoothPowerState) {
        guard powerState != state else {
            return
        }

        powerState = state
        if state.canSampleDevices {
            reconcileMonitoring()
        } else {
            cancelMonitoringTask()
            publishPowerBlock()
        }
    }

    private func publishPowerBlock() {
        refreshTask?.cancel()
        refreshTask = nil
        activeActionDeviceID = nil
        devices = []
        isRefreshing = false
        issue = nil
    }

    private func performConnectionAction(_ device: BluetoothDevice, action: BluetoothConnectionAction) {
        guard powerState.canSampleDevices else {
            publishPowerBlock()
            return
        }

        guard let address = device.address else {
            issue = .actionFailed
            return
        }

        activeActionDeviceID = device.id
        issue = issue?.nonActionIssue

        Task { @MainActor [weak self, sampler] in
            let result: IOReturn
            switch action {
            case .connect:
                result = await sampler.connect(address: address)
            case .disconnect:
                result = await sampler.disconnect(address: address)
            }

            guard !Task.isCancelled else {
                return
            }

            if result != kIOReturnSuccess {
                self?.issue = .actionFailed
            }

            self?.activeActionDeviceID = nil
            self?.refreshTask = nil
            self?.refresh()
        }
    }
}

private enum BluetoothMonitoringCadence: Equatable {
    case foreground
    case background

    var refreshInterval: Duration {
        switch self {
        case .foreground:
            BluetoothDeviceStore.foregroundRefreshInterval
        case .background:
            BluetoothDeviceStore.backgroundRefreshInterval
        }
    }
}

nonisolated enum BluetoothConnectionAction: Sendable {
    case connect
    case disconnect
}

nonisolated enum BluetoothDeviceIssue: Equatable, Sendable {
    case permission(String)
    case actionFailed

    var nonActionIssue: BluetoothDeviceIssue? {
        switch self {
        case .permission:
            self
        case .actionFailed:
            nil
        }
    }
}
