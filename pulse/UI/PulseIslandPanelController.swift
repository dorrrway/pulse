import AppKit
import Observation
import SwiftUI

struct PulseIslandLayoutMetrics: Equatable {
    var seedVisibleHeight: CGFloat
    var notchUnsafeWidth: CGFloat

    static let fallback = PulseIslandLayoutMetrics(
        seedVisibleHeight: PulseIslandLayout.defaultSeedVisibleHeight,
        notchUnsafeWidth: 0
    )
}

enum PulseIslandLayout {
    static let seedVisibleWidth: CGFloat = PulseDesign.Island.seedVisibleWidth
    static let criticalSeedVisibleWidth: CGFloat = PulseDesign.Island.criticalSeedVisibleWidth
    static let notchLaneSafetyInset: CGFloat = PulseDesign.Island.notchLaneSafetyInset
    static let estimatedNotchWidthToHeightRatio: CGFloat = 4.1
    static let minimumEstimatedNotchWidth: CGFloat = 116
    static let maximumEstimatedNotchWidthFraction: CGFloat = 0.14
    static let notchedSeedSideLaneWidth: CGFloat = PulseDesign.Island.notchedSeedSideLaneWidth
    static let notchedSeedContentHorizontalPadding: CGFloat = PulseDesign.Island.notchedSeedContentHorizontalPadding
    static let defaultSeedVisibleHeight: CGFloat = PulseDesign.Island.defaultSeedVisibleHeight
    static let expandedSurfaceHeightMultiplier: CGFloat = PulseDesign.Island.expandedSurfaceHeightMultiplier
    static let expandedSurfaceWidth: CGFloat = PulseDesign.Island.expandedSurfaceWidth
    static let attachedPanelTopGap: CGFloat = PulseDesign.Island.attachedPanelTopGap
    static let screenEdgeInset: CGFloat = PulseDesign.Island.screenEdgeInset
    static let seedSurfaceTopShoulderRadius: CGFloat = PulseDesign.Radius.islandSeedShoulder
    static let expandedSurfaceTopShoulderRadius: CGFloat = PulseDesign.Radius.islandExpandedShoulder
    static let seedSurfaceTopShoulderInset: CGFloat = PulseDesign.Island.seedSurfaceTopShoulderInset
    static let expandedSurfaceTopShoulderInset: CGFloat = PulseDesign.Island.expandedSurfaceTopShoulderInset
    static let seedSurfaceTopShoulderDepth: CGFloat = PulseDesign.Island.seedSurfaceTopShoulderDepth
    static let expandedSurfaceTopShoulderDepth: CGFloat = PulseDesign.Island.expandedSurfaceTopShoulderDepth
    static let seedSurfaceBottomCornerRadius: CGFloat = PulseDesign.Radius.islandSeedBottom
    static let expandedSurfaceBottomCornerRadius: CGFloat = PulseDesign.Radius.islandExpandedBottom
    static let seedContentHorizontalPadding: CGFloat = PulseDesign.Island.seedContentHorizontalPadding
    static let expandedContentHorizontalPadding: CGFloat = PulseDesign.Island.expandedContentHorizontalPadding
    static let seedSurfaceOpacity: Double = PulseDesign.Opacity.islandSeedSurface
    static let expandedSurfaceOpacity: Double = PulseDesign.Opacity.islandExpandedSurface
    static let seedSurfaceShadowOpacity: Double = PulseDesign.Opacity.islandSeedShadow
    static let expandedSurfaceShadowOpacity: Double = PulseDesign.Opacity.islandExpandedShadow
    static let seedSurfaceShadowRadius: CGFloat = PulseDesign.Shadow.islandSeedRadius
    static let expandedSurfaceShadowRadius: CGFloat = PulseDesign.Shadow.islandExpandedRadius

    private static let seedTopAttachmentDepth: CGFloat = PulseDesign.Island.seedTopAttachmentDepth
    private static let expandedTopAttachmentDepth: CGFloat = PulseDesign.Island.expandedTopAttachmentDepth

    static var panelContentSize: CGSize {
        panelContentSize(metrics: .fallback)
    }

