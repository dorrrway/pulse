import AppKit
import SwiftUI

private let islandOpenAnimation = Animation.spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0)
private let islandCloseAnimation = Animation.smooth(duration: 0.30)
private let attachedPanelRevealAnimation = Animation.smooth(duration: 0.26)
private let attachedPanelConcealAnimation = Animation.smooth(duration: 0.16)
private let expandedHeaderRevealAnimation = Animation.easeOut(duration: 0.16)
private let expandedHeaderConcealAnimation = Animation.easeOut(duration: 0.10)
private let expandedSurfaceUnmountDelay: TimeInterval = 0.36
private let expandedHeaderRevealDelay: TimeInterval = 0.12
private let attachedPanelRevealDelay: TimeInterval = 0.18
private let attachedPanelHiddenYOffset: CGFloat = -8
private let moduleSwitchDragThreshold: CGFloat = 18
private let moduleSwitchScrollThreshold: CGFloat = 12
private let moduleSwitchAnimation = Animation.smooth(duration: 0.22)
private let moduleSwitchInputLockDuration: TimeInterval = 0.24
private let seedMetricRollAnimation = Animation.spring(response: 0.50, dampingFraction: 0.86, blendDuration: 0)
private let seedMetricFadeAnimation = Animation.easeInOut(duration: 0.16)
private let criticalSeedAnimation = Animation.spring(response: 0.42, dampingFraction: 0.84, blendDuration: 0)

struct PulseIslandView: View {
    var controller: PulseIslandPanelController
    var updateController: PulseUpdateController
    var pinAction: () -> Void
    var expandAction: () -> Void
    var collapseAction: () -> Void

    @Environment(\.openSettings) private var openSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(PulseStore.self) private var store
    @State private var keepsExpandedSurfaceMounted = false
    @State private var expandedSurfaceMountGeneration = 0
    @State private var isExpandedHeaderRevealed = false
    @State private var isAttachedPanelRevealed = false
    @State private var selectedModule: PulseIslandModule = .resourceMonitor
    @State private var moduleSwitchDirection = 1
    @State private var isModuleSwitchLocked = false
    @State private var moduleSwitchLockGeneration = 0
    @State private var selectedSeedMetric: PulseIslandSeedMetric = .memory
    @State private var activeCriticalAlert: PulseIslandCriticalAlert?
    @State private var acknowledgedCriticalAlerts: Set<PulseIslandCriticalAlert> = []
    #if DEBUG
    @State private var activePreviewCriticalAlerts: [PulseIslandCriticalAlert] = []
    @State private var acknowledgedPreviewCriticalAlerts: Set<PulseIslandCriticalAlert> = []
    @State private var handledPreviewCriticalAlertRequestID: UUID?
    #endif

    private var style: PulseIslandStyle {
        controller.style
    }

    private var layoutMetrics: PulseIslandLayoutMetrics {
        controller.layoutMetrics
    }

    private var usesExpandedVisualState: Bool {
        style == .expanded
    }

    private var usesCriticalSeedState: Bool {
        style == .criticalSeed
    }

    private var shouldRenderExpandedSurface: Bool {
        usesExpandedVisualState || keepsExpandedSurfaceMounted
    }

    private var transitionAnimation: Animation {
        switch style {
        case .expanded:
            islandOpenAnimation
        case .criticalSeed:
            criticalSeedAnimation
        case .seed:
            islandCloseAnimation
        }
    }

