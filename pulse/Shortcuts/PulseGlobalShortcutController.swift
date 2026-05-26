import Carbon
import Foundation

final class PulseGlobalShortcutController {
    var actionHandler: ((PulseShortcutAction) -> Void)?

    private var eventHandler: EventHandlerRef?
    private var hotKeys: [PulseShortcutAction: EventHotKeyRef] = [:]
    private var activePreferences = PulseShortcutPreferences()

    private static let eventSignature: OSType = 0x5075_6C53

    init(isEnabled: Bool = true) {
        if isEnabled {
            installEventHandler()
        }
    }

    func configure(preferences: PulseShortcutPreferences) {
        guard preferences != activePreferences else {
            return
        }

        activePreferences = preferences
        unregisterAll()

        for action in PulseShortcutAction.allCases {
            guard let shortcut = preferences.shortcut(for: action) else {
                continue
            }

            register(shortcut, for: action)
        }
    }

    private func installEventHandler() {
        guard eventHandler == nil else {
            return
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        var handler: EventHandlerRef?
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.hotKeyEventHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handler
        )

        if status == noErr {
            eventHandler = handler
        }
    }

    private func register(_ shortcut: PulseKeyboardShortcut, for action: PulseShortcutAction) {
        guard eventHandler != nil else {
            return
        }

        let hotKeyID = EventHotKeyID(
            signature: Self.eventSignature,
            id: action.hotKeyID
        )
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            shortcut.carbonModifierFlags,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr, let hotKeyRef {
            hotKeys[action] = hotKeyRef
        }
    }

    private func unregisterAll() {
        for hotKeyRef in hotKeys.values {
            UnregisterEventHotKey(hotKeyRef)
        }

        hotKeys.removeAll()
    }

    private func handle(action: PulseShortcutAction) {
        DispatchQueue.main.async { [weak self] in
            self?.actionHandler?(action)
        }
    }

    private static let hotKeyEventHandler: EventHandlerUPP = { _, event, userData in
        guard let event, let userData else {
            return OSStatus(eventNotHandledErr)
        }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        guard
            status == noErr,
            hotKeyID.signature == PulseGlobalShortcutController.eventSignature,
            let action = PulseShortcutAction(hotKeyID: hotKeyID.id)
        else {
            return OSStatus(eventNotHandledErr)
        }

        let controller = Unmanaged<PulseGlobalShortcutController>
            .fromOpaque(userData)
            .takeUnretainedValue()
        controller.handle(action: action)
        return noErr
    }
}