    static var seedVisibleSize: CGSize {
        seedVisibleSize(metrics: .fallback)
    }

    static var expandedSurfaceVisibleHeight: CGFloat {
        expandedSurfaceVisibleHeight(metrics: .fallback)
    }

    static var expandedHeaderRowHeight: CGFloat {
        expandedHeaderRowHeight(metrics: .fallback)
    }

    static func expandedSurfaceVisibleHeight(metrics: PulseIslandLayoutMetrics) -> CGFloat {
        expandedHeaderRowHeight(metrics: metrics) * expandedSurfaceHeightMultiplier
    }

    static func expandedHeaderRowHeight(metrics: PulseIslandLayoutMetrics) -> CGFloat {
        metrics.seedVisibleHeight
    }

    static func metrics(for screen: NSScreen?) -> PulseIslandLayoutMetrics {
        PulseIslandLayoutMetrics(
            seedVisibleHeight: topBarHeight(on: screen),
            notchUnsafeWidth: notchUnsafeWidth(on: screen)
        )
    }

    static func topBarHeight(on screen: NSScreen?) -> CGFloat {
        guard let screen else {
            return defaultSeedVisibleHeight
        }

        return topBarHeight(
            screenFrame: screen.frame,
            visibleFrame: screen.visibleFrame,
            safeAreaTop: screen.safeAreaInsets.top
        )
    }

    static func topBarHeight(
        screenFrame: CGRect,
        visibleFrame: CGRect,
        safeAreaTop: CGFloat
    ) -> CGFloat {
        let visibleFrameInset = screenFrame.maxY - visibleFrame.maxY
        let measuredHeight = max(visibleFrameInset, safeAreaTop)
        guard measuredHeight > 0 else {
            return defaultSeedVisibleHeight
        }

        return measuredHeight.rounded(.toNearestOrAwayFromZero)
    }

    static func notchUnsafeWidth(on screen: NSScreen?) -> CGFloat {
        guard let screen else {
            return 0
        }

        return notchUnsafeWidth(
            screenFrame: screen.frame,
            auxiliaryTopLeftArea: screen.auxiliaryTopLeftArea,
            auxiliaryTopRightArea: screen.auxiliaryTopRightArea,
            safeAreaTop: screen.safeAreaInsets.top
        )
    }

    static func notchUnsafeWidth(
        screenFrame: CGRect,
        auxiliaryTopLeftArea: CGRect?,
        auxiliaryTopRightArea: CGRect?,
        safeAreaTop: CGFloat
    ) -> CGFloat {
        if let auxiliaryGapWidth = auxiliaryTopGapWidth(
            leftArea: auxiliaryTopLeftArea,
            rightArea: auxiliaryTopRightArea
        ) {
            return auxiliaryGapWidth
        }

        guard safeAreaTop > 0 else {
            return 0
        }

        return estimatedNotchUnsafeWidth(screenFrame: screenFrame, topAreaHeight: safeAreaTop)
    }

    static func auxiliaryTopGapWidth(
        leftArea: CGRect?,
        rightArea: CGRect?
    ) -> CGFloat? {
        guard
            let leftArea,
            let rightArea,
            !leftArea.isEmpty,
            !rightArea.isEmpty,
            rightArea.minX > leftArea.maxX
        else {
            return nil
        }

        return (rightArea.minX - leftArea.maxX)
            .rounded(.toNearestOrAwayFromZero)
    }

    static func estimatedNotchUnsafeWidth(
        screenFrame: CGRect,
        topAreaHeight: CGFloat
    ) -> CGFloat {
        guard topAreaHeight > 0 else {
            return 0
        }

        let width = max(minimumEstimatedNotchWidth, topAreaHeight * estimatedNotchWidthToHeightRatio)
        return min(width, screenFrame.width * maximumEstimatedNotchWidthFraction)
            .rounded(.toNearestOrAwayFromZero)
    }

    static func panelContentSize(metrics: PulseIslandLayoutMetrics) -> CGSize {
        contentSize(for: .expanded, metrics: metrics)
    }