    var body: some View {
        let strings = store.strings
        let criticalAlerts = PulseIslandCriticalAlert.active(core: store.coreMetrics, signal: store.signalMetrics)
        let rotationMetrics = PulseIslandSeedMetric.rotationMetrics(for: store.signalMetrics.power)
        let activeSeedMetric = selectedSeedMetric.normalized(in: rotationMetrics)
        let activity = activeCriticalAlert.map { visibleCriticalActivity(alert: $0, strings: strings) }
            ?? seedActivity(metric: activeSeedMetric, strings: strings)

        ZStack(alignment: .top) {
            morphingIslandChrome()

            if shouldRenderExpandedSurface {
                surfaceLayer(for: .expanded) {
                    expandedIsland(strings: strings)
                }
                .opacity(usesExpandedVisualState ? 1 : 0)
                .scaleEffect(usesExpandedVisualState ? 1 : 0.88, anchor: .top)
                .allowsHitTesting(usesExpandedVisualState)
            }

            surfaceLayer(for: .seed) {
                seedSurface(activity: activity)
            }
            .opacity(usesExpandedVisualState ? 0 : 1)
            .scaleEffect(usesExpandedVisualState ? 0.82 : 1, anchor: .top)
            .allowsHitTesting(!usesExpandedVisualState)
        }
        .frame(
            width: PulseIslandLayout.panelContentSize(metrics: layoutMetrics).width,
            height: PulseIslandLayout.panelContentSize(metrics: layoutMetrics).height,
            alignment: .top
        )
        .foregroundStyle(.white)
        .animation(transitionAnimation, value: style)
        .onAppear {
            syncExpandedSurfaceMount(with: style, immediate: true)
            #if DEBUG
            handleCriticalAlertPreviewRequest(controller.criticalAlertPreviewRequest)
            #endif
            reconcileVisibleCriticalAlerts(criticalAlerts)
        }
        .onChange(of: style) { _, newStyle in
            syncExpandedSurfaceMount(with: newStyle)
            if newStyle == .seed {
                activeCriticalAlert = nil
            }
            reconcileVisibleCriticalAlerts(criticalAlerts)
        }
        .onChange(of: criticalAlerts) { _, alerts in
            reconcileVisibleCriticalAlerts(alerts)
        }
        #if DEBUG
        .onChange(of: controller.criticalAlertPreviewRequest) { _, request in
            handleCriticalAlertPreviewRequest(request)
        }
        #endif
        .task {
            await rotateSeedMetric()
        }
        .contextMenu {
            Button(strings.text(.settings)) {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openSettings()
            }
            Button(strings.text(.quit)) {
                NSApplication.shared.terminate(nil)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(strings.text(.topIsland))
    }

    private func morphingIslandChrome() -> some View {
        let chromeSize = PulseIslandLayout.chromeSize(for: style, metrics: layoutMetrics)
        let topShoulderRadius = PulseIslandLayout.surfaceTopShoulderRadius(for: style)
        let topShoulderInset = PulseIslandLayout.surfaceTopShoulderInset(for: style)
        let topShoulderDepth = PulseIslandLayout.surfaceTopShoulderDepth(for: style)
        let bottomCornerRadius = PulseIslandLayout.surfaceBottomCornerRadius(for: style)
        let opacity = PulseIslandLayout.surfaceOpacity(for: style)
        let shadowOpacity = PulseIslandLayout.surfaceShadowOpacity(for: style)
        let shadowRadius = PulseIslandLayout.surfaceShadowRadius(for: style)

        return VStack(spacing: 0) {
            Color.clear
                .frame(height: PulseIslandLayout.surfaceTopOffset(for: style))

            islandSurfaceBackground(
                topShoulderRadius: topShoulderRadius,
                topShoulderInset: topShoulderInset,
                topShoulderDepth: topShoulderDepth,
                bottomCornerRadius: bottomCornerRadius,
                opacity: opacity,
                shadowOpacity: shadowOpacity,
                shadowRadius: shadowRadius
            )
                .frame(width: chromeSize.width, height: chromeSize.height)

            Spacer(minLength: 0)
        }
        .frame(
            width: PulseIslandLayout.panelContentSize(metrics: layoutMetrics).width,
            height: PulseIslandLayout.panelContentSize(metrics: layoutMetrics).height,
            alignment: .top
        )
        .allowsHitTesting(false)
    }

    private func surfaceLayer<Surface: View>(
        for style: PulseIslandStyle,
        @ViewBuilder surface: () -> Surface
    ) -> some View {
        return VStack(spacing: 0) {
            Color.clear
                .frame(height: PulseIslandLayout.surfaceTopOffset(for: style))

            surface()

            Spacer(minLength: 0)
        }
        .frame(
            width: PulseIslandLayout.panelContentSize(metrics: layoutMetrics).width,
            height: PulseIslandLayout.panelContentSize(metrics: layoutMetrics).height,
            alignment: .top
        )
    }

    private func syncExpandedSurfaceMount(with style: PulseIslandStyle, immediate: Bool = false) {
        expandedSurfaceMountGeneration &+= 1
        let generation = expandedSurfaceMountGeneration

        switch style {
        case .expanded:
            keepsExpandedSurfaceMounted = true
            isExpandedHeaderRevealed = immediate
            isAttachedPanelRevealed = false

            if !immediate {
                DispatchQueue.main.asyncAfter(deadline: .now() + expandedHeaderRevealDelay) {
                    guard expandedSurfaceMountGeneration == generation, self.style == .expanded else {
                        return
                    }

                    withAnimation(expandedHeaderRevealAnimation) {
                        isExpandedHeaderRevealed = true
                    }
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + attachedPanelRevealDelay) {
                guard expandedSurfaceMountGeneration == generation, self.style == .expanded else {
                    return
                }

                withAnimation(attachedPanelRevealAnimation) {
                    isAttachedPanelRevealed = true
                }
            }
        case .seed, .criticalSeed:
            withAnimation(expandedHeaderConcealAnimation) {
                isExpandedHeaderRevealed = false
            }

            withAnimation(attachedPanelConcealAnimation) {
                isAttachedPanelRevealed = false
            }

            guard !immediate else {
                keepsExpandedSurfaceMounted = false
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + expandedSurfaceUnmountDelay) {
                guard expandedSurfaceMountGeneration == generation, self.style != .expanded else {
                    return
                }

                keepsExpandedSurfaceMounted = false
            }
        }
    }

    private func seedSurface(activity: IslandActivity) -> some View {
        let seedStyle: PulseIslandStyle = usesCriticalSeedState ? .criticalSeed : .seed
        let visibleSize = PulseIslandLayout.seedVisibleSize(for: seedStyle, metrics: layoutMetrics)
        let contentSize = PulseIslandLayout.contentSize(for: seedStyle, metrics: layoutMetrics)

        return VStack(spacing: 0) {
            Color.clear
                .frame(height: PulseIslandLayout.topAttachmentDepth(for: seedStyle))

            seedContent(activity: activity)
                .frame(
                    width: visibleSize.width,
                    height: visibleSize.height
                )
        }
        .frame(
            width: contentSize.width,
            height: contentSize.height
        )
        .clipShape(surfaceShape(for: seedStyle))
        .contentShape(surfaceShape(for: seedStyle))
        .onHover { hovering in
            controller.setHovering(hovering)
        }
        .onTapGesture(perform: expandAction)
    }

    private func seedContent(activity: IslandActivity) -> some View {
        if usesCriticalSeedState {
            return AnyView(criticalSeedContent(activity: activity))
        }

        let notchGapWidth = PulseIslandLayout.notchContentGapWidth(metrics: layoutMetrics)

        if notchGapWidth > 0 {
            return AnyView(notchAwareSeedContent(activity: activity, notchGapWidth: notchGapWidth))
        }

        return AnyView(standardSeedContent(activity: activity))
    }

    private func standardSeedContent(activity: IslandActivity) -> some View {
        let rowHeight = PulseIslandLayout.seedVisibleSize(for: .seed, metrics: layoutMetrics).height

        return HStack(spacing: 9) {
            rollingSeedMetricIcon(
                activity: activity,
                width: PulseDesign.Control.symbolSize,
                rowHeight: rowHeight
            )

            ZStack {
                HStack(spacing: 9) {
                    IslandPulseDots(tint: activity.tint, progress: activity.progress)

                    Spacer(minLength: 0)

                    seedValueText(activity.value, font: PulseDesign.Typography.islandSeed)
                }
                .frame(height: rowHeight)
                .id(activity.transitionIdentity)
                .transition(seedMetricTransition)
            }
            .frame(maxWidth: .infinity, maxHeight: rowHeight)
            .clipped()
        }
        .frame(height: rowHeight)
        .padding(.horizontal, PulseIslandLayout.seedContentHorizontalPadding)
    }

    private func notchAwareSeedContent(activity: IslandActivity, notchGapWidth: CGFloat) -> some View {
        let sideLaneWidth = PulseIslandLayout.notchedSeedContentSideLaneWidth(metrics: layoutMetrics)
        let rowHeight = PulseIslandLayout.seedVisibleSize(for: .seed, metrics: layoutMetrics).height

        return HStack(spacing: 0) {
            ZStack(alignment: .leading) {
                rollingSeedMetricIcon(
                    activity: activity,
                    width: sideLaneWidth,
                    rowHeight: rowHeight,
                    alignment: .leading
                )
            }
            .frame(width: sideLaneWidth, height: rowHeight, alignment: .leading)
            .clipped()

            Color.clear
                .frame(width: notchGapWidth)

            ZStack(alignment: .trailing) {
                seedValueText(activity.value, font: PulseDesign.Typography.islandNotchedSeed)
                    .frame(width: sideLaneWidth, height: rowHeight, alignment: .trailing)
                    .id(activity.transitionIdentity)
                    .transition(seedMetricTransition)
            }
            .frame(width: sideLaneWidth, height: rowHeight, alignment: .trailing)
            .clipped()
        }
        .frame(height: rowHeight)
        .padding(.horizontal, PulseIslandLayout.notchedSeedContentHorizontalPadding)
    }

    private func seedMetricIcon(activity: IslandActivity) -> some View {
        Image(activity.iconAssetName ?? "PulseStatusIcon")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(
                width: PulseDesign.Control.symbolSize,
                height: PulseDesign.Control.symbolSize
            )
            .foregroundStyle(activity.tint.opacity(0.96))
            .accessibilityLabel(activity.title)
            .help(activity.title)
    }

    private func rollingSeedMetricIcon(
        activity: IslandActivity,
        width: CGFloat,
        rowHeight: CGFloat,
        alignment: Alignment = .center
    ) -> some View {
        ZStack(alignment: alignment) {
            seedMetricIcon(activity: activity)
                .frame(width: width, height: rowHeight, alignment: alignment)
                .id(activity.transitionIdentity)
                .transition(seedMetricTransition)
        }
        .frame(
            width: width,
            height: rowHeight,
            alignment: alignment
        )
        .clipped()
    }

    private func criticalSeedContent(activity: IslandActivity) -> some View {
        let rowHeight = PulseIslandLayout.expandedHeaderRowHeight(metrics: layoutMetrics)

        return VStack(spacing: 0) {
            HStack(alignment: .center, spacing: PulseDesign.Spacing.sm) {
                HStack(alignment: .center, spacing: PulseDesign.Spacing.xs) {
                    criticalAlertIcon(activity: activity)

                    Text(activity.title)
                        .font(PulseDesign.Typography.islandNotchedSeed)
                        .foregroundStyle(activity.tint.opacity(0.98))
                        .lineLimit(1)
                }

                Spacer(minLength: PulseDesign.Spacing.sm)

                seedValueText(activity.value, font: PulseDesign.Typography.islandNotchedSeed)
            }
            .frame(height: rowHeight, alignment: .center)

            Text(activity.detail ?? "")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity, maxHeight: rowHeight, alignment: .center)
                .accessibilityHidden(activity.detail == nil)
        }
        .padding(.horizontal, PulseDesign.Spacing.md)
    }

    private func criticalAlertIcon(activity: IslandActivity) -> some View {
        Group {
            if let iconAssetName = activity.iconAssetName {
                Image(iconAssetName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: PulseDesign.Control.symbolSize,
                        height: PulseDesign.Control.symbolSize
                    )
                    .foregroundStyle(activity.tint.opacity(0.98))
                    .accessibilityHidden(true)
            }
        }
    }

    private func expandedIsland(strings: PulseStrings) -> some View {
        VStack(spacing: PulseIslandLayout.attachedPanelTopGap) {
            expandedSurface(strings: strings)

            attachedPanel()
        }
        .onHover { hovering in
            controller.setHovering(hovering)
        }
    }

    private func attachedPanel() -> some View {
        ZStack {
            Group {
                switch selectedModule {
                case .resourceMonitor:
                    PulsePanelView(style: .full, collapseAction: collapseAction, expandAction: expandAction)
                        .environment(store)
                        .environment(updateController)
                        .environment(\.pulsePanelPresentation, .island)
                        .environment(\.pulsePanelIsPinned, controller.isPinnedPanelPresented)
                        .environment(\.pulsePanelPinAction, pinAction)
                case .applications:
                    InstalledAppsPanelView()
                        .environment(store)
                }
            }
            .id(selectedModule)
            .frame(
                width: PulseIslandLayout.attachedPanelSize.width,
                height: PulseIslandLayout.attachedPanelSize.height
            )
            .transition(attachedPanelModuleTransition)
        }
            .frame(
                width: PulseIslandLayout.attachedPanelSize.width,
                height: PulseIslandLayout.attachedPanelSize.height
            )
            .background {
                attachedPanelBackground()
            }
            .mask {
                attachedPanelMask()
            }
            .animation(moduleSwitchAnimation, value: selectedModule)
            .offset(y: isAttachedPanelRevealed ? 0 : attachedPanelHiddenYOffset)
            .opacity(isAttachedPanelRevealed ? 1 : 0)
            .frame(
                width: PulseIslandLayout.attachedPanelSize.width,
                height: isAttachedPanelRevealed ? PulseIslandLayout.attachedPanelSize.height : 0,
                alignment: .top
            )
            .clipped()
            .allowsHitTesting(isAttachedPanelRevealed)
            .accessibilityHidden(!isAttachedPanelRevealed)
    }

    @ViewBuilder
    private func attachedPanelBackground() -> some View {
        let fill = Color.black.opacity(PulseIslandLayout.surfaceOpacity(for: .expanded))

        switch selectedModule {
        case .resourceMonitor:
            RoundedRectangle(cornerRadius: PulsePanelLayout.panelCornerRadius, style: .continuous)
                .fill(fill)
        case .applications:
            installedAppsAttachedPanelShape
                .fill(fill, style: FillStyle(eoFill: true))
        }
    }

    @ViewBuilder
    private func attachedPanelMask() -> some View {
        switch selectedModule {
        case .resourceMonitor:
            RoundedRectangle(cornerRadius: PulsePanelLayout.panelCornerRadius, style: .continuous)
                .fill(.black)
        case .applications:
            installedAppsAttachedPanelShape
                .fill(.black, style: FillStyle(eoFill: true))
        }
    }

    private var installedAppsAttachedPanelShape: InstalledAppsAttachedPanelShape {
        InstalledAppsAttachedPanelShape(
            cornerRadius: PulsePanelLayout.panelCornerRadius,
            separatorCenterY: InstalledAppsPanelLayout.sectionGapCenterY,
            separatorHeight: InstalledAppsPanelLayout.separatorCutoutHeight
        )
    }

    private var attachedPanelModuleTransition: AnyTransition {
        let insertionEdge: Edge = moduleSwitchDirection > 0 ? .bottom : .top
        let removalEdge: Edge = moduleSwitchDirection > 0 ? .top : .bottom

        return .asymmetric(
            insertion: .opacity.combined(with: .move(edge: insertionEdge)),
            removal: .opacity.combined(with: .move(edge: removalEdge))
        )
    }

    private func expandedSurface(strings: PulseStrings) -> some View {
        let surfaceVisibleHeight = PulseIslandLayout.expandedSurfaceVisibleHeight(metrics: layoutMetrics)
        let headerContentHeight = PulseIslandLayout.expandedHeaderContentHeight(metrics: layoutMetrics)
        let headerRowHeight = PulseIslandLayout.expandedHeaderRowHeight(metrics: layoutMetrics)

        return VStack(spacing: 0) {
            Color.clear
                .frame(height: PulseIslandLayout.topAttachmentDepth(for: .expanded))

            IslandModuleHeader(
                module: selectedModule,
                title: strings.text(selectedModule.titleKey),
                deviceName: store.deviceName ?? strings.text(.thisMac),
                rowHeight: headerRowHeight,
                settingsTitle: strings.text(.settings),
                settingsHelp: strings.text(.settingsHelp),
                settingsAction: {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    openSettings()
                },
                quitTitle: strings.text(.quit),
                quitHelp: strings.text(.quitHelp),
                quitAction: {
                    NSApplication.shared.terminate(nil)
                }
            )
            .opacity(isExpandedHeaderRevealed ? 1 : 0)
            .allowsHitTesting(isExpandedHeaderRevealed)
            .accessibilityHidden(!isExpandedHeaderRevealed)
            .padding(.horizontal, PulseIslandLayout.expandedContentHorizontalPadding)
            .frame(
                width: PulseIslandLayout.expandedSurfaceWidth,
                height: headerContentHeight,
                alignment: .top
            )
            .overlay(alignment: .bottom) {
                IslandModuleInteractionBridge(
                    switchAction: { switchModule(by: $0) }
                )
                .frame(height: headerRowHeight)
            }

            Color.clear
                .frame(height: PulseIslandLayout.expandedHeaderExtraHeight)
        }
        .frame(
            width: PulseIslandLayout.surfaceWidth(for: .expanded),
            height: surfaceVisibleHeight + PulseIslandLayout.topAttachmentDepth(for: .expanded),
            alignment: .top
        )
        .clipShape(surfaceShape(for: .expanded))
        .contentShape(surfaceShape(for: .expanded))
        .help(strings.text(.switchIslandModule))
        .animation(.smooth(duration: 0.18), value: selectedModule)
    }

    private func switchModule(by offset: Int) {
        let nextModule = selectedModule.shifted(by: offset)
        guard !isModuleSwitchLocked, nextModule != selectedModule else {
            return
        }

        isModuleSwitchLocked = true
        moduleSwitchLockGeneration &+= 1
        let lockGeneration = moduleSwitchLockGeneration
        moduleSwitchDirection = offset >= 0 ? 1 : -1

        withAnimation(moduleSwitchAnimation) {
            selectedModule = nextModule
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + moduleSwitchInputLockDuration) {
            guard moduleSwitchLockGeneration == lockGeneration else {
                return
            }

            isModuleSwitchLocked = false
        }
    }

    private func reconcileVisibleCriticalAlerts(_ activeAlerts: [PulseIslandCriticalAlert]) {
        #if DEBUG
        if !activePreviewCriticalAlerts.isEmpty {
            reconcilePreviewCriticalAlerts()
            return
        }
        #endif

        reconcileCriticalAlerts(activeAlerts)
    }

    private func reconcileCriticalAlerts(_ activeAlerts: [PulseIslandCriticalAlert]) {
        let activeAlertSet = Set(activeAlerts)
        acknowledgedCriticalAlerts.formIntersection(activeAlertSet)

        if let activeCriticalAlert, !activeAlertSet.contains(activeCriticalAlert) {
            self.activeCriticalAlert = nil
            controller.dismissCriticalAlert()
        }

        guard activeCriticalAlert == nil, style == .seed else {
            return
        }

        guard let nextAlert = activeAlerts.first(where: { !acknowledgedCriticalAlerts.contains($0) }) else {
            return
        }

        activeCriticalAlert = nextAlert
        acknowledgedCriticalAlerts.insert(nextAlert)

        if nextAlert == .power {
            selectedSeedMetric = .power
        }

        controller.presentCriticalAlert()
    }

    #if DEBUG
    private func handleCriticalAlertPreviewRequest(_ request: PulseIslandCriticalAlertPreviewRequest?) {
        guard let request, handledPreviewCriticalAlertRequestID != request.id else {
            return
        }

        handledPreviewCriticalAlertRequestID = request.id
        activePreviewCriticalAlerts = request.alerts
        acknowledgedPreviewCriticalAlerts = []
        activeCriticalAlert = nil
        controller.dismissCriticalAlert()
        reconcilePreviewCriticalAlerts()
    }

    private func reconcilePreviewCriticalAlerts() {
        guard activeCriticalAlert == nil, style == .seed else {
            return
        }

        guard let nextAlert = activePreviewCriticalAlerts.first(where: { !acknowledgedPreviewCriticalAlerts.contains($0) }) else {
            activePreviewCriticalAlerts = []
            acknowledgedPreviewCriticalAlerts = []
            return
        }

        activeCriticalAlert = nextAlert
        acknowledgedPreviewCriticalAlerts.insert(nextAlert)

        if nextAlert == .power {
            selectedSeedMetric = .power
        }

        controller.presentCriticalAlert()
    }
    #endif

    private func rotateSeedMetric() async {
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .milliseconds(Int(PulseIslandSeedMetric.rotationInterval * 1_000)))
            } catch {
                return
            }

            withAnimation(seedMetricAnimation) {
                let rotationMetrics = PulseIslandSeedMetric.rotationMetrics(for: store.signalMetrics.power)
                selectedSeedMetric = selectedSeedMetric.next(in: rotationMetrics)
            }
        }
    }

    private var seedMetricAnimation: Animation {
        reduceMotion ? seedMetricFadeAnimation : seedMetricRollAnimation
    }

    private var seedMetricTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }

        return .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        )
    }

    private func seedValueText(_ value: String, font: Font) -> some View {
        Text(value)
            .font(font)
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.92))
            .lineLimit(1)
            .minimumScaleFactor(0.74)
            .contentTransition(.numericText())
    }

    private func seedActivity(metric: PulseIslandSeedMetric, strings: PulseStrings) -> IslandActivity {
        let metrics = store.coreMetrics

        switch metric {
        case .memory:
            return IslandActivity(
                metric: metric,
                title: strings.text(.memory),
                value: ResourceFormatters.percentage(metrics.memory.percentage),
                iconAssetName: metric.compactIconAssetName(power: store.signalMetrics.power),
                tint: .green,
                progress: metrics.memory.percentage
            )
        case .cpu:
            return IslandActivity(
                metric: metric,
                title: strings.text(.cpu),
                value: ResourceFormatters.percentage(metrics.cpu.percentage),
                iconAssetName: metric.compactIconAssetName(power: store.signalMetrics.power),
                tint: .cyan,
                progress: metrics.cpu.percentage
            )
        case .power:
            let power = store.signalMetrics.power
            let percentage = power.batteryPercentage ?? 0

            return IslandActivity(
                metric: metric,
                title: strings.islandBatteryLevelTitle(),
                value: power.batteryPercentage.map(ResourceFormatters.percentage) ?? strings.text(.battery),
                iconAssetName: metric.compactIconAssetName(power: power),
                tint: SignalStatusColor.power(power),
                progress: percentage,
                detail: strings.criticalPowerIslandDetail(power)
            )
        }
    }

    private func visibleCriticalActivity(alert: PulseIslandCriticalAlert, strings: PulseStrings) -> IslandActivity {
        #if DEBUG
        if !activePreviewCriticalAlerts.isEmpty {
            return previewCriticalActivity(alert: alert, strings: strings)
        }
        #endif

        return criticalActivity(alert: alert, strings: strings)
    }

    private func criticalActivity(alert: PulseIslandCriticalAlert, strings: PulseStrings) -> IslandActivity {
        let coreMetrics = store.coreMetrics
        let signalMetrics = store.signalMetrics

        switch alert {
        case .power:
            let power = signalMetrics.power
            let percentage = power.batteryPercentage ?? 0

            return IslandActivity(
                metric: .power,
                identity: alert,
                title: strings.islandBatteryLevelTitle(),
                value: power.batteryPercentage.map(ResourceFormatters.percentage) ?? strings.text(.battery),
                iconAssetName: alert.iconAssetName(power: power),
                tint: SignalStatusColor.power(power),
                progress: percentage,
                detail: strings.criticalPowerIslandDetail(power)
            )
        case .thermal:
            let thermal = signalMetrics.thermal

            return IslandActivity(
                metric: .cpu,
                identity: alert,
                title: strings.text(.thermal),
                value: strings.thermal(thermal.condition),
                iconAssetName: alert.iconAssetName(power: signalMetrics.power),
                tint: SignalStatusColor.thermal(thermal.condition),
                progress: 1,
                detail: strings.criticalThermalIslandDetail(thermal)
            )
        case .disk:
            let disk = coreMetrics.disk

            return IslandActivity(
                metric: .memory,
                identity: alert,
                title: strings.text(.disk),
                value: ResourceFormatters.percentage(disk.percentage),
                iconAssetName: alert.iconAssetName(power: signalMetrics.power),
                tint: .orange,
                progress: disk.percentage,
                detail: strings.criticalDiskIslandDetail(disk)
            )
        case .memory:
            let memory = signalMetrics.memory

            return IslandActivity(
                metric: .memory,
                identity: alert,
                title: strings.text(.memory),
                value: strings.pressure(memory.pressureLevel),
                iconAssetName: alert.iconAssetName(power: signalMetrics.power),
                tint: SignalStatusColor.memoryPressure(memory.pressureLevel),
                progress: memory.percentage,
                detail: strings.criticalMemoryIslandDetail(memory)
            )
        }
    }

    #if DEBUG
    private func previewCriticalActivity(alert: PulseIslandCriticalAlert, strings: PulseStrings) -> IslandActivity {
        switch alert {
        case .power:
            let power = PowerUsage(
                hasBattery: true,
                batteryPercentage: 0.09,
                isPluggedIn: false,
                isCharging: false,
                timeRemaining: 1_080
            )

            return IslandActivity(
                metric: .power,
                identity: alert,
                title: strings.islandBatteryLevelTitle(),
                value: power.batteryPercentage.map(ResourceFormatters.percentage) ?? strings.text(.battery),
                iconAssetName: alert.iconAssetName(power: power),
                tint: SignalStatusColor.power(power),
                progress: power.batteryPercentage ?? 0,
                detail: strings.criticalPowerIslandDetail(power)
            )
        case .thermal:
            let thermal = ThermalUsage(condition: .critical, stateDuration: 45)

            return IslandActivity(
                metric: .cpu,
                identity: alert,
                title: strings.text(.thermal),
                value: strings.thermal(thermal.condition),
                iconAssetName: alert.iconAssetName(power: .empty),
                tint: SignalStatusColor.thermal(thermal.condition),
                progress: 1,
                detail: strings.criticalThermalIslandDetail(thermal)
            )
        case .disk:
            let disk = DiskUsage(totalBytes: 100_000_000_000, availableBytes: 4_900_000_000)

            return IslandActivity(
                metric: .memory,
                identity: alert,
                title: strings.text(.disk),
                value: ResourceFormatters.percentage(disk.percentage),
                iconAssetName: alert.iconAssetName(power: .empty),
                tint: .orange,
                progress: disk.percentage,
                detail: strings.criticalDiskIslandDetail(disk)
            )
        case .memory:
            let memory = MemoryUsage(
                totalBytes: 100_000_000_000,
                usedBytes: 91_000_000_000,
                availableBytes: 9_000_000_000,
                compressedBytes: 0,
                swapUsedBytes: 0,
                swapTotalBytes: 0
            )

            return IslandActivity(
                metric: .memory,
                identity: alert,
                title: strings.text(.memory),
                value: strings.pressure(memory.pressureLevel),
                iconAssetName: alert.iconAssetName(power: .empty),
                tint: SignalStatusColor.memoryPressure(memory.pressureLevel),
                progress: memory.percentage,
                detail: strings.criticalMemoryIslandDetail(memory)
            )
        }
    }
    #endif

    private func islandSurfaceBackground(
        topShoulderRadius: CGFloat,
        topShoulderInset: CGFloat,
        topShoulderDepth: CGFloat,
        bottomCornerRadius: CGFloat,
        opacity: Double,
        shadowOpacity: Double,
        shadowRadius: CGFloat
    ) -> some View {
        let shape = PulseIslandSurfaceShape(
            topShoulderRadius: topShoulderRadius,
            topShoulderInset: topShoulderInset,
            topShoulderDepth: topShoulderDepth,
            bottomCornerRadius: bottomCornerRadius
        )

        return shape
            .fill(Color.black.opacity(opacity))
            .shadow(color: .black.opacity(shadowOpacity), radius: shadowRadius, x: 0, y: shadowRadius * 0.38)
    }

    private func surfaceShape(for style: PulseIslandStyle) -> PulseIslandSurfaceShape {
        PulseIslandSurfaceShape(
            topShoulderRadius: PulseIslandLayout.surfaceTopShoulderRadius(for: style),
            topShoulderInset: PulseIslandLayout.surfaceTopShoulderInset(for: style),
            topShoulderDepth: PulseIslandLayout.surfaceTopShoulderDepth(for: style),
            bottomCornerRadius: PulseIslandLayout.surfaceBottomCornerRadius(for: style)
        )
    }
}

