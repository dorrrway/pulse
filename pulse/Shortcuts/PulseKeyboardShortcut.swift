import AppKit
import Carbon
import Foundation

enum PulseShortcutAction: String, CaseIterable, Codable, Sendable {
    case wakeClipboard
    case wakeApplications

    var hotKeyID: UInt32 {
        switch self {
        case .wakeClipboard:
            1
        case .wakeApplications:
            2
        }
    }

    init?(hotKeyID: UInt32) {
        switch hotKeyID {
        case Self.wakeClipboard.hotKeyID:
            self = .wakeClipboard
        case Self.wakeApplications.hotKeyID:
            self = .wakeApplications
        default:
            return nil
        }
    }

    var islandModule: PulseIslandModule {
        switch self {
        case .wakeClipboard:
            .clipboard
        case .wakeApplications:
            .applications
        }
    }
}

struct PulseShortcutPreferences: Equatable, Sendable {
    var wakeClipboard: PulseKeyboardShortcut?
    var wakeApplications: PulseKeyboardShortcut?

    init(
        wakeClipboard: PulseKeyboardShortcut? = nil,
        wakeApplications: PulseKeyboardShortcut? = nil
    ) {
        self.wakeClipboard = wakeClipboard
        self.wakeApplications = wakeApplications
    }

    func shortcut(for action: PulseShortcutAction) -> PulseKeyboardShortcut? {
        switch action {
        case .wakeClipboard:
            wakeClipboard
        case .wakeApplications:
            wakeApplications
        }
    }
}

struct PulseKeyboardShortcut: Codable, Equatable, Hashable, Sendable {
    var keyCode: UInt16
    var modifierFlagsRawValue: UInt
    var keyEquivalent: String

    init(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags, keyEquivalent: String) {
        self.keyCode = keyCode
        self.modifierFlagsRawValue = Self.normalizedModifierFlags(modifierFlags).rawValue
        self.keyEquivalent = Self.normalizedKeyEquivalent(keyEquivalent)
    }

    init?(event: NSEvent) {
        let modifierFlags = Self.normalizedModifierFlags(event.modifierFlags)
        guard !modifierFlags.isEmpty, let displayKey = Self.displayKey(for: event) else {
            return nil
        }

        self.init(
            keyCode: UInt16(event.keyCode),
            modifierFlags: modifierFlags,
            keyEquivalent: displayKey
        )
    }

    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierFlagsRawValue)
    }

    var carbonModifierFlags: UInt32 {
        var modifiers: UInt32 = 0
        let flags = modifierFlags

        if flags.contains(.command) {
            modifiers |= UInt32(cmdKey)
        }
        if flags.contains(.option) {
            modifiers |= UInt32(optionKey)
        }
        if flags.contains(.control) {
            modifiers |= UInt32(controlKey)
        }
        if flags.contains(.shift) {
            modifiers |= UInt32(shiftKey)
        }

        return modifiers
    }

    var displayTitle: String {
        modifierDisplayTitle + keyEquivalent
    }

    private var modifierDisplayTitle: String {
        var parts: [String] = []
        let flags = modifierFlags

        if flags.contains(.control) {
            parts.append("⌃")
        }
        if flags.contains(.option) {
            parts.append("⌥")
        }
        if flags.contains(.shift) {
            parts.append("⇧")
        }
        if flags.contains(.command) {
            parts.append("⌘")
        }

        return parts.joined()
    }

    private static func normalizedModifierFlags(_ flags: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
        flags.intersection([.control, .option, .shift, .command])
    }

    private static func normalizedKeyEquivalent(_ keyEquivalent: String) -> String {
        if keyEquivalent.count == 1 {
            return keyEquivalent.uppercased()
        }

        return keyEquivalent
    }

    private static func displayKey(for event: NSEvent) -> String? {
        if let mappedKey = displayKey(forKeyCode: UInt16(event.keyCode)) {
            return mappedKey
        }

        guard let characters = event.charactersIgnoringModifiers, !characters.isEmpty else {
            return nil
        }

        if characters == " " {
            return "Space"
        }

        return normalizedKeyEquivalent(characters)
    }

    private static func displayKey(forKeyCode keyCode: UInt16) -> String? {
        switch Int(keyCode) {
        case kVK_Space:
            "Space"
        case kVK_Return:
            "Return"
        case kVK_Tab:
            "Tab"
        case kVK_Delete:
            "Delete"
        case kVK_ForwardDelete:
            "Forward Delete"
        case kVK_LeftArrow:
            "←"
        case kVK_RightArrow:
            "→"
        case kVK_UpArrow:
            "↑"
        case kVK_DownArrow:
            "↓"
        case kVK_F1:
            "F1"
        case kVK_F2:
            "F2"
        case kVK_F3:
            "F3"
        case kVK_F4:
            "F4"
        case kVK_F5:
            "F5"
        case kVK_F6:
            "F6"
        case kVK_F7:
            "F7"
        case kVK_F8:
            "F8"
        case kVK_F9:
            "F9"
        case kVK_F10:
            "F10"
        case kVK_F11:
            "F11"
        case kVK_F12:
            "F12"
        case kVK_F13:
            "F13"
        case kVK_F14:
            "F14"
        case kVK_F15:
            "F15"
        case kVK_F16:
            "F16"
        case kVK_F17:
            "F17"
        case kVK_F18:
            "F18"
        case kVK_F19:
            "F19"
        case kVK_F20:
            "F20"
        default:
            nil
        }
    }
}
