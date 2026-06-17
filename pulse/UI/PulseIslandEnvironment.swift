import SwiftUI

#if DEBUG
private struct PulseIslandPreviewCriticalAlertsKey: EnvironmentKey {
    static let defaultValue: ([PulseIslandCriticalAlert]) -> Void = { _ in }
}

private struct PulseIslandPreviewNotificationSuggestionsKey: EnvironmentKey {
    static let defaultValue: ([PulseIslandCriticalAlert]) -> Void = { _ in }
}
#endif

extension EnvironmentValues {
    #if DEBUG
    var pulseIslandPreviewCriticalAlerts: ([PulseIslandCriticalAlert]) -> Void {
        get { self[PulseIslandPreviewCriticalAlertsKey.self] }
        set { self[PulseIslandPreviewCriticalAlertsKey.self] = newValue }
    }

    var pulseIslandPreviewNotificationSuggestions: ([PulseIslandCriticalAlert]) -> Void {
        get { self[PulseIslandPreviewNotificationSuggestionsKey.self] }
        set { self[PulseIslandPreviewNotificationSuggestionsKey.self] = newValue }
    }
    #endif
}