private struct IslandActivity {
    var identity: AnyHashable
    var title: String
    var value: String
    var iconAssetName: String?
    var tint: Color
    var progress: Double
    var detail: String?

    init(
        metric: PulseIslandSeedMetric,
        identity: AnyHashable? = nil,
        title: String,
        value: String,
        iconAssetName: String? = nil,
        tint: Color,
        progress: Double,
        detail: String? = nil
    ) {
        self.identity = identity ?? AnyHashable(metric)
        self.title = title
        self.value = value
        self.iconAssetName = iconAssetName
        self.tint = tint
        self.progress = progress
        self.detail = detail
    }

    var transitionIdentity: IslandActivityTransitionIdentity {
        IslandActivityTransitionIdentity(
            activity: identity,
            iconAssetName: iconAssetName
        )
    }
}

private struct IslandActivityTransitionIdentity: Hashable {
    var activity: AnyHashable
    var iconAssetName: String?
}

private enum IslandHeaderControlIcon {
    static let settings = "PanelSettingsIcon"
    static let quit = "PanelPowerIcon"
}

private struct IslandModuleHeader: View {
    var module: PulseIslandModule
    var title: String
    var deviceName: String
    var rowHeight: CGFloat
    var settingsTitle: String
    var settingsHelp: String
    var settingsAction: () -> Void
    var quitTitle: String
    var quitHelp: String
    var quitAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: PulseDesign.Spacing.sm) {
                Text(deviceName)
                    .font(PulseDesign.Typography.islandNotchedSeed)
                    .foregroundStyle(.white.opacity(PulseDesign.Opacity.secondaryOnDark))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: PulseDesign.Spacing.sm)

                HStack(spacing: PulseDesign.Spacing.xs) {
                    IslandHeaderIconButton(
                        iconName: IslandHeaderControlIcon.settings,
                        action: settingsAction
                    )
                    .help(settingsHelp)
                    .accessibilityLabel(settingsTitle)

                    IslandHeaderIconButton(
                        iconName: IslandHeaderControlIcon.quit,
                        action: quitAction
                    )
                    .help(quitHelp)
                    .accessibilityLabel(quitTitle)
                }
            }
            .frame(height: rowHeight, alignment: .center)

            HStack {
                Spacer(minLength: 0)
                moduleTitle
                Spacer(minLength: 0)
            }
            .frame(height: rowHeight, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }

    private var moduleTitle: some View {
        HStack(spacing: 10) {
            moduleIcon
                .frame(width: 16, height: 16)

            Text(title)
                .font(.system(.callout, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var moduleIcon: some View {
        Image(module.iconAssetName)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(.white.opacity(0.94))
            .accessibilityHidden(true)
    }
}

private struct IslandHeaderIconButton: View {
    var iconName: String
    var action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if isHovering {
                    RoundedRectangle(cornerRadius: PulseDesign.Radius.control, style: .continuous)
                        .fill(.white.opacity(PulseDesign.Opacity.hoverFillOnDark))
                }

                Image(iconName)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: PulseDesign.Control.iconSide, height: PulseDesign.Control.iconSide)
                    .accessibilityHidden(true)
            }
            .frame(width: PulseDesign.Control.buttonSide, height: PulseDesign.Control.buttonSide)
            .contentShape(RoundedRectangle(cornerRadius: PulseDesign.Radius.control, style: .continuous))
            .animation(.easeOut(duration: 0.12), value: isHovering)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(0.92))
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

private struct IslandModuleInteractionBridge: NSViewRepresentable {
    var switchAction: (Int) -> Void

    func makeNSView(context: Context) -> InteractionView {
        let view = InteractionView()
        view.switchAction = switchAction
        return view
    }

    func updateNSView(_ nsView: InteractionView, context: Context) {
        nsView.switchAction = switchAction
    }

    final class InteractionView: NSView {
        var switchAction: ((Int) -> Void)?

        private var mouseDownPoint: CGPoint?
        private var didSwitchDuringMouseDown = false
        private var didSwitchDuringScrollGesture = false
        private var accumulatedScrollDeltaY: CGFloat = 0
        private var lastScrollSwitchTime: TimeInterval = 0

        override var acceptsFirstResponder: Bool {
            true
        }

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
            true
        }

        override func mouseDown(with event: NSEvent) {
            mouseDownPoint = convert(event.locationInWindow, from: nil)
            didSwitchDuringMouseDown = false
        }

        override func mouseDragged(with event: NSEvent) {
            guard let mouseDownPoint, !didSwitchDuringMouseDown else {
                return
            }

            let currentPoint = convert(event.locationInWindow, from: nil)
            let translation = CGSize(
                width: currentPoint.x - mouseDownPoint.x,
                height: currentPoint.y - mouseDownPoint.y
            )

            guard
                abs(translation.height) >= abs(translation.width),
                abs(translation.height) >= moduleSwitchDragThreshold
            else {
                return
            }

            switchAction?(translation.height > 0 ? 1 : -1)
            didSwitchDuringMouseDown = true
        }

        override func mouseUp(with event: NSEvent) {
            mouseDownPoint = nil
            didSwitchDuringMouseDown = false
        }

        override func scrollWheel(with event: NSEvent) {
            if event.phase.contains(.began) || event.phase.contains(.mayBegin) {
                resetScrollGesture()
            }

            guard event.momentumPhase.isEmpty else {
                if event.momentumPhase.contains(.ended) || event.momentumPhase.contains(.cancelled) {
                    resetScrollGesture()
                }
                return
            }

            let endsScrollGesture = event.phase.contains(.ended) || event.phase.contains(.cancelled)
            defer {
                if endsScrollGesture {
                    resetScrollGesture()
                }
            }

            let deltaY = event.scrollingDeltaY
            guard
                abs(deltaY) >= abs(event.scrollingDeltaX),
                abs(deltaY) > 0
            else {
                super.scrollWheel(with: event)
                return
            }

            let isPhasedGesture = !event.phase.isEmpty
            guard shouldAcceptScrollSwitch(isPhasedGesture: isPhasedGesture) else {
                return
            }

            accumulatedScrollDeltaY += deltaY

            guard abs(accumulatedScrollDeltaY) >= moduleSwitchScrollThreshold else {
                return
            }

            switchAction?(accumulatedScrollDeltaY > 0 ? 1 : -1)
            didSwitchDuringScrollGesture = isPhasedGesture
            lastScrollSwitchTime = ProcessInfo.processInfo.systemUptime
            accumulatedScrollDeltaY = 0
        }

        private func shouldAcceptScrollSwitch(isPhasedGesture: Bool) -> Bool {
            if isPhasedGesture {
                return !didSwitchDuringScrollGesture
            }

            return ProcessInfo.processInfo.systemUptime - lastScrollSwitchTime >= moduleSwitchInputLockDuration
        }

        private func resetScrollGesture() {
            didSwitchDuringScrollGesture = false
            accumulatedScrollDeltaY = 0
        }
    }
}

