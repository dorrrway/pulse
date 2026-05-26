import ApplicationServices
import Foundation

@MainActor
protocol ClipboardFocusedPasteCommandPosting: AnyObject {
    func postPasteCommand() -> ClipboardFocusedPasteCommandResult
}

nonisolated enum ClipboardFocusedPasteCommandResult: Equatable, Sendable {
    case posted
    case accessibilityPermissionRequired
}

@MainActor
final class AppKitClipboardFocusedPasteCommandPoster: ClipboardFocusedPasteCommandPosting {
    private static let pasteKeyCode: CGKeyCode = 0x09
    private static let accessibilityPromptOption = "AXTrustedCheckOptionPrompt"

    func postPasteCommand() -> ClipboardFocusedPasteCommandResult {
        guard Self.requestAccessibilityTrust() else {
            return .accessibilityPermissionRequired
        }

        guard
            let source = CGEventSource(stateID: .hidSystemState),
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: Self.pasteKeyCode, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: Self.pasteKeyCode, keyDown: false)
        else {
            return .accessibilityPermissionRequired
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        return .posted
    }

    private static func requestAccessibilityTrust() -> Bool {
        AXIsProcessTrustedWithOptions([accessibilityPromptOption: true] as CFDictionary)
    }
}