    static func seedVisibleSize(metrics: PulseIslandLayoutMetrics) -> CGSize {
        seedVisibleSize(for: .seed, metrics: metrics)
    }

    static func seedVisibleSize(
        for style: PulseIslandStyle,
        metrics: PulseIslandLayoutMetrics
    ) -> CGSize {
        switch style {
        case .seed:
            CGSize(width: seedBodyWidth(metrics: metrics), height: metrics.seedVisibleHeight)
        case .criticalSeed:
            CGSize(
                width: criticalSeedBodyWidth(metrics: metrics),
                height: expandedSurfaceVisibleHeight(metrics: metrics)
            )
        case .expanded:
            CGSize(width: expandedSurfaceWidth, height: expandedSurfaceVisibleHeight(metrics: metrics))
        }
    }

    static func chromeSize(for style: PulseIslandStyle, metrics: PulseIslandLayoutMetrics = .fallback) -> CGSize {
        switch style {
        case .seed, .criticalSeed:
            contentSize(for: style, metrics: metrics)
        case .expanded:
            CGSize(
                width: surfaceWidth(for: .expanded),
                height: expandedSurfaceVisibleHeight(metrics: metrics) + topAttachmentDepth(for: .expanded)
            )
        }
    }

    static func contentSize(
        for style: PulseIslandStyle,
        metrics: PulseIslandLayoutMetrics = .fallback
    ) -> CGSize {
        switch style {
        case .seed:
            CGSize(
                width: surfaceWidth(for: style, metrics: metrics),
                height: metrics.seedVisibleHeight + topAttachmentDepth(for: style)
            )
        case .criticalSeed:
            CGSize(
                width: surfaceWidth(for: style, metrics: metrics),
                height: expandedSurfaceVisibleHeight(metrics: metrics) + topAttachmentDepth(for: style)
            )
        case .expanded:
            CGSize(
                width: max(surfaceWidth(for: style, metrics: metrics), attachedPanelSize.width),
                height: visibleHeight(for: style, metrics: metrics) + topAttachmentDepth(for: style)
            )
        }
    }

    static func visibleHeight(
        for style: PulseIslandStyle,
        metrics: PulseIslandLayoutMetrics = .fallback
    ) -> CGFloat {
        switch style {
        case .seed:
            metrics.seedVisibleHeight
        case .criticalSeed:
            expandedSurfaceVisibleHeight(metrics: metrics)
        case .expanded:
            expandedSurfaceVisibleHeight(metrics: metrics) + attachedPanelTopGap + attachedPanelSize.height
        }
    }

    static var attachedPanelSize: CGSize {
        CGSize(
            width: expandedSurfaceWidth,
            height: PulsePanelLayout.contentHeight
        )
    }

    static func topAttachmentDepth(for style: PulseIslandStyle) -> CGFloat {
        switch style {
        case .seed, .criticalSeed:
            seedTopAttachmentDepth
        case .expanded:
            expandedTopAttachmentDepth
        }
    }

    static func surfaceTopShoulderRadius(for style: PulseIslandStyle) -> CGFloat {
        switch style {
        case .seed, .criticalSeed:
            seedSurfaceTopShoulderRadius
        case .expanded:
            expandedSurfaceTopShoulderRadius
        }
    }

    static func surfaceTopShoulderInset(for style: PulseIslandStyle) -> CGFloat {
        switch style {
        case .seed, .criticalSeed:
            seedSurfaceTopShoulderInset
        case .expanded:
            expandedSurfaceTopShoulderInset
        }
    }

    static func surfaceTopShoulderDepth(for style: PulseIslandStyle) -> CGFloat {
        switch style {
        case .seed, .criticalSeed:
            seedSurfaceTopShoulderDepth
        case .expanded:
            expandedSurfaceTopShoulderDepth
        }
    }

    static func surfaceBottomCornerRadius(for style: PulseIslandStyle) -> CGFloat {
        switch style {
        case .seed, .criticalSeed:
            seedSurfaceBottomCornerRadius
        case .expanded:
            expandedSurfaceBottomCornerRadius
        }
    }

