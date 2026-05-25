import AppKit
import Observation
import SwiftUI

enum PulsePanelLayout {
    static let contentWidth: CGFloat = PulseDesign.Panel.contentWidth
    static let outerPadding: CGFloat = PulseDesign.Panel.outerPadding
    static let sectionSpacing: CGFloat = PulseDesign.Panel.sectionSpacing
    static let metricRowHeight: CGFloat = PulseDesign.Panel.metricRowHeight
    static let metricRowSpacing: CGFloat = PulseDesign.Panel.metricRowSpacing
    static let coreMetricsHeight = metricRowHeight * 4 + metricRowSpacing * 3
    static let processSectionHeight: CGFloat = PulseDesign.Panel.processSectionHeight
    static let processSectionSpacing: CGFloat = PulseDesign.Panel.processSectionSpacing
    static let processLeadersHeight = processSectionHeight * 2 + processSectionSpacing
    static let signalCardHeight: CGFloat = PulseDesign.Panel.signalCardHeight
    static let runtimeRowHeight: CGFloat = PulseDesign.Panel.runtimeRowHeight
    static let signalSpacing: CGFloat = PulseDesign.Panel.signalSpacing
    static let signalGridHeight = signalCardHeight * 2 + runtimeRowHeight + signalSpacing * 2
    static let footerHeight: CGFloat = PulseDesign.Panel.footerHeight
    static let footerTopSpacing: CGFloat = PulseDesign.Panel.footerTopSpacing
    static let footerBottomPadding: CGFloat = PulseDesign.Panel.footerBottomPadding
    static let panelCornerRadius: CGFloat = PulseDesign.Radius.panel
    static let dragRegionHeight: CGFloat = PulseDesign.Panel.dragRegionHeight
    static let contentHeight = outerPadding
        + footerBottomPadding
        + coreMetricsHeight
        + processLeadersHeight
        + signalGridHeight
        + footerHeight
        + sectionSpacing * 2
        + footerTopSpacing
    static let contentSize = CGSize(width: contentWidth, height: contentHeight)

    static let minimalMetricGraphWidth: CGFloat = PulseDesign.Panel.minimalMetricGraphWidth
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

    @ObservationIgnored var presentationDidChange: ((Bool) -> Void)?
    @ObservationIgnored private var panel: NSPanel?
    @ObservationIgnored private var anchorScreen: NSScreen?
    @ObservationIgnored private var screenTrackingTask: Task<Void, Never>?
    @ObservationIgnored private var style: PulsePanelStyle = .full

    private static let screenTrackingInterval: Duration = .milliseconds(350)

    func toggle(store: PulseStore, updateController: PulseUpdateController) {
        if isPresented {
            dismiss()
        } else {
            present(store: store, updateController: updateController)
        }
    }

    func present(store: PulseStore, updateController: PulseUpdateController) {
        style = .full
        anchorScreen = currentScreen()

        let panel = panel ?? makePanel(store: store, updateController: updateController)
        self.panel = panel
        configure(panel, for: style)
        installRootView(in: panel, store: store, updateController: updateController)

        if panel.frame.isEmpty || !PulseDisplaySelection.isSameScreen(panel.screen, anchorScreen) {
            panel.setFrame(defaultFrame(for: style, screen: anchorScreen), display: false)
        } else {
            resize(panel, to: style, screen: anchorScreen, animated: false)
        }

        panel.orderFrontRegardless()
        updatePresentationState(true)
        startScreenTracking()
    }

    func dismiss() {
        screenTrackingTask?.cancel()
        screenTrackingTask = nil
        panel?.orderOut(nil)
        style = .full
        updatePresentationState(false)
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

        anchorScreen = panel.screen ?? anchorScreen ?? currentScreen()
        configure(panel, for: newStyle)
        installRootView(in: panel, store: store, updateController: updateController)
        resize(panel, to: newStyle, screen: anchorScreen, animated: true)
        panel.orderFrontRegardless()
        updatePresentationState(true)
    }

    private func updatePresentationState(_ newValue: Bool) {
        guard isPresented != newValue else {
            return
        }

        isPresented = newValue
        presentationDidChange?(newValue)
    }

