import AppKit
import Carbon
import XCTest
@testable import pulse

final class PulseShortcutRecorderTests: XCTestCase {
    @MainActor
    func testEscapeCancelsRecordingWithoutChangingShortcut() throws {
        let recorder = makeRecorder()
        var receivedShortcut: PulseKeyboardShortcut?
        recorder.onChange = { receivedShortcut = $0 }

        recorder.performClick(nil)
        XCTAssertEqual(recorder.title, "Recording")

        recorder.keyDown(with: try keyEvent(keyCode: UInt16(kVK_Escape), characters: "\u{1b}"))

        XCTAssertNil(receivedShortcut)
        XCTAssertEqual(recorder.title, "Not Set")
    }

    @MainActor
    func testRecordedShortcutUpdatesButtonImmediately() throws {
        let recorder = makeRecorder()
        var receivedShortcut: PulseKeyboardShortcut?
        recorder.onChange = { receivedShortcut = $0 }

        recorder.performClick(nil)
        recorder.keyDown(with: try keyEvent(keyCode: UInt16(kVK_ANSI_A), characters: "a"))

        XCTAssertEqual(receivedShortcut?.displayTitle, "A")
        XCTAssertEqual(recorder.title, "A")
    }

    @MainActor
    private func makeRecorder() -> PulseShortcutRecorderButton {
        let recorder = PulseShortcutRecorderButton(frame: NSRect(x: 0, y: 0, width: 120, height: 28))
        recorder.placeholder = "Not Set"
        recorder.recordingTitle = "Recording"
        return recorder
    }

    private func keyEvent(keyCode: UInt16, characters: String) throws -> NSEvent {
        try XCTUnwrap(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: characters,
                charactersIgnoringModifiers: characters,
                isARepeat: false,
                keyCode: keyCode
            )
        )
    }
}
