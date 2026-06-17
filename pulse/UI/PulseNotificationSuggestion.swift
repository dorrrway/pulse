import Foundation

struct PulseNotificationSuggestion: Equatable, Identifiable, Sendable {
    var alert: PulseIslandCriticalAlert
    #if DEBUG
    var isPreview: Bool
    #endif

    init(alert: PulseIslandCriticalAlert, isPreview: Bool = false) {
        self.alert = alert
        #if DEBUG
        self.isPreview = isPreview
        #endif
    }

    var id: String {
        #if DEBUG
        if isPreview {
            return "preview:\(alert.notificationSuggestionID)"
        }
        #endif

        return alert.notificationSuggestionID
    }

    static func active(
        core: CoreMetricsSnapshot,
        signal: SignalMetricsSnapshot,
        bluetoothDevices: [BluetoothDevice],
        isEnabled: Bool,
        dismissedIDs: Set<String>,
        limit: Int? = nil
    ) -> [PulseNotificationSuggestion] {
        guard isEnabled else {
            return []
        }

        let suggestions = allActive(core: core, signal: signal, bluetoothDevices: bluetoothDevices)
            .filter { !dismissedIDs.contains($0.id) }

        guard let limit else {
            return suggestions
        }

        guard limit > 0 else {
            return []
        }

        return Array(suggestions.prefix(limit))
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
        .map { PulseNotificationSuggestion(alert: $0) }
    }

    static func resolvedSelectionID(
        _ selectedID: String?,
        in suggestions: [PulseNotificationSuggestion]
    ) -> String? {
        guard let fallbackID = suggestions.first?.id else {
            return nil
        }

        guard
            let selectedID,
            suggestions.contains(where: { $0.id == selectedID })
        else {
            return fallbackID
        }

        return selectedID
    }

    static func selected(
        in suggestions: [PulseNotificationSuggestion],
        selectedID: String?
    ) -> PulseNotificationSuggestion? {
        guard let selectedID = resolvedSelectionID(selectedID, in: suggestions) else {
            return nil
        }

        return suggestions.first { $0.id == selectedID }
    }

    static func secondarySuggestions(
        in suggestions: [PulseNotificationSuggestion],
        selectedID: String?
    ) -> [PulseNotificationSuggestion] {
        guard let selectedID = resolvedSelectionID(selectedID, in: suggestions) else {
            return []
        }

        return suggestions.filter { $0.id != selectedID }
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