private struct IslandPulseDots: View {
    private static let dotCount = 7

    var tint: Color
    var progress: Double

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<Self.dotCount, id: \.self) { index in
                Circle()
                    .fill(index <= activeIndex ? tint : Color.white.opacity(0.24))
                    .frame(width: index == activeIndex ? 7 : 5, height: index == activeIndex ? 7 : 5)
            }
        }
        .accessibilityHidden(true)
    }

    private var activeIndex: Int {
        let lastIndex = Self.dotCount - 1
        return min(lastIndex, max(0, Int((min(max(progress, 0), 1) * Double(lastIndex)).rounded())))
    }
}

private struct InstalledAppsAttachedPanelShape: Shape {
    var cornerRadius: CGFloat
    var separatorCenterY: CGFloat
    var separatorHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        let separatorHeight = min(max(0, separatorHeight), rect.height)
        let separatorCenterY = min(max(rect.minY + separatorCenterY, rect.minY), rect.maxY)
        let separatorMinY = min(max(separatorCenterY - separatorHeight / 2, rect.minY), rect.maxY)
        let separatorMaxY = min(max(separatorCenterY + separatorHeight / 2, rect.minY), rect.maxY)
        let topRect = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width,
            height: max(0, separatorMinY - rect.minY)
        )
        let bottomRect = CGRect(
            x: rect.minX,
            y: separatorMaxY,
            width: rect.width,
            height: max(0, rect.maxY - separatorMaxY)
        )
        let cornerSize = CGSize(width: cornerRadius, height: cornerRadius)
        var path = Path()

        path.addRoundedRect(in: topRect, cornerSize: cornerSize, style: .continuous)
        path.addRoundedRect(in: bottomRect, cornerSize: cornerSize, style: .continuous)

        return path
    }
}

