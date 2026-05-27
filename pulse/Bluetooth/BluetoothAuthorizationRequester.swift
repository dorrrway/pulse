import CoreBluetooth
import Foundation

extension BluetoothAuthorizationStatus {
    nonisolated static var current: Self {
        Self(authorization: CBManager.authorization)
    }

    nonisolated init(authorization: CBManagerAuthorization) {
        switch authorization {
        case .notDetermined:
            self = .notDetermined
        case .restricted:
            self = .restricted
        case .denied:
            self = .denied
        case .allowedAlways:
            self = .allowed
        @unknown default:
            self = .restricted
        }
    }
}

@MainActor
final class BluetoothAuthorizationRequester: NSObject, CBCentralManagerDelegate {
    static let shared = BluetoothAuthorizationRequester()

    private var manager: CBCentralManager?
    private var continuations: [CheckedContinuation<BluetoothAuthorizationStatus, Never>] = []

    private override init() {
        super.init()
    }

    func requestAfterPanelCollapse() async -> BluetoothAuthorizationStatus {
        try? await Task.sleep(for: .milliseconds(240))
        return await requestAuthorization()
    }

    func requestAuthorization() async -> BluetoothAuthorizationStatus {
        let current = BluetoothAuthorizationStatus.current
        guard current == .notDetermined else {
            return current
        }

        return await withCheckedContinuation { continuation in
            continuations.append(continuation)

            guard manager == nil else {
                return
            }

            manager = CBCentralManager(
                delegate: self,
                queue: .main,
                options: [
                    CBCentralManagerOptionShowPowerAlertKey: false,
                ]
            )
        }
    }

    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            finish(with: .current)
        }
    }

    private func finish(with status: BluetoothAuthorizationStatus) {
        guard status != .notDetermined else {
            return
        }

        let pending = continuations
        continuations.removeAll()
        manager = nil
        pending.forEach { $0.resume(returning: status) }
    }
}
