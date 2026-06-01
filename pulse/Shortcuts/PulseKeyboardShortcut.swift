import AppKit
import Carbon
import Foundation

nonisolated enum PulseShortcutAction: String, CaseIterable, Codable, Sendable {
    case wakeClipboard
    case wakeApplications
    case captureFullScreen
    case captureWindow
    case captureSelection
    case recordFullScreen
    case recordWindow
    case recordSelection

    var hotKeyID: UInt32 {
        switch self {
        case .wakeClipboard:
            1
        case .wakeApplications:
            2
        case .captureFullScreen:
            3
        case .captureWindow:
            4
        case .captureSelection:
            5
        case .recordFullScreen:
            6
        case .recordWindow:
            7
        case .recordSelection:
            8
        }
    }

    init?(hotKeyID: UInt32) {
        switch hotKeyID {
        case Self.wakeClipboard.hotKeyID:
            self = .wakeClipboard
        case Self.wakeApplications.hotKeyID:
            self = .wakeApplications
        case Self.captureFullScreen.hotKeyID:
            self = .captureFullScreen
        case Self.captureWindow.hotKeyID:
            self = .captureWindow
        case Self.captureSelection.hotKeyID:
            self = .captureSelection
        case Self.recordFullScreen.hotKeyID:
            self = .recordFullScreen
        case Self.recordWindow.hotKeyID:
            self = .recordWindow
        case Self.recordSelection.hotKeyID:
            self = .recordSelection
        default:
            return nil
        }
    }

    var islandModule: PulseIslandModule? {
        switch self {
        case .wakeClipboard:
            .clipboard
        case .wakeApplications:
            .applications
        case .captureFullScreen, .captureWindow, .captureSelection,
             .recordFullScreen, .recordWindow, .recordSelection:
            nil
        }
    }

    var screenshotMode: PulseScreenshotMode? {
        switch self {
        case .wakeClipboard, .wakeApplications,
             .recordFullScreen, .recordWindow, .recordSelection:
            nil
        case .captureFullScreen:
            .fullScreen
        case .captureWindow:
            .window
        case .captureSelection:
            .selection
        }
    }

    var screenRecordingMode: PulseScreenshotMode? {
        switch self {
        case .wakeClipboard, .wakeApplications,
             .captureFullScreen, .captureWindow, .captureSelection:
            nil
        case .recordFullScreen:
            .fullScreen
        case .recordWindow:
            .window
        case .recordSelection:
            .selection
        }
    }
}

struct PulseShortcutPreferences: Equatable, Sendable {
    var wakeClipboard: PulseKeyboardShortcut?
    var wakeApplications: PulseKeyboardShortcut?
    var captureFullScreen: PulseKeyboardShortcut?
    var captureWindow: PulseKeyboardShortcut?
    var captureSelection: PulseKeyboardShortcut?
    var recordFullScreen: PulseKeyboardShortcut?
    var recordWindow: PulseKeyboardShortcut?
    var recordSelection: PulseKeyboardShortcut?

    init(
        wakeClipboard: PulseKeyboardShortcut? = nil,
        wakeApplications: PulseKeyboardShortcut? = nil,
        captureFullScreen: PulseKeyboardShortcut? = nil,
        captureWindow: PulseKeyboardShortcut? = nil,
        captureSelection: PulseKeyboardShortcut? = nil,
        recordFullScreen: PulseKeyboardShortcut? = nil,
        recordWindow: PulseKeyboardShortcut? = nil,
        recordSelection: PulseKeyboardShortcut? = nil
    ) {
        self.wakeClipboard = wakeClipboard
        self.wakeApplications = wakeApplications
        self.captureFullScreen = captureFullScreen
        self.captureWindow = captureWindow
        self.captureSelection = captureSelection
        self.recordFullScreen = recordFullScreen
        self.recordWindow = recordWindow
        self.recordSelection = recordSelection
    }

    func shortcut(for action: PulseShortcutAction) -> PulseKeyboardShortcut? {
        switch action {
        case .wakeClipboard:
            wakeClipboard
        case .wakeApplications:
            wakeApplications
        case .captureFullScreen:
            captureFullScreen
        case .captureWindow:
            captureWindow
        case .captureSelection:
            captureSelection
        case .recordFullScreen:
            recordFullScreen
        case .recordWindow:
            recordWindow
        case .recordSelection:
            recordSelection
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
        guard let displayKey = Self.displayKey(for: event) else {
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
        case kVK_Escape:
            "Esc"
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