    static func surfaceOpacity(for style: PulseIslandStyle) -> Double {
        switch style {
        case .seed, .criticalSeed:
            seedSurfaceOpacity
        case .expanded:
            expandedSurfaceOpacity
        }
    }

    static func surfaceShadowOpacity(for style: PulseIslandStyle) -> Double {
        switch style {
        case .seed, .criticalSeed:
            seedSurfaceShadowOpacity
        case .expanded:
            expandedSurfaceShadowOpacity
        }
    }

    static func surfaceShadowRadius(for style: PulseIslandStyle) -> CGFloat {
        switch style {
        case .seed, .criticalSeed:
            seedSurfaceShadowRadius
        case .expanded:
            expandedSurfaceShadowRadius
        }
    }

    static func surfaceWidth(for style: PulseIslandStyle) -> CGFloat {
        surfaceWidth(for: style, metrics: .fallback)
    }

    static func surfaceWidth(
        for style: PulseIslandStyle,
        metrics: PulseIslandLayoutMetrics
    ) -> CGFloat {
        let bodyWidth: CGFloat
        switch style {
        case .seed:
            bodyWidth = seedBodyWidth(metrics: metrics)
        case .criticalSeed:
            bodyWidth = criticalSeedBodyWidth(metrics: metrics)
        case .expanded:
            bodyWidth = expandedSurfaceWidth
        }

        return bodyWidth + surfaceTopShoulderInset(for: style) * 2
    }

    static func seedBodyWidth(metrics: PulseIslandLayoutMetrics) -> CGFloat {
        guard metrics.notchUnsafeWidth > 0 else {
            return seedVisibleWidth
        }

        return max(
            seedVisibleWidth,
            notchContentGapWidth(metrics: metrics)
                + notchedSeedSideLaneWidth(metrics: metrics) * 2
        )
    }

    static func criticalSeedBodyWidth(metrics: PulseIslandLayoutMetrics) -> CGFloat {
        max(criticalSeedVisibleWidth, seedBodyWidth(metrics: metrics))
    }

    static func notchedSeedSideLaneWidth(metrics: PulseIslandLayoutMetrics) -> CGFloat {
        guard metrics.notchUnsafeWidth > 0 else {
            return 0
        }

        return notchedSeedSideLaneWidth
    }

    static func notchedSeedContentSideLaneWidth(metrics: PulseIslandLayoutMetrics) -> CGFloat {
        max(0, notchedSeedSideLaneWidth(metrics: metrics) - notchedSeedContentHorizontalPadding)
    }

    static func notchContentGapWidth(metrics: PulseIslandLayoutMetrics) -> CGFloat {
        guard metrics.notchUnsafeWidth > 0 else {
            return 0
        }

        return metrics.notchUnsafeWidth + notchLaneSafetyInset * 2
    }

    static func surfaceTopOffset(for style: PulseIslandStyle) -> CGFloat {
        topAttachmentDepth(for: .expanded) - topAttachmentDepth(for: style)
    }

    static func surfaceFrame(
        for style: PulseIslandStyle,
        in bounds: CGRect,
        metrics: PulseIslandLayoutMetrics = .fallback
    ) -> CGRect {
        let size = contentSize(for: style, metrics: metrics)
        let topOffset = surfaceTopOffset(for: style)
        let origin = CGPoint(
            x: bounds.midX - size.width / 2,
            y: bounds.maxY - topOffset - size.height
        )

        return CGRect(origin: origin, size: size)
    }

    static func panelFrame(
        screenFrame: CGRect,
        centerX: CGFloat,
        metrics: PulseIslandLayoutMetrics = .fallback
    ) -> CGRect {
        let size = panelContentSize(metrics: metrics)
        let originX = min(
            max(centerX - size.width / 2, screenFrame.minX + screenEdgeInset),
            screenFrame.maxX - size.width - screenEdgeInset
        )
        let originY = screenFrame.maxY - visibleHeight(for: .expanded, metrics: metrics)

        return CGRect(origin: CGPoint(x: originX, y: originY), size: size)
    }