    private func makePanel(store: PulseStore, updateController: PulseUpdateController) -> NSPanel {
        let panel = NSPanel(
            contentRect: defaultFrame(for: style, screen: anchorScreen),
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

    private func resize(_ panel: NSPanel, to style: PulsePanelStyle, screen: NSScreen?, animated: Bool) {
        let frame = frame(
            preservingTopLeftOf: panel.frame,
            size: PulsePanelLayout.contentSize(for: style),
            screen: screen
        )
        panel.setFrame(frame, display: true, animate: animated)
    }

    private func defaultFrame(for style: PulsePanelStyle, screen: NSScreen? = nil) -> CGRect {
        let contentSize = PulsePanelLayout.contentSize(for: style)
        let visibleFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .init(origin: .zero, size: contentSize)
        let origin = CGPoint(
            x: visibleFrame.midX - contentSize.width / 2,
            y: visibleFrame.midY - contentSize.height / 2
        )

        return CGRect(origin: origin, size: contentSize)
    }

    private func frame(preservingTopLeftOf currentFrame: CGRect, size: CGSize, screen: NSScreen?) -> CGRect {
        guard !currentFrame.isEmpty else {
            return defaultFrame(for: style, screen: screen)
        }

        let visibleFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .init(origin: .zero, size: size)
        let proposedOrigin = CGPoint(
            x: currentFrame.minX,
            y: currentFrame.maxY - size.height
        )

        return CGRect(origin: clampedOrigin(proposedOrigin, size: size, visibleFrame: visibleFrame), size: size)
    }

    private func startScreenTracking() {
        guard screenTrackingTask == nil else {
            return
        }

        screenTrackingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: Self.screenTrackingInterval)
                } catch {
                    return
                }

                guard !Task.isCancelled else {
                    return
                }

                self?.syncToCurrentScreenIfNeeded()
            }
        }
    }

    private func syncToCurrentScreenIfNeeded() {
        guard isPresented, let panel else {
            return
        }

        let screen = currentScreen()
        guard !PulseDisplaySelection.isSameScreen(screen, anchorScreen) else {
            return
        }

        let frame = frame(
            preservingRelativePositionOf: panel.frame,
            size: PulsePanelLayout.contentSize(for: style),
            from: panel.screen ?? anchorScreen,
            to: screen
        )
        anchorScreen = screen
        panel.setFrame(frame, display: true)
    }

    private func frame(
        preservingRelativePositionOf currentFrame: CGRect,
        size: CGSize,
        from currentScreen: NSScreen?,
        to targetScreen: NSScreen?
    ) -> CGRect {
        guard !currentFrame.isEmpty else {
            return defaultFrame(for: style, screen: targetScreen)
        }

        let currentVisibleFrame = currentScreen?.visibleFrame
            ?? anchorScreen?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? .init(origin: .zero, size: size)
        let targetVisibleFrame = targetScreen?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? .init(origin: .zero, size: size)
        let xRatio = relativePosition(
            value: currentFrame.minX,
            lowerBound: currentVisibleFrame.minX,
            availableDistance: currentVisibleFrame.width - currentFrame.width
        )
        let yRatio = relativePosition(
            value: currentFrame.minY,
            lowerBound: currentVisibleFrame.minY,
            availableDistance: currentVisibleFrame.height - currentFrame.height
        )
        let proposedOrigin = CGPoint(
            x: targetVisibleFrame.minX + (targetVisibleFrame.width - size.width) * xRatio,
            y: targetVisibleFrame.minY + (targetVisibleFrame.height - size.height) * yRatio
        )

        return CGRect(origin: clampedOrigin(proposedOrigin, size: size, visibleFrame: targetVisibleFrame), size: size)
    }

    private func relativePosition(value: CGFloat, lowerBound: CGFloat, availableDistance: CGFloat) -> CGFloat {
        guard availableDistance > 0 else {
            return 0.5
        }

        return min(max((value - lowerBound) / availableDistance, 0), 1)
    }

    private func clampedOrigin(_ origin: CGPoint, size: CGSize, visibleFrame: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(origin.x, visibleFrame.minX), visibleFrame.maxX - size.width),
            y: min(max(origin.y, visibleFrame.minY), visibleFrame.maxY - size.height)
        )
    }

    private func currentScreen() -> NSScreen? {
        let screens = NSScreen.screens
        if let screenIndex = PulseDisplaySelection.screenIndex(
            containing: NSEvent.mouseLocation,
            in: screens.map(\.frame)
        ) {
            return screens[screenIndex]
        }

        return panel?.screen ?? anchorScreen ?? NSScreen.main
    }
}
