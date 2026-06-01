import AppKit
import AVKit

@MainActor
final class PulseScreenRecordingPreviewPanelController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private var player: AVPlayer?

    func show(recording: PulseScreenRecordingPreview, title: String) {
        close()

        let player = AVPlayer(url: recording.url)
        let playerView = AVPlayerView(frame: NSRect(origin: .zero, size: Self.preferredContentSize()))
        playerView.player = player
        playerView.controlsStyle = .floating

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: playerView.frame.size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = title
        panel.contentView = playerView
        panel.delegate = self
        panel.isReleasedWhenClosed = false
        panel.center()

        self.player = player
        self.panel = panel

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        player.play()
    }

    func close() {
        player?.pause()
        player = nil

        panel?.delegate = nil
        panel?.close()
        panel = nil
    }

    func windowWillClose(_ notification: Notification) {
        player?.pause()
        player = nil
        panel = nil
    }

    private static func preferredContentSize() -> CGSize {
        let fallback = CGSize(width: 760, height: 460)
        guard let visibleFrame = NSScreen.main?.visibleFrame else {
            return fallback
        }

        return CGSize(
            width: min(fallback.width, visibleFrame.width * 0.82),
            height: min(fallback.height, visibleFrame.height * 0.72)
        )
    }
}
