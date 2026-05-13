import AppKit
import Observation
import SwiftUI

enum PulsePanelLayout {
    static let contentWidth: CGFloat = 420
    static let outerPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 16
    static let headerHeight: CGFloat = 36
    static let metricRowHeight: CGFloat = 36
    static let metricRowSpacing: CGFloat = 10
    static let coreMetricsHeight = metricRowHeight * 4 + metricRowSpacing * 3
    static let processSectionHeight: CGFloat = 82
    static let processSectionSpacing: CGFloat = 12
    static let processLeadersHeight = processSectionHeight * 2 + processSectionSpacing
    static let signalCardHeight: CGFloat = 68
    static let signalSpacing: CGFloat = 8
    static let signalGridHeight = signalCardHeight * 2 + signalSpacing
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

    static let minimalMetricGraphWidth: CGFloat = 106
    static let minimalContentWidth = minimalMetricGraphWidth + outerPadding * 2
    static let minimalContentHeight = coreMetricsHeight + outerPadding * 2
    static let minimalContentSize = CGSize(width: minimalContentWidth, height: minimalContentHeight)

    static func contentSize(for style: PulsePanelStyle) -> CGSize {
        switch style {
        case .full:
            contentSize
        case .minimal:
            minimalContentSize
        }
    }
}

enum PulsePanelStyle {
    case full
    case minimal
}

@MainActor
@Observable
final class PulsePinnedPanelController {
    private(set) var isPresented = false

    @ObservationIgnored private var panel: NSPanel?
    @ObservationIgnored private var style: PulsePanelStyle = .full

    func toggle(store: PulseStore, updateController: PulseUpdateController) {
        if isPresented {
            dismiss()
        } else {
            present(store: store, updateController: updateController)
        }
    }

    func present(store: PulseStore, updateController: PulseUpdateController) {
        style = .full

        let panel = panel ?? makePanel(store: store, updateController: updateController)
        self.panel = panel
        configure(panel, for: style)
        installRootView(in: panel, store: store, updateController: updateController)

        if panel.frame.isEmpty {
            panel.setFrame(defaultFrame(for: style), display: false)
        } else {
            resize(panel, to: style, animated: false)
        }

        panel.orderFrontRegardless()
        isPresented = true
    }

    func dismiss() {
        panel?.orderOut(nil)
        style = .full
        isPresented = false
    }

    private func collapse(store: PulseStore, updateController: PulseUpdateController) {
        setStyle(.minimal, store: store, updateController: updateController)
    }

    private func expand(store: PulseStore, updateController: PulseUpdateController) {
        setStyle(.full, store: store, updateController: updateController)
    }

    private func setStyle(_ newStyle: PulsePanelStyle, store: PulseStore, updateController: PulseUpdateController) {
        style = newStyle

        guard let panel else {
            return
        }

        configure(panel, for: newStyle)
        installRootView(in: panel, store: store, updateController: updateController)
        resize(panel, to: newStyle, animated: true)
        panel.orderFrontRegardless()
        isPresented = true
    }

    private func makePanel(store: PulseStore, updateController: PulseUpdateController) -> NSPanel {
        let panel = NSPanel(
            contentRect: defaultFrame(for: style),
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
        configure(panel, for: style)
        installRootView(in: panel, store: store, updateController: updateController)

        return panel
    }

    private func installRootView(in panel: NSPanel, store: PulseStore, updateController: PulseUpdateController) {
        let rootView = PulsePanelView(
            style: style,
            collapseAction: { [weak self] in
                self?.collapse(store: store, updateController: updateController)
            },
            expandAction: { [weak self] in
                self?.expand(store: store, updateController: updateController)
            }
        )
            .environment(store)
            .environment(updateController)
            .environment(\.pulsePanelPresentation, .pinned)
            .environment(\.pulsePanelIsPinned, true)
            .environment(\.pulsePanelPinAction) { [weak self] in
                self?.dismiss()
            }
            .pulsePreferredAppearance(store)

        panel.contentViewController = NSHostingController(rootView: rootView)
    }

    private func configure(_ panel: NSPanel, for style: PulsePanelStyle) {
        let contentSize = PulsePanelLayout.contentSize(for: style)
        panel.contentMinSize = contentSize
        panel.contentMaxSize = contentSize
        panel.hasShadow = style == .full
        panel.invalidateShadow()
    }

    private func resize(_ panel: NSPanel, to style: PulsePanelStyle, animated: Bool) {
        let frame = frame(
            preservingTopLeftOf: panel.frame,
            size: PulsePanelLayout.contentSize(for: style),
            screen: panel.screen
        )
        panel.setFrame(frame, display: true, animate: animated)
    }

    private func defaultFrame(for style: PulsePanelStyle) -> CGRect {
        let contentSize = PulsePanelLayout.contentSize(for: style)
        let visibleFrame = NSScreen.main?.visibleFrame ?? .init(origin: .zero, size: contentSize)
        let origin = CGPoint(
            x: visibleFrame.midX - contentSize.width / 2,
            y: visibleFrame.midY - contentSize.height / 2
        )

        return CGRect(origin: origin, size: contentSize)
    }

    private func frame(preservingTopLeftOf currentFrame: CGRect, size: CGSize, screen: NSScreen?) -> CGRect {
        guard !currentFrame.isEmpty else {
            return defaultFrame(for: style)
        }

        let visibleFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .init(origin: .zero, size: size)
        let proposedOrigin = CGPoint(
            x: currentFrame.minX,
            y: currentFrame.maxY - size.height
        )
        let clampedOrigin = CGPoint(
            x: min(max(proposedOrigin.x, visibleFrame.minX), visibleFrame.maxX - size.width),
            y: min(max(proposedOrigin.y, visibleFrame.minY), visibleFrame.maxY - size.height)
        )

        return CGRect(origin: clampedOrigin, size: size)
    }
}
