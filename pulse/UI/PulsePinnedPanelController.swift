import AppKit
import Observation
import SwiftUI

enum PulsePanelLayout {
    static let width: CGFloat = 420
    static let height: CGFloat = 680
    static let size = CGSize(width: width, height: height)
}

@MainActor
@Observable
final class PulsePinnedPanelController {
    private(set) var isPresented = false

    @ObservationIgnored private var panel: NSPanel?

    func toggle(store: PulseStore) {
        if isPresented {
            dismiss()
        } else {
            present(store: store)
        }
    }

    func present(store: PulseStore) {
        let panel = panel ?? makePanel(store: store)
        self.panel = panel

        if panel.frame.isEmpty {
            panel.setFrame(defaultFrame(), display: false)
        }

        panel.orderFrontRegardless()
        isPresented = true
    }

    func dismiss() {
        panel?.orderOut(nil)
        isPresented = false
    }

    private func makePanel(store: PulseStore) -> NSPanel {
        let panel = NSPanel(
            contentRect: defaultFrame(),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Pulse"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.minSize = PulsePanelLayout.size
        panel.maxSize = PulsePanelLayout.size

        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        let rootView = PulsePanelView()
            .environment(store)
            .environment(\.pulsePanelPresentation, .pinned)
            .environment(\.pulsePanelIsPinned, true)
            .environment(\.pulsePanelPinAction) { [weak self] in
                self?.dismiss()
            }

        panel.contentViewController = NSHostingController(rootView: rootView)
        return panel
    }

    private func defaultFrame() -> CGRect {
        let visibleFrame = NSScreen.main?.visibleFrame ?? .init(origin: .zero, size: PulsePanelLayout.size)
        let origin = CGPoint(
            x: visibleFrame.midX - PulsePanelLayout.width / 2,
            y: visibleFrame.midY - PulsePanelLayout.height / 2
        )

        return CGRect(origin: origin, size: PulsePanelLayout.size)
    }
}