    static func preferredTopAnchorCenterX(
        screenFrame: CGRect
    ) -> CGFloat {
        screenFrame.midX
    }
}

enum PulseIslandStyle: Equatable {
    case seed
    case criticalSeed
    case expanded
}

@MainActor
@Observable
final class PulseIslandPanelController {
    private(set) var isPresented = false
    private(set) var style: PulseIslandStyle = .seed
    private(set) var layoutMetrics: PulseIslandLayoutMetrics = .fallback
    private(set) var isPinnedPanelPresented = false
    #if DEBUG
    private(set) var criticalAlertPreviewRequest: PulseIslandCriticalAlertPreviewRequest?
    #endif

    @ObservationIgnored private var panel: NSPanel?
    @ObservationIgnored private var anchorScreen: NSScreen?
    @ObservationIgnored private var collapseTask: Task<Void, Never>?
    @ObservationIgnored private var criticalAlertTask: Task<Void, Never>?
    @ObservationIgnored private var pinPanelAction: () -> Void = {}

    private static let hoverCollapseDelay: Duration = .milliseconds(360)
    private static let criticalAlertDuration: Duration = .seconds(3)

    func present(
        store: PulseStore,
        updateController: PulseUpdateController,
        pinAction: (() -> Void)? = nil,
        isPinnedPanelPresented: Bool? = nil
    ) {
        updatePinnedPanelBridge(
            pinAction: pinAction,
            isPinnedPanelPresented: isPinnedPanelPresented
        )
        style = .seed
        criticalAlertTask?.cancel()
        criticalAlertTask = nil
        anchorScreen = currentScreen()
        layoutMetrics = PulseIslandLayout.metrics(for: anchorScreen)

        let panel = panel ?? makePanel(store: store, updateController: updateController)
        self.panel = panel
        installRootView(in: panel, store: store, updateController: updateController)
        panel.setFrame(targetFrame(screen: anchorScreen), display: true)
        panel.orderFrontRegardless()
        isPresented = true
    }

    func setPinnedPanelPresented(_ isPresented: Bool) {
        isPinnedPanelPresented = isPresented
    }

    func dismiss() {
        collapseTask?.cancel()
        collapseTask = nil
        criticalAlertTask?.cancel()
        criticalAlertTask = nil
        panel?.orderOut(nil)
        style = .seed
        isPresented = false
    }

    func setHovering(_ isHovering: Bool) {
        collapseTask?.cancel()
        collapseTask = nil

        if isHovering {
            expand()
        } else {
            collapseTask = Task { @MainActor [weak self] in
                do {
                    try await Task.sleep(for: Self.hoverCollapseDelay)
                } catch {
                    return
                }

                guard !Task.isCancelled else {
                    return
                }

                guard let self, !self.isMouseInsideCurrentContentRect() else {
                    return
                }

                self.collapse()
            }
        }
    }

    func toggleStyle() {
        switch style {
        case .seed, .criticalSeed:
            expand()
        case .expanded:
            collapse()
        }
    }

