import AppKit
import Carbon
import SwiftUI

struct PulseShortcutRecorder: NSViewRepresentable {
    var shortcut: PulseKeyboardShortcut?
    var placeholder: String
    var recordingTitle: String
    var isEnabled = true
    var onChange: (PulseKeyboardShortcut?) -> Void

    func makeNSView(context: Context) -> PulseShortcutRecorderButton {
        let button = PulseShortcutRecorderButton()
        button.shortcut = shortcut
        button.placeholder = placeholder
        button.recordingTitle = recordingTitle
        button.isEnabled = isEnabled
        button.onChange = onChange
        return button
    }

    func updateNSView(_ button: PulseShortcutRecorderButton, context: Context) {
        button.shortcut = shortcut
        button.placeholder = placeholder
        button.recordingTitle = recordingTitle
        button.isEnabled = isEnabled
        button.onChange = onChange
    }
}

final class PulseShortcutRecorderButton: NSButton {
    var shortcut: PulseKeyboardShortcut? {
        didSet {
            updateTitle()
        }
    }
    var placeholder = "" {
        didSet {
            updateTitle()
        }
    }
    var recordingTitle = "" {
        didSet {
            updateTitle()
        }
    }
    var onChange: ((PulseKeyboardShortcut?) -> Void)?

    private var isRecording = false

    override var acceptsFirstResponder: Bool {
        true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setButtonType(.momentaryPushIn)
        bezelStyle = .rounded
        controlSize = .small
        font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        alignment = .center
        target = self
        action = #selector(beginRecording)
        focusRingType = .default
        updateTitle()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        updateTitle()
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        if event.keyCode == UInt16(kVK_Escape) {
            endRecording()
            return
        }

        guard let shortcut = PulseKeyboardShortcut(event: event) else {
            NSSound.beep()
            return
        }

        self.shortcut = shortcut
        onChange?(shortcut)
        endRecording()
    }

    @objc private func beginRecording() {
        isRecording = true
        updateTitle()
        window?.makeKey()
        window?.makeFirstResponder(self)
    }

    private func endRecording() {
        isRecording = false
        window?.makeFirstResponder(nil)
        updateTitle()
    }

    private func updateTitle() {
        if isRecording {
            title = recordingTitle
        } else {
            title = shortcut?.displayTitle ?? placeholder
        }
    }
}
