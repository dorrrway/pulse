import AppKit
import Observation
import SwiftUI

enum PulsePanelLayout {
    static let contentWidth: CGFloat = 420
    static let outerPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 10
    static let headerHeight: CGFloat = 36
    static let metricRowHeight: CGFloat = 36
    static let metricRowSpacing: CGFloat = 10
    static let coreMetricsHeight = metricRowHeight * 4 + metricRowSpacing * 3
    static let processSectionHeight: CGFloat = 82
    static let processSectionSpacing: CGFloat = 12
    static let processLeadersHeight = processSectionHeight * 2 + processSectionSpacing
    static let signalCardHeight: CGFloat = 68
    static let pressureRowHeight: CGFloat = 34
    static let signalSpacing: CGFloat = 8
    static let signalGridHeight = signalCardHeight * 2 + pressureRowHeight + signalSpacing * 2
    static let footerHeight: CGFloat = 36
    static let panelCornerRadius: CGFloat = 16
    static let dragRegionHeight: CGFloat = 86
    static let contentHeight = outerPadding * 2
        + headerHeight
        + coreMetricsHeight
        + processLeadersHeight
        + signalGridHeight
        + footerHeight
        + sectionSpacing * 4
    static let contentSize = CGSize(width: contentWidth, height: contentHeight)
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
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Pulse"
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.contentMinSize = PulsePanelLayout.contentSize
        panel.contentMaxSize = PulsePanelLayout.contentSize

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
        let contentSize = PulsePanelLayout.contentSize
        let visibleFrame = NSScreen.main?.visibleFrame ?? .init(origin: .zero, size: contentSize)
        let origin = CGPoint(
            x: visibleFrame.midX - contentSize.width / 2,
            y: visibleFrame.midY - contentSize.height / 2
        )

        return CGRect(origin: origin, size: contentSize)
    }
}