    func presentCriticalAlert() {
        guard panel != nil, style != .expanded else {
            return
        }

        criticalAlertTask?.cancel()
        setStyle(.criticalSeed)

        criticalAlertTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: Self.criticalAlertDuration)
            } catch {
                return
            }

            guard let self, self.style == .criticalSeed else {
                return
            }

            self.criticalAlertTask = nil
            self.setStyle(.seed)
        }
    }

    func dismissCriticalAlert() {
        criticalAlertTask?.cancel()
        criticalAlertTask = nil

        guard style == .criticalSeed else {
            return
        }

        setStyle(.seed)
    }

    #if DEBUG
    func presentCriticalAlertPreview(_ alerts: [PulseIslandCriticalAlert]) {
        guard !alerts.isEmpty else {
            return
        }

        criticalAlertTask?.cancel()
        criticalAlertTask = nil

        if style != .seed {
            setStyle(.seed)
        }

        criticalAlertPreviewRequest = PulseIslandCriticalAlertPreviewRequest(alerts: alerts)
    }
    #endif

    private func expand() {
        setStyle(.expanded)
    }

    private func collapse() {
        setStyle(.seed)
    }

    private func setStyle(_ newStyle: PulseIslandStyle) {
        guard style != newStyle else {
            return
        }

        style = newStyle
        guard let panel else {
            return
        }

        let screen = panel.screen ?? anchorScreen
        layoutMetrics = PulseIslandLayout.metrics(for: screen)
        panel.setFrame(targetFrame(screen: screen), display: true)
        panel.orderFrontRegardless()
        isPresented = true
    }

    private func makePanel(store: PulseStore, updateController: PulseUpdateController) -> NSPanel {
        let panel = NSPanel(
            contentRect: targetFrame(screen: anchorScreen),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Pulse Island"
        panel.isReleasedWhenClosed = false
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.acceptsMouseMovedEvents = true
        installRootView(in: panel, store: store, updateController: updateController)

        return panel
    }

    private func installRootView(in panel: NSPanel, store: PulseStore, updateController: PulseUpdateController) {
        let rootView = PulseIslandView(
            controller: self,
            updateController: updateController,
            pinAction: { [weak self] in
                self?.pinPanelAction()
            },
            expandAction: { [weak self] in
                self?.expand()
            },
            collapseAction: { [weak self] in
                self?.collapse()
            }
        )
        .environment(store)

        let hostingView = PulseIslandHostingView(rootView: rootView)
        hostingView.islandController = self
        hostingView.frame = NSRect(origin: .zero, size: panel.frame.size)
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView
    }

    private func updatePinnedPanelBridge(
        pinAction: (() -> Void)?,
        isPinnedPanelPresented: Bool?
    ) {
        if let pinAction {
            pinPanelAction = pinAction
        }

        if let isPinnedPanelPresented {
            self.isPinnedPanelPresented = isPinnedPanelPresented
        }
    }

    func contentRect(in bounds: CGRect) -> CGRect? {
        guard isPresented || panel == nil else {
            return nil
        }

        return PulseIslandLayout.surfaceFrame(for: style, in: bounds, metrics: layoutMetrics)
    }

    private func isMouseInsideCurrentContentRect() -> Bool {
        guard
            let panel,
            let contentView = panel.contentView,
            let contentRect = contentRect(in: contentView.bounds)
        else {
            return false
        }

        let windowPoint = panel.convertPoint(fromScreen: NSEvent.mouseLocation)
        let viewPoint = contentView.convert(windowPoint, from: nil)
        return contentRect.contains(viewPoint)
    }

    private func targetFrame(screen: NSScreen?) -> CGRect {
        let fallbackSize = PulseIslandLayout.panelContentSize(metrics: layoutMetrics)
        let screenFrame = (screen ?? NSScreen.main)?.frame ?? CGRect(origin: .zero, size: fallbackSize)
        let centerX = PulseIslandLayout.preferredTopAnchorCenterX(
            screenFrame: screenFrame
        )
        return PulseIslandLayout.panelFrame(screenFrame: screenFrame, centerX: centerX, metrics: layoutMetrics)
    }

    private func currentScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        let mouseScreen = NSScreen.screens.first { screen in
            screen.frame.contains(mouseLocation)
        }

        if let mouseScreen, Self.isNotchedScreen(mouseScreen) {
            return mouseScreen
        }

        return NSScreen.screens.first(where: Self.isNotchedScreen) ?? mouseScreen ?? NSScreen.main
    }

    private static func isNotchedScreen(_ screen: NSScreen) -> Bool {
        screen.safeAreaInsets.top > 0
            || screen.auxiliaryTopLeftArea?.isEmpty == false
            || screen.auxiliaryTopRightArea?.isEmpty == false
    }

}

@MainActor
private final class PulseIslandHostingView<Content: View>: NSHostingView<Content> {
    weak var islandController: PulseIslandPanelController?

    required init(rootView: Content) {
        super.init(rootView: rootView)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard
            let contentRect = islandController?.contentRect(in: bounds),
            contentRect.contains(point)
        else {
            return nil
        }

        return super.hitTest(point) ?? self
    }
}
