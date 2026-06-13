import Foundation

struct PulseNotificationSuggestion: Equatable, Identifiable, Sendable {
    static let defaultLimit = 2

    var alert: PulseIslandCriticalAlert

    var id: String {
        alert.notificationSuggestionID
    }

    static func active(
        core: CoreMetricsSnapshot,
        signal: SignalMetricsSnapshot,
        bluetoothDevices: [BluetoothDevice],
        isEnabled: Bool,
        dismissedIDs: Set<String>,
        limit: Int = defaultLimit
    ) -> [PulseNotificationSuggestion] {
        guard isEnabled, limit > 0 else {
            return []
        }

        return allActive(core: core, signal: signal, bluetoothDevices: bluetoothDevices)
            .filter { !dismissedIDs.contains($0.id) }
            .prefix(limit)
            .map { $0 }
    }

    static func allActive(
        core: CoreMetricsSnapshot,
        signal: SignalMetricsSnapshot,
        bluetoothDevices: [BluetoothDevice]
    ) -> [PulseNotificationSuggestion] {
        PulseIslandCriticalAlert.active(
            core: core,
            signal: signal,
            bluetoothDevices: bluetoothDevices
        )
        .map(PulseNotificationSuggestion.init(alert:))
    }
}

extension PulseIslandCriticalAlert {
    var notificationSuggestionID: String {
        switch self {
        case .power:
            "power"
        case .bluetoothBattery(let alert):
            "bluetoothBattery:\(alert.id)"
        case .thermal:
            "thermal"
        case .disk:
            "disk"
        case .memory:
            "memory"
        }
    }
}
