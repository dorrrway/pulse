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
    static let expandedHeaderExtraHeight: CGFloat = PulseDesign.Island.expandedHeaderExtraHeight
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

    static var expandedHeaderContentHeight: CGFloat {
        expandedHeaderContentHeight(metrics: .fallback)
    }

    static var expandedHeaderRowHeight: CGFloat {
        expandedHeaderRowHeight(metrics: .fallback)
    }

    static func expandedHeaderContentHeight(metrics: PulseIslandLayoutMetrics) -> CGFloat {
        expandedHeaderRowHeight(metrics: metrics) * expandedSurfaceHeightMultiplier
    }

    static func expandedSurfaceVisibleHeight(metrics: PulseIslandLayoutMetrics) -> CGFloat {
        expandedHeaderContentHeight(metrics: metrics) + expandedHeaderExtraHeight
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
                height: expandedHeaderContentHeight(metrics: metrics)
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
                height: expandedHeaderContentHeight(metrics: metrics) + topAttachmentDepth(for: style)
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
            expandedHeaderContentHeight(metrics: metrics)
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

enum PulseDisplaySelection {
    static func screenIndex(containing point: CGPoint, in screenFrames: [CGRect]) -> Int? {
        screenFrames.firstIndex { frame in
            frame.contains(point)
        }
    }

    static func isSameScreen(_ lhs: NSScreen?, _ rhs: NSScreen?) -> Bool {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            lhs.frame == rhs.frame
                && lhs.visibleFrame == rhs.visibleFrame
        case (nil, nil):
            true
        case (.some, .none), (.none, .some):
            false
        }
    }
}

@MainActor
@Observable
final class PulseIslandPanelController {
    private(set) var isPresented = false
    private(set) var style: PulseIslandStyle = .seed
    private(set) var layoutMetrics: PulseIslandLayoutMetrics = .fallback
    private(set) var isPinnedPanelPresented = false
    private(set) var selectedModule: PulseIslandModule = .applications
    #if DEBUG
    private(set) var criticalAlertPreviewRequest: PulseIslandCriticalAlertPreviewRequest?
    #endif

    @ObservationIgnored private var panel: NSPanel?
    @ObservationIgnored private var anchorScreen: NSScreen?
    @ObservationIgnored private var collapseTask: Task<Void, Never>?
    @ObservationIgnored private var criticalAlertTask: Task<Void, Never>?
    @ObservationIgnored private var screenTrackingTask: Task<Void, Never>?
    @ObservationIgnored private var pinPanelAction: () -> Void = {}

    private static let hoverCollapseDelay: Duration = .milliseconds(360)
    private static let criticalAlertDuration: Duration = .seconds(3)
    private static let screenTrackingInterval: Duration = .milliseconds(350)

    static func shouldDeferHoverCollapse(pressedMouseButtons: Int) -> Bool {
        pressedMouseButtons != 0
    }

    func present(
        store: PulseStore,
        updateController: PulseUpdateController,
        pinAction: (() -> Void)? = nil,
        isPinnedPanelPresented: Bool? = nil
    ) {
        presentPanel(
            store: store,
            updateController: updateController,
            pinAction: pinAction,
            isPinnedPanelPresented: isPinnedPanelPresented,
            resetToSeed: true
        )
    }

    func wake(
        module: PulseIslandModule,
        store: PulseStore,
        updateController: PulseUpdateController,
        pinAction: (() -> Void)? = nil,
        isPinnedPanelPresented: Bool? = nil
    ) {
        selectModule(module)
        presentPanel(
            store: store,
            updateController: updateController,
            pinAction: pinAction,
            isPinnedPanelPresented: isPinnedPanelPresented,
            resetToSeed: !isPresented
        )
        expand()
    }

    func setPinnedPanelPresented(_ isPresented: Bool) {
        isPinnedPanelPresented = isPresented
    }

    func selectModule(_ module: PulseIslandModule) {
        selectedModule = module
    }

    func dismiss() {
        collapseTask?.cancel()
        collapseTask = nil
        criticalAlertTask?.cancel()
        criticalAlertTask = nil
        screenTrackingTask?.cancel()
        screenTrackingTask = nil
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
            scheduleHoverCollapse()
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

    private func presentPanel(
        store: PulseStore,
        updateController: PulseUpdateController,
        pinAction: (() -> Void)?,
        isPinnedPanelPresented: Bool?,
        resetToSeed: Bool
    ) {
        updatePinnedPanelBridge(
            pinAction: pinAction,
            isPinnedPanelPresented: isPinnedPanelPresented
        )

        if resetToSeed {
            style = .seed
        }
        criticalAlertTask?.cancel()
        criticalAlertTask = nil
        anchorScreen = currentScreen()
        layoutMetrics = PulseIslandLayout.metrics(for: anchorScreen)

        let panel: NSPanel
        if let existingPanel = self.panel {
            panel = existingPanel
        } else {
            panel = makePanel()
            self.panel = panel
            installRootView(in: panel, store: store, updateController: updateController)
        }

        panel.setFrame(targetFrame(screen: anchorScreen), display: true)
        panel.orderFrontRegardless()
        isPresented = true
        startScreenTracking()
    }

    private func scheduleHoverCollapse() {
        collapseTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: Self.hoverCollapseDelay)
            } catch {
                return
            }

            guard !Task.isCancelled else {
                return
            }

            self?.performHoverCollapseIfReady()
        }
    }

    private func performHoverCollapseIfReady() {
        guard !Self.shouldDeferHoverCollapse(pressedMouseButtons: NSEvent.pressedMouseButtons) else {
            scheduleHoverCollapse()
            return
        }

        collapseTask = nil

        guard !isMouseInsideCurrentContentRect() else {
            return
        }

        collapse()
    }

    private func setStyle(_ newStyle: PulseIslandStyle) {
        guard style != newStyle else {
            return
        }

        style = newStyle
        guard let panel else {
            return
        }

        let screen = screen(for: newStyle)
        anchorScreen = screen
        layoutMetrics = PulseIslandLayout.metrics(for: screen)
        panel.setFrame(targetFrame(screen: screen), display: true)
        panel.orderFrontRegardless()
        isPresented = true
    }

    private func makePanel() -> NSPanel {
        let panel = PulseIslandPanel(
            contentRect: targetFrame(screen: anchorScreen),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Pulse Dynamic Island-style entry"
        panel.isReleasedWhenClosed = false
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.acceptsMouseMovedEvents = true

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

        let hostingView = PulseIslandHostingView(rootView: AnyView(rootView))
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
        guard isPresented, style == .seed, let panel else {
            return
        }

        let screen = currentScreen()
        let metrics = PulseIslandLayout.metrics(for: screen)
        guard !PulseDisplaySelection.isSameScreen(screen, anchorScreen) || metrics != layoutMetrics else {
            return
        }

        anchorScreen = screen
        layoutMetrics = metrics
        panel.setFrame(targetFrame(screen: screen), display: true)
    }

    private func screen(for style: PulseIslandStyle) -> NSScreen? {
        switch style {
        case .seed, .criticalSeed:
            currentScreen()
        case .expanded:
            panel?.screen ?? anchorScreen ?? currentScreen()
        }
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

private final class PulseIslandPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }
}

@MainActor
private final class PulseIslandHostingView: NSHostingView<AnyView> {
    weak var islandController: PulseIslandPanelController?

    required init(rootView: AnyView) {
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