private struct PulseIslandSurfaceShape: Shape {
    var topShoulderRadius: CGFloat
    var topShoulderInset: CGFloat
    var topShoulderDepth: CGFloat
    var bottomCornerRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>>> {
        get {
            AnimatablePair(
                topShoulderRadius,
                AnimatablePair(
                    topShoulderInset,
                    AnimatablePair(topShoulderDepth, bottomCornerRadius)
                )
            )
        }
        set {
            topShoulderRadius = newValue.first
            topShoulderInset = newValue.second.first
            topShoulderDepth = newValue.second.second.first
            bottomCornerRadius = newValue.second.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let bottomCornerRadius = min(bottomCornerRadius, rect.width / 4, rect.height / 2)
        let topShoulderInset = min(topShoulderInset, rect.width / 3)
        let topShoulderRadius = min(topShoulderRadius, topShoulderInset)
        let topShoulderDepth = min(topShoulderDepth, max(0, rect.height - bottomCornerRadius))
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topShoulderInset, y: rect.minY + topShoulderDepth),
            control: CGPoint(x: rect.minX + topShoulderRadius, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX + topShoulderInset, y: rect.maxY - bottomCornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topShoulderInset + bottomCornerRadius, y: rect.maxY),
            control: CGPoint(x: rect.minX + topShoulderInset, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - topShoulderInset - bottomCornerRadius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - topShoulderInset, y: rect.maxY - bottomCornerRadius),
            control: CGPoint(x: rect.maxX - topShoulderInset, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - topShoulderInset, y: rect.minY + topShoulderDepth))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - topShoulderRadius, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()

        return path
    }
}
