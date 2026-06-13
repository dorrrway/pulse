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
private let moduleSwitchHorizontalDragThreshold: CGFloat = 18
private let moduleSwitchHorizontalScrollThreshold: CGFloat = 12
private let moduleSwitchAnimation = Animation.smooth(duration: 0.22)
private let moduleSwitchInputLockDuration: TimeInterval = 0.24
private let moduleSelectorFallbackItemWidth: CGFloat = 96
private let moduleSelectorItemSpacing: CGFloat = PulseDesign.Spacing.lg
private let moduleSelectorClickMovementTolerance: CGFloat = 6
private let seedMetricRollAnimation = Animation.spring(response: 0.50, dampingFraction: 0.86, blendDuration: 0)
private let seedMetricFadeAnimation = Animation.easeInOut(duration: 0.16)
private let criticalSeedAnimation = Animation.spring(response: 0.42, dampingFraction: 0.84, blendDuration: 0)
private let screenshotPreviewAnimation = Animation.spring(response: 0.38, dampingFraction: 0.84, blendDuration: 0)
private let clipboardRecordReminderDuration: TimeInterval = 1.5

private enum ScreenshotPreviewActionIcon {
    case system(String)
    case asset(String)
}

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
    @State private var moduleSwitchDirection = 1
    @State private var isModuleSwitchLocked = false
    @State private var moduleSwitchLockGeneration = 0
    @State private var moduleSelectorItemWidths: [PulseIslandModule: CGFloat] = [:]
    @State private var selectedSeedMetric: PulseIslandSeedMetric = .memory
    @State private var activeCriticalAlert: PulseIslandCriticalAlert?
    @State private var acknowledgedCriticalAlerts: Set<PulseIslandCriticalAlert> = []
    @State private var activeClipboardReminder: ClipboardIslandReminder?
    @State private var clipboardReminderGeneration = 0
    @State private var isNotificationPanelRevealed = false
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

    private func panelContentSize(includesNotificationPanel: Bool) -> CGSize {
        PulseIslandLayout.panelContentSize(
            metrics: layoutMetrics,
            includesNotificationPanel: includesNotificationPanel
        )
    }

    private var selectedModule: PulseIslandModule {
        controller.selectedModule
    }

    private var usesExpandedVisualState: Bool {
        style == .expanded
    }

    private var usesCriticalSeedState: Bool {
        style == .criticalSeed
    }

    private var usesScreenshotPreviewState: Bool {
        style == .screenshotPreview
    }

    private var usesSeedVisualState: Bool {
        style == .seed || style == .criticalSeed
    }

    private var shouldRenderExpandedSurface: Bool {
        usesExpandedVisualState || keepsExpandedSurfaceMounted
    }

    private var transitionAnimation: Animation {
        switch style {
        case .expanded:
            islandOpenAnimation
        case .screenshotPreview:
            screenshotPreviewAnimation
        case .criticalSeed:
            criticalSeedAnimation
        case .seed:
            islandCloseAnimation
        }
    }

    var body: some View {
        let strings = store.strings
        let criticalAlerts = PulseIslandCriticalAlert.active(
            core: store.coreMetrics,
            signal: store.signalMetrics,
            bluetoothDevices: store.bluetoothDevices.devices
        )
        let activeNotificationSuggestionIDs = Set(
            PulseNotificationSuggestion.allActive(
                core: store.coreMetrics,
                signal: store.signalMetrics,
                bluetoothDevices: store.bluetoothDevices.devices
            )
            .map(\.id)
        )
        let notificationSuggestions = PulseNotificationSuggestion.active(
            core: store.coreMetrics,
            signal: store.signalMetrics,
            bluetoothDevices: store.bluetoothDevices.devices,
            isEnabled: store.notificationSuggestionsEnabled,
            dismissedIDs: store.dismissedNotificationSuggestionIDs
        )
        let shouldShowNotificationPanel = !notificationSuggestions.isEmpty
        let rotationMetrics = PulseIslandSeedMetric.rotationMetrics(
            for: store.signalMetrics.power,
            bluetoothDevices: store.bluetoothDevices.devices
        )
        let activeSeedMetric = selectedSeedMetric.normalized(in: rotationMetrics)
        let presentation = seedPresentation(metric: activeSeedMetric, strings: strings)
        let currentPanelContentSize = panelContentSize(
            includesNotificationPanel: isNotificationPanelRevealed
        )

        ZStack(alignment: .top) {
            morphingIslandChrome(panelContentSize: currentPanelContentSize)

            if shouldRenderExpandedSurface {
                surfaceLayer(for: .expanded, panelContentSize: currentPanelContentSize) {
                    expandedIsland(strings: strings, notificationSuggestions: notificationSuggestions)
                }
                .opacity(usesExpandedVisualState ? 1 : 0)
                .scaleEffect(usesExpandedVisualState ? 1 : 0.88, anchor: .top)
                .allowsHitTesting(usesExpandedVisualState)
            }

            if let capturePreviewReminder = controller.capturePreviewReminder {
                surfaceLayer(for: .screenshotPreview, panelContentSize: currentPanelContentSize) {
                    screenshotPreviewSurface(
                        reminder: capturePreviewReminder,
                        title: capturePreviewTitle(reminder: capturePreviewReminder, strings: strings)
                    )
                }
                .opacity(usesScreenshotPreviewState ? 1 : 0)
                .scaleEffect(usesScreenshotPreviewState ? 1 : 0.92, anchor: .top)
                .allowsHitTesting(usesScreenshotPreviewState)
            }

            surfaceLayer(for: .seed, panelContentSize: currentPanelContentSize) {
                seedSurface(presentation: presentation)
            }
            .opacity(usesSeedVisualState ? 1 : 0)
            .scaleEffect(usesSeedVisualState ? 1 : 0.82, anchor: .top)
            .allowsHitTesting(usesSeedVisualState)
        }
        .frame(
            width: currentPanelContentSize.width,
            height: currentPanelContentSize.height,
            alignment: .top
        )
        .foregroundStyle(.white)
        .animation(transitionAnimation, value: style)
        .onAppear {
            syncNotificationPanelVisibility(isVisible: shouldShowNotificationPanel, immediate: true)
            syncExpandedSurfaceMount(with: style, immediate: true)
            #if DEBUG
            handleCriticalAlertPreviewRequest(controller.criticalAlertPreviewRequest)
            #endif
            store.reconcileDismissedNotificationSuggestions(activeIDs: activeNotificationSuggestionIDs)
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
        .onChange(of: activeNotificationSuggestionIDs) { _, ids in
            store.reconcileDismissedNotificationSuggestions(activeIDs: ids)
        }
        .onChange(of: shouldShowNotificationPanel) { _, isVisible in
            syncNotificationPanelVisibility(isVisible: isVisible)
        }
        .onChange(of: store.clipboardHistory.latestRecordNotice) { _, notice in
            handleClipboardRecordNotice(notice, strings: store.strings)
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

    private func morphingIslandChrome(panelContentSize: CGSize) -> some View {
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
            width: panelContentSize.width,
            height: panelContentSize.height,
            alignment: .top
        )
        .allowsHitTesting(false)
    }

    private func surfaceLayer<Surface: View>(
        for style: PulseIslandStyle,
        panelContentSize: CGSize,
        @ViewBuilder surface: () -> Surface
    ) -> some View {
        return VStack(spacing: 0) {
            Color.clear
                .frame(height: PulseIslandLayout.surfaceTopOffset(for: style))

            surface()

            Spacer(minLength: 0)
        }
        .frame(
            width: panelContentSize.width,
            height: panelContentSize.height,
            alignment: .top
        )
    }

    private func syncNotificationPanelVisibility(isVisible: Bool, immediate: Bool = false) {
        if isVisible {
            if immediate {
                isNotificationPanelRevealed = true
            } else {
                withAnimation(attachedPanelRevealAnimation) {
                    isNotificationPanelRevealed = true
                }
            }

            controller.setNotificationPanelVisible(true)

            return
        }

        if immediate {
            isNotificationPanelRevealed = false
            controller.setNotificationPanelVisible(false)
            return
        }

        withAnimation(attachedPanelConcealAnimation) {
            isNotificationPanelRevealed = false
        }
        controller.setNotificationPanelVisible(false)
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
        case .seed, .criticalSeed, .screenshotPreview:
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

    private func seedSurface(presentation: IslandSeedPresentation) -> some View {
        let seedStyle: PulseIslandStyle = usesCriticalSeedState ? .criticalSeed : .seed
        let visibleSize = PulseIslandLayout.seedVisibleSize(for: seedStyle, metrics: layoutMetrics)
        let contentSize = PulseIslandLayout.contentSize(for: seedStyle, metrics: layoutMetrics)

        return VStack(spacing: 0) {
            Color.clear
                .frame(height: PulseIslandLayout.topAttachmentDepth(for: seedStyle))

            seedContent(presentation: presentation)
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
            controller.setSeedHovering(hovering)
        }
        .onTapGesture(perform: expandAction)
    }

    private func seedContent(presentation: IslandSeedPresentation) -> some View {
        if let recordingSession = controller.screenRecordingState.activeSession {
            return AnyView(recordingSeedContent(session: recordingSession))
        }

        if usesCriticalSeedState {
            guard case .activity(let activity) = presentation else {
                return AnyView(EmptyView())
            }

            return AnyView(criticalSeedContent(activity: activity))
        }

        let notchGapWidth = PulseIslandLayout.notchContentGapWidth(metrics: layoutMetrics)

        if notchGapWidth > 0 {
            return AnyView(notchAwareSeedContent(presentation: presentation, notchGapWidth: notchGapWidth))
        }

        return AnyView(standardSeedContent(presentation: presentation))
    }

    private func recordingSeedContent(session: PulseScreenRecordingSession) -> some View {
        let rowHeight = PulseIslandLayout.seedVisibleSize(for: .seed, metrics: layoutMetrics).height
        let notchGapWidth = PulseIslandLayout.notchContentGapWidth(metrics: layoutMetrics)

        return TimelineView(.periodic(from: session.startedAt, by: 1)) { context in
            HStack(spacing: 0) {
                recordingElapsedLabel(
                    startedAt: session.startedAt,
                    now: context.date
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )

                if notchGapWidth > 0 {
                    Color.clear
                        .frame(width: notchGapWidth)
                }

                recordingStopButton()
                    .frame(
                        maxWidth: .infinity,
                        alignment: .trailing
                    )
            }
            .frame(height: rowHeight)
            .padding(.horizontal, notchGapWidth > 0 ? PulseIslandLayout.notchedSeedContentHorizontalPadding : PulseIslandLayout.seedContentHorizontalPadding)
        }
    }

    private func recordingElapsedLabel(startedAt: Date, now: Date) -> some View {
        HStack(spacing: PulseDesign.Spacing.xxs) {
            Circle()
                .fill(.red.opacity(0.92))
                .frame(width: 7, height: 7)

            Text(recordingElapsedText(startedAt: startedAt, now: now))
                .font(.system(.caption, design: .rounded, weight: .bold).monospacedDigit())
                .foregroundStyle(.white.opacity(0.94))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .accessibilityElement(children: .combine)
    }

    private func recordingStopButton() -> some View {
        let isStopping: Bool = {
            if case .stopping = controller.screenRecordingState {
                return true
            }

            return false
        }()

        return Button {
            controller.stopScreenRecording(strings: store.strings)
        } label: {
            Image(systemName: "stop.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(isStopping ? 0.42 : 0.94))
                .frame(width: 24, height: 24)
                .background(
                    .red.opacity(isStopping ? 0.16 : 0.74),
                    in: Circle()
                )
        }
        .buttonStyle(.plain)
        .disabled(isStopping)
        .accessibilityLabel(store.strings.text(.screenRecordingStopAction))
        .help(store.strings.text(.screenRecordingStopAction))
    }

    private func recordingElapsedText(startedAt: Date, now: Date) -> String {
        let elapsed = max(0, Int(now.timeIntervalSince(startedAt)))
        return durationText(seconds: elapsed)
    }

    private func screenRecordingDurationText(_ duration: TimeInterval) -> String {
        durationText(seconds: max(0, Int(duration.rounded())))
    }

    private func durationText(seconds: Int) -> String {
        let elapsed = max(0, seconds)
        let hours = elapsed / 3600
        let minutes = (elapsed % 3600) / 60
        let seconds = elapsed % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func standardSeedContent(presentation: IslandSeedPresentation) -> some View {
        let rowHeight = PulseIslandLayout.seedVisibleSize(for: .seed, metrics: layoutMetrics).height

        return HStack(spacing: 9) {
            Color.clear
                .frame(
                    width: PulseDesign.Control.symbolSize,
                    height: rowHeight
                )
                .accessibilityHidden(true)

            ZStack {
                standardSeedTrailingContent(presentation: presentation, rowHeight: rowHeight)
                .frame(height: rowHeight)
                .id(presentation.transitionIdentity)
                .transition(seedMetricTransition)
            }
            .frame(maxWidth: .infinity, maxHeight: rowHeight)
            .clipped()
        }
        .frame(height: rowHeight)
        .overlay(alignment: .leading) {
            ZStack(alignment: .leading) {
                standardSeedLeadingContent(
                    presentation: presentation,
                    rowHeight: rowHeight
                )
                .fixedSize(horizontal: true, vertical: false)
                .frame(height: rowHeight, alignment: .leading)
                .id(presentation.transitionIdentity)
                .transition(seedMetricTransition)
            }
            .frame(maxWidth: .infinity, maxHeight: rowHeight, alignment: .leading)
            .clipped()
            .allowsHitTesting(false)
        }
        .padding(.horizontal, PulseIslandLayout.seedContentHorizontalPadding)
    }

    private func notchAwareSeedContent(presentation: IslandSeedPresentation, notchGapWidth: CGFloat) -> some View {
        let sideLaneWidth = PulseIslandLayout.notchedSeedContentSideLaneWidth(metrics: layoutMetrics)
        let rowHeight = PulseIslandLayout.seedVisibleSize(for: .seed, metrics: layoutMetrics).height

        return HStack(spacing: 0) {
            ZStack(alignment: .leading) {
                rollingSeedPresentationIcon(
                    presentation: presentation,
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
                notchedSeedTrailingContent(presentation: presentation, rowHeight: rowHeight)
                    .frame(width: sideLaneWidth, height: rowHeight, alignment: .trailing)
                    .id(presentation.transitionIdentity)
                    .transition(seedMetricTransition)
            }
            .frame(width: sideLaneWidth, height: rowHeight, alignment: .trailing)
            .clipped()
        }
        .frame(height: rowHeight)
        .padding(.horizontal, PulseIslandLayout.notchedSeedContentHorizontalPadding)
    }

    private func seedPresentationIcon(_ presentation: IslandSeedPresentation) -> some View {
        seedAssetIcon(
            presentation.leadingIconAssetName,
            title: presentation.title,
            tint: presentation.leadingTint
        )
    }

    private func seedAssetIcon(_ assetName: String, title: String, tint: Color) -> some View {
        Image(assetName)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(
                width: PulseDesign.Control.symbolSize,
                height: PulseDesign.Control.symbolSize
            )
            .foregroundStyle(tint.opacity(0.96))
            .accessibilityLabel(title)
            .help(title)
    }

    private func rollingSeedPresentationIcon(
        presentation: IslandSeedPresentation,
        width: CGFloat,
        rowHeight: CGFloat,
        alignment: Alignment = .center
    ) -> some View {
        ZStack(alignment: alignment) {
            seedPresentationIcon(presentation)
                .frame(width: width, height: rowHeight, alignment: alignment)
                .id(presentation.transitionIdentity)
                .transition(seedMetricTransition)
        }
        .frame(
            width: width,
            height: rowHeight,
            alignment: alignment
        )
        .clipped()
    }

    @ViewBuilder
    private func standardSeedLeadingContent(
        presentation: IslandSeedPresentation,
        rowHeight: CGFloat
    ) -> some View {
        switch presentation {
        case .activity:
            seedPresentationIcon(presentation)
                .frame(
                    width: PulseDesign.Control.symbolSize,
                    height: rowHeight
                )
        case .clipboard(let reminder):
            HStack(spacing: PulseDesign.Spacing.fine) {
                seedPresentationIcon(presentation)
                    .frame(
                        width: PulseDesign.Control.symbolSize,
                        height: rowHeight
                    )

                Text(reminder.copyLabel)
                    .font(PulseDesign.Typography.islandSeed)
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .frame(height: rowHeight)
        }
    }

    @ViewBuilder
    private func standardSeedTrailingContent(
        presentation: IslandSeedPresentation,
        rowHeight: CGFloat
    ) -> some View {
        switch presentation {
        case .activity(let activity):
            HStack(spacing: 9) {
                IslandPulseDots(tint: activity.tint, progress: activity.progress)

                Spacer(minLength: 0)

                seedValueText(activity.value, font: PulseDesign.Typography.islandSeed)
            }
            .frame(height: rowHeight)
        case .clipboard(let reminder):
            HStack(spacing: 0) {
                Spacer(minLength: 0)

                seedAssetIcon(
                    reminder.confirmationIconAssetName,
                    title: reminder.confirmationTitle,
                    tint: reminder.confirmationTint
                )
            }
            .frame(height: rowHeight)
        }
    }

    @ViewBuilder
    private func notchedSeedTrailingContent(
        presentation: IslandSeedPresentation,
        rowHeight: CGFloat
    ) -> some View {
        switch presentation {
        case .activity(let activity):
            seedValueText(activity.value, font: PulseDesign.Typography.islandNotchedSeed)
        case .clipboard(let reminder):
            seedAssetIcon(
                reminder.confirmationIconAssetName,
                title: reminder.confirmationTitle,
                tint: reminder.confirmationTint
            )
        }
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
                        .minimumScaleFactor(0.72)
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

    private func screenshotPreviewSurface(reminder: PulseCapturePreviewReminder, title: String) -> some View {
        let visibleSize = PulseIslandLayout.seedVisibleSize(for: .screenshotPreview, metrics: layoutMetrics)
        let contentSize = PulseIslandLayout.contentSize(for: .screenshotPreview, metrics: layoutMetrics)
        let headerRowHeight = PulseIslandLayout.screenshotPreviewHeaderRowHeight(metrics: layoutMetrics)

        return VStack(spacing: 0) {
            Color.clear
                .frame(height: PulseIslandLayout.topAttachmentDepth(for: .screenshotPreview))

            VStack(spacing: PulseDesign.Spacing.xs) {
                HStack(alignment: .center, spacing: PulseDesign.Spacing.xs) {
                    capturePreviewHeaderIcon(reminder: reminder)

                    Text(title)
                        .font(.system(.callout, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.94))
                        .lineLimit(1)

                    Spacer(minLength: PulseDesign.Spacing.sm)

                    capturePreviewCloseButton(strings: store.strings)
                }
                .frame(height: headerRowHeight, alignment: .center)

                capturePreviewMedia(reminder: reminder, title: title, visibleWidth: visibleSize.width)

                capturePreviewActions(reminder: reminder, strings: store.strings)
                    .padding(.top, PulseDesign.Spacing.md)
            }
            .padding(.horizontal, PulseDesign.Spacing.md)
            .padding(.bottom, PulseDesign.Spacing.md)
            .frame(width: visibleSize.width, height: visibleSize.height, alignment: .top)
        }
        .frame(width: contentSize.width, height: contentSize.height, alignment: .top)
        .clipShape(surfaceShape(for: .screenshotPreview))
        .contentShape(surfaceShape(for: .screenshotPreview))
        .onHover { hovering in
            controller.setHovering(hovering)
        }
    }

    @ViewBuilder
    private func capturePreviewHeaderIcon(reminder: PulseCapturePreviewReminder) -> some View {
        if reminder.isScreenRecording {
            Image(systemName: "video.fill")
                .font(.system(size: 16, weight: .semibold))
                .frame(
                    width: PulseDesign.Control.iconFrameSide,
                    height: PulseDesign.Control.iconFrameSide
                )
                .foregroundStyle(.white.opacity(0.94))
                .accessibilityHidden(true)
        } else {
            Image("ClipboardImageFilterIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(
                    width: PulseDesign.Control.iconFrameSide,
                    height: PulseDesign.Control.iconFrameSide
                )
                .foregroundStyle(.white.opacity(0.94))
                .accessibilityHidden(true)
        }
    }

    private func capturePreviewCloseButton(strings: PulseStrings) -> some View {
        Button {
            controller.closeCapturePreview()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.90))
                .frame(
                    width: PulseDesign.Control.iconFrameSide,
                    height: PulseDesign.Control.iconFrameSide
                )
                .background(.white.opacity(0.12), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(strings.text(.capturePreviewCloseAction))
        .help(strings.text(.capturePreviewCloseAction))
    }

    private func capturePreviewMedia(
        reminder: PulseCapturePreviewReminder,
        title: String,
        visibleWidth: CGFloat
    ) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Image(nsImage: reminder.previewImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: visibleWidth - PulseDesign.Spacing.md * 2, maxHeight: 112)
                .clipShape(RoundedRectangle(cornerRadius: PulseDesign.Radius.card, style: .continuous))
                .accessibilityLabel(title)

            if let recording = reminder.screenRecording {
                Image(systemName: "play.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white.opacity(0.95))
                    .frame(width: 42, height: 42)
                    .background(.black.opacity(0.42), in: Circle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .accessibilityHidden(true)

                Text(screenRecordingDurationText(recording.duration))
                    .font(.system(.caption2, design: .rounded, weight: .bold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.95))
                    .padding(.horizontal, PulseDesign.Spacing.xs)
                    .padding(.vertical, 3)
                    .background(.black.opacity(0.54), in: Capsule())
                    .padding(PulseDesign.Spacing.xs)
            }
        }
        .frame(maxWidth: visibleWidth - PulseDesign.Spacing.md * 2, maxHeight: 112)
        .contentShape(RoundedRectangle(cornerRadius: PulseDesign.Radius.card, style: .continuous))
        .onTapGesture {
            if reminder.isScreenRecording {
                controller.openScreenRecordingPreview(strings: store.strings)
            }
        }
        .onDrag {
            controller.capturePreviewDragItemProvider()
        }
    }

    private func capturePreviewTitle(reminder: PulseCapturePreviewReminder, strings: PulseStrings) -> String {
        if reminder.isScreenRecording {
            return strings.text(.screenRecordingPreviewTitle)
        }

        return strings.text(.screenshotCaptured)
    }

    @ViewBuilder
    private func capturePreviewActions(reminder: PulseCapturePreviewReminder, strings: PulseStrings) -> some View {
        if reminder.isScreenRecording {
            screenRecordingPreviewActions(strings: strings)
        } else {
            screenshotPreviewActions(strings: strings)
        }
    }

    private func screenRecordingPreviewActions(strings: PulseStrings) -> some View {
        HStack(spacing: PulseDesign.Spacing.xs) {
            screenshotPreviewActionButton(
                title: strings.text(.screenRecordingPreviewAction),
                icon: .system("play.fill")
            ) {
                controller.openScreenRecordingPreview(strings: strings)
            }

            screenshotPreviewActionButton(
                title: strings.text(.screenshotSaveAction),
                icon: .system("square.and.arrow.down")
            ) {
                controller.saveScreenRecordingPreview(strings: strings)
            }

            screenshotPreviewActionButton(
                title: strings.text(.screenshotShareAction),
                icon: .system("square.and.arrow.up")
            ) {
                controller.shareCapturePreview()
            }

            screenshotPreviewActionButton(
                title: strings.text(.screenRecordingDiscardAction),
                icon: .system("trash"),
                isDestructive: true
            ) {
                controller.discardCapturePreview()
            }
        }
        .frame(height: 30)
    }

    private func screenshotPreviewActions(strings: PulseStrings) -> some View {
        HStack(spacing: PulseDesign.Spacing.xs) {
            screenshotPreviewActionButton(
                title: strings.text(.screenshotSaveAction),
                icon: .system("square.and.arrow.down")
            ) {
                controller.saveScreenshotPreview()
            }

            screenshotPreviewActionButton(
                title: strings.text(.screenshotShareAction),
                icon: .system("square.and.arrow.up")
            ) {
                controller.shareScreenshotPreview()
            }

            screenshotPreviewActionButton(
                title: strings.text(.screenshotEditAction),
                icon: .system("slider.horizontal.3")
            ) {
                controller.editScreenshotPreview(strings: strings)
            }

            screenshotPreviewActionButton(
                title: strings.text(.screenshotPinAction),
                icon: .asset(PanelControlIcon.pin)
            ) {
                controller.pinScreenshotPreview(strings: strings)
            }

            screenshotPreviewActionButton(
                title: screenshotRecognizeTextActionTitle(strings: strings),
                icon: .system("text.viewfinder"),
                isDisabled: controller.screenshotPreviewActionState == .recognizingText
            ) {
                controller.recognizeTextInScreenshotPreview(strings: strings)
            }
        }
        .frame(height: 30)
    }

    private func screenshotRecognizeTextActionTitle(strings: PulseStrings) -> String {
        switch controller.screenshotPreviewActionState {
        case .idle:
            strings.text(.screenshotRecognizeTextAction)
        case .recognizingText:
            strings.text(.screenshotRecognizingText)
        case .noRecognizedText:
            strings.text(.screenshotNoRecognizedText)
        case .textCopied:
            strings.text(.screenshotTextCopied)
        }
    }

    private func screenshotPreviewActionButton(
        title: String,
        icon: ScreenshotPreviewActionIcon,
        isDisabled: Bool = false,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: PulseDesign.Spacing.xxs) {
                screenshotPreviewActionIcon(icon)

                Text(title)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(actionForegroundColor(isDisabled: isDisabled, isDestructive: isDestructive))
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .background(
                actionBackgroundColor(isDisabled: isDisabled, isDestructive: isDestructive),
                in: RoundedRectangle(cornerRadius: PulseDesign.Radius.control, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(title)
    }

    private func actionForegroundColor(isDisabled: Bool, isDestructive: Bool) -> Color {
        if isDisabled {
            return .white.opacity(0.42)
        }

        if isDestructive {
            return .red.opacity(0.92)
        }

        return .white.opacity(0.88)
    }

    private func actionBackgroundColor(isDisabled: Bool, isDestructive: Bool) -> Color {
        if isDisabled {
            return .white.opacity(0.05)
        }

        if isDestructive {
            return .red.opacity(0.16)
        }

        return .white.opacity(0.10)
    }

    @ViewBuilder
    private func screenshotPreviewActionIcon(_ icon: ScreenshotPreviewActionIcon) -> some View {
        switch icon {
        case .system(let name):
            Image(systemName: name)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 14, height: 14)
                .accessibilityHidden(true)
        case .asset(let name):
            PanelControlIconImage(name: name, side: 14)
                .frame(width: 14, height: 14)
        }
    }

    private func expandedIsland(
        strings: PulseStrings,
        notificationSuggestions: [PulseNotificationSuggestion]
    ) -> some View {
        VStack(spacing: PulseIslandLayout.attachedPanelTopGap) {
            expandedSurface(strings: strings)

            if isNotificationPanelRevealed && !notificationSuggestions.isEmpty {
                notificationSuggestionPanel(
                    suggestions: notificationSuggestions,
                    strings: strings
                )
            }

            attachedPanel()
        }
        .onHover { hovering in
            controller.setPanelHovering(hovering)
        }
    }

    private func notificationSuggestionPanel(
        suggestions: [PulseNotificationSuggestion],
        strings: PulseStrings
    ) -> some View {
        HStack(spacing: 8) {
            ForEach(suggestions) { suggestion in
                notificationSuggestionCard(suggestion, strings: strings)
            }
        }
        .frame(
            width: PulseIslandLayout.expandedSurfaceWidth,
            height: PulseIslandLayout.notificationPanelHeight
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func notificationSuggestionCard(
        _ suggestion: PulseNotificationSuggestion,
        strings: PulseStrings
    ) -> some View {
        let activity = criticalActivity(alert: suggestion.alert, strings: strings)
        let module = notificationModule(for: suggestion.alert)
        let title = notificationTitle(for: suggestion.alert, activity: activity, strings: strings)
        let detail = activity.detail ?? title

        return IslandNotificationSuggestionCard(
            title: title,
            value: activity.value,
            detail: detail,
            iconAssetName: activity.iconAssetName ?? "PulseStatusIcon",
            tint: activity.tint,
            dismissTitle: strings.text(.notificationDismiss),
            openAction: {
                switchModule(to: module)
            },
            dismissAction: {
                store.dismissNotificationSuggestion(withID: suggestion.id)
            }
        )
    }

    private func notificationTitle(
        for alert: PulseIslandCriticalAlert,
        activity: IslandActivity,
        strings: PulseStrings
    ) -> String {
        switch alert {
        case .power:
            strings.text(.notificationPowerTitle)
        case .bluetoothBattery:
            activity.title
        case .thermal:
            strings.text(.notificationThermalTitle)
        case .disk:
            strings.text(.notificationDiskTitle)
        case .memory:
            strings.text(.notificationMemoryTitle)
        }
    }

    private func notificationModule(for alert: PulseIslandCriticalAlert) -> PulseIslandModule {
        switch alert {
        case .bluetoothBattery:
            .bluetooth
        case .power, .thermal, .disk, .memory:
            .resourceMonitor
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
                    InstalledAppsPanelView(
                        openApplication: .live(afterLaunch: {
                            controller.collapseAfterLaunchingApplication()
                        }),
                        uninstallWindowController: controller.applicationUninstallWindowController,
                        afterUninstallWindowPresented: {
                            controller.collapseAfterLaunchingApplication()
                        }
                    )
                        .environment(store)
                case .clipboard:
                    ClipboardPanelView()
                        .environment(store)
                case .memos:
                    MemoPanelView()
                        .environment(store)
                case .screenshots:
                    PulseScreenshotPanelView(
                        recordingState: controller.screenRecordingState,
                        recordAction: { mode in
                            controller.startScreenRecording(
                                mode: mode,
                                hidesPulseDuringCapture: store.hidePulseDuringScreenshots,
                                hidesCursorDuringCapture: store.hideCursorDuringScreenRecordings
                            )
                        },
                        stopRecordingAction: {
                            controller.stopScreenRecording(strings: store.strings)
                        },
                        captureAction: { mode in
                            controller.captureScreenshot(
                                mode: mode,
                                hidesPulseDuringCapture: store.hidePulseDuringScreenshots
                            )
                        }
                    )
                    .environment(store)
                case .bluetooth:
                    BluetoothPanelView(
                        bluetooth: store.bluetoothDevices,
                        collapseBeforeAuthorization: collapseAction
                    )
                        .environment(store)
                #if DEBUG
                case .translation:
                    TranslationPanelView()
                        .environment(store)
                #endif
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
        case .clipboard, .memos, .screenshots, .bluetooth:
            RoundedRectangle(cornerRadius: PulsePanelLayout.panelCornerRadius, style: .continuous)
                .fill(fill)
        #if DEBUG
        case .translation:
            RoundedRectangle(cornerRadius: PulsePanelLayout.panelCornerRadius, style: .continuous)
                .fill(fill)
        #endif
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
        case .clipboard, .memos, .screenshots, .bluetooth:
            RoundedRectangle(cornerRadius: PulsePanelLayout.panelCornerRadius, style: .continuous)
                .fill(.black)
        #if DEBUG
        case .translation:
            RoundedRectangle(cornerRadius: PulsePanelLayout.panelCornerRadius, style: .continuous)
                .fill(.black)
        #endif
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
        let insertionEdge: Edge = moduleSwitchDirection > 0 ? .trailing : .leading
        let removalEdge: Edge = moduleSwitchDirection > 0 ? .leading : .trailing

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
                selectedModule: selectedModule,
                moduleTitle: { strings.text($0.titleKey) },
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
                },
                itemWidths: moduleSelectorItemWidths,
                updateItemWidths: { moduleSelectorItemWidths = $0 },
                selectModule: switchModule(to:)
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
                    selectedModule: selectedModule,
                    moduleRowHeight: headerRowHeight,
                    itemWidths: moduleSelectorItemWidths,
                    switchAction: { switchModule(by: $0) },
                    selectAction: { switchModule(to: $0) }
                )
                .frame(width: PulseIslandLayout.expandedSurfaceWidth, height: headerContentHeight)
                .accessibilityHidden(true)
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
        switchModule(to: nextModule, direction: offset >= 0 ? 1 : -1)
    }

    private func switchModule(to module: PulseIslandModule) {
        switchModule(to: module, direction: moduleSwitchDirection(to: module))
    }

    private func switchModule(to module: PulseIslandModule, direction: Int) {
        guard !isModuleSwitchLocked, module != selectedModule else {
            return
        }

        isModuleSwitchLocked = true
        moduleSwitchLockGeneration &+= 1
        let lockGeneration = moduleSwitchLockGeneration
        moduleSwitchDirection = direction >= 0 ? 1 : -1

        withAnimation(moduleSwitchAnimation) {
            controller.selectModule(module)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + moduleSwitchInputLockDuration) {
            guard moduleSwitchLockGeneration == lockGeneration else {
                return
            }

            isModuleSwitchLocked = false
        }
    }

    private func moduleSwitchDirection(to module: PulseIslandModule) -> Int {
        let modules = PulseIslandModule.allCases
        guard
            let currentIndex = modules.firstIndex(of: selectedModule),
            let targetIndex = modules.firstIndex(of: module)
        else {
            return 1
        }

        return targetIndex >= currentIndex ? 1 : -1
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

        switch nextAlert {
        case .power:
            selectedSeedMetric = .power
        case .bluetoothBattery(let alert):
            selectedSeedMetric = .bluetoothBattery(alert)
        case .thermal, .disk, .memory:
            break
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

    private func handleClipboardRecordNotice(_ notice: ClipboardHistoryRecordNotice?, strings: PulseStrings) {
        guard let notice, style == .seed, activeCriticalAlert == nil else {
            return
        }

        clipboardReminderGeneration &+= 1
        let generation = clipboardReminderGeneration
        let reminder = ClipboardIslandReminder(notice: notice, strings: strings)

        withAnimation(seedMetricAnimation) {
            activeClipboardReminder = reminder
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + clipboardRecordReminderDuration) {
            guard
                clipboardReminderGeneration == generation,
                activeClipboardReminder?.id == reminder.id
            else {
                return
            }

            withAnimation(seedMetricAnimation) {
                activeClipboardReminder = nil
            }
        }
    }

    private func rotateSeedMetric() async {
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .milliseconds(Int(PulseIslandSeedMetric.rotationInterval * 1_000)))
            } catch {
                return
            }

            withAnimation(seedMetricAnimation) {
                let rotationMetrics = PulseIslandSeedMetric.rotationMetrics(
                    for: store.signalMetrics.power,
                    bluetoothDevices: store.bluetoothDevices.devices
                )
                selectedSeedMetric = selectedSeedMetric.next(in: rotationMetrics)
            }
        }
    }

    private func seedPresentation(metric: PulseIslandSeedMetric, strings: PulseStrings) -> IslandSeedPresentation {
        if let activeCriticalAlert {
            return .activity(visibleCriticalActivity(alert: activeCriticalAlert, strings: strings))
        }

        if let activeClipboardReminder, style == .seed {
            return .clipboard(activeClipboardReminder)
        }

        return .activity(seedActivity(metric: metric, strings: strings))
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
        case .bluetoothBattery(let batteryAlert):
            return IslandActivity(
                metric: metric,
                title: strings.bluetoothBatteryAlertTitle(batteryAlert),
                value: ResourceFormatters.percentage(batteryAlert.percentage),
                iconAssetName: metric.compactIconAssetName(power: store.signalMetrics.power),
                tint: SignalStatusColor.bluetoothBattery(batteryAlert),
                progress: batteryAlert.percentage,
                detail: strings.bluetoothBatteryAlertDetail(batteryAlert)
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
        case .bluetoothBattery(let batteryAlert):
            return IslandActivity(
                metric: .power,
                identity: alert,
                title: strings.bluetoothBatteryAlertTitle(batteryAlert),
                value: ResourceFormatters.percentage(batteryAlert.percentage),
                iconAssetName: alert.iconAssetName(power: signalMetrics.power),
                tint: SignalStatusColor.bluetoothBattery(batteryAlert),
                progress: batteryAlert.percentage,
                detail: strings.bluetoothBatteryAlertDetail(batteryAlert)
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
        case .bluetoothBattery(let batteryAlert):
            return IslandActivity(
                metric: .power,
                identity: alert,
                title: strings.bluetoothBatteryAlertTitle(batteryAlert),
                value: ResourceFormatters.percentage(batteryAlert.percentage),
                iconAssetName: alert.iconAssetName(power: .empty),
                tint: SignalStatusColor.bluetoothBattery(batteryAlert),
                progress: batteryAlert.percentage,
                detail: strings.bluetoothBatteryAlertDetail(batteryAlert)
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

private struct IslandNotificationSuggestionCard: View {
    var title: String
    var value: String
    var detail: String
    var iconAssetName: String
    var tint: Color
    var dismissTitle: String
    var openAction: () -> Void
    var dismissAction: () -> Void

    var body: some View {
        let backgroundShape = RoundedRectangle(cornerRadius: PulseDesign.Radius.panel, style: .continuous)

        HStack(spacing: 8) {
            Button(action: openAction) {
                HStack(spacing: 9) {
                    ZStack {
                        Circle()
                            .fill(tint.opacity(0.18))

                        PanelControlIconImage(name: iconAssetName, side: 16)
                            .foregroundStyle(tint)
                    }
                    .frame(width: 30, height: 30)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .lineLimit(1)

                        Text(detail)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.68))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    Spacer(minLength: 8)

                    Text(value)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .frame(minWidth: 24, alignment: .center)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.42))
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .help(detail)
            .accessibilityLabel(title)
            .accessibilityValue(detail)

            Button(action: dismissAction) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 18, height: 18)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.58))
            .help(dismissTitle)
            .accessibilityLabel(dismissTitle)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            backgroundShape
                .fill(Color.black.opacity(0.86))
                .overlay {
                    backgroundShape.fill(tint.opacity(0.32))
                }
        }
    }
}

private enum IslandSeedPresentation {
    case activity(IslandActivity)
    case clipboard(ClipboardIslandReminder)

    var title: String {
        switch self {
        case .activity(let activity):
            activity.title
        case .clipboard(let reminder):
            reminder.title
        }
    }

    var leadingIconAssetName: String {
        switch self {
        case .activity(let activity):
            activity.iconAssetName ?? "PulseStatusIcon"
        case .clipboard(let reminder):
            reminder.iconAssetName
        }
    }

    var leadingTint: Color {
        switch self {
        case .activity(let activity):
            activity.tint
        case .clipboard(let reminder):
            reminder.tint
        }
    }

    var transitionIdentity: IslandActivityTransitionIdentity {
        switch self {
        case .activity(let activity):
            activity.transitionIdentity
        case .clipboard(let reminder):
            IslandActivityTransitionIdentity(
                activity: AnyHashable(reminder.id),
                iconAssetName: reminder.iconAssetName
            )
        }
    }
}

private struct ClipboardIslandReminder: Equatable, Identifiable {
    var id: UUID
    var kind: ClipboardContentKind
    var title: String
    var copyLabel: String
    var confirmationTitle: String

    init(notice: ClipboardHistoryRecordNotice, strings: PulseStrings) {
        self.id = notice.id
        self.kind = notice.kind
        self.title = strings.clipboardKind(notice.kind)
        self.copyLabel = strings.text(.copied)
        self.confirmationTitle = strings.text(.clipboardRecorded)
    }

    var iconAssetName: String {
        kind.islandReminderIconAssetName
    }

    var confirmationIconAssetName: String {
        "IslandClipboardSavedIcon"
    }

    var tint: Color {
        .white
    }

    var confirmationTint: Color {
        .green
    }
}

private extension ClipboardContentKind {
    var islandReminderIconAssetName: String {
        switch self {
        case .text:
            "ClipboardTextFilterIcon"
        case .url:
            "ClipboardLinkFilterIcon"
        case .file:
            "ClipboardFileFilterIcon"
        case .image:
            "ClipboardImageFilterIcon"
        case .mixed, .data:
            "IslandClipboardIcon"
        }
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
    var selectedModule: PulseIslandModule
    var moduleTitle: (PulseIslandModule) -> String
    var deviceName: String
    var rowHeight: CGFloat
    var settingsTitle: String
    var settingsHelp: String
    var settingsAction: () -> Void
    var quitTitle: String
    var quitHelp: String
    var quitAction: () -> Void
    var itemWidths: [PulseIslandModule: CGFloat]
    var updateItemWidths: ([PulseIslandModule: CGFloat]) -> Void
    var selectModule: (PulseIslandModule) -> Void

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

            IslandModuleSelector(
                selectedModule: selectedModule,
                moduleTitle: moduleTitle,
                itemWidths: itemWidths,
                updateItemWidths: updateItemWidths,
                selectModule: selectModule
            )
            .frame(height: rowHeight, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }
}

private struct IslandModuleSelector: View {
    var selectedModule: PulseIslandModule
    var moduleTitle: (PulseIslandModule) -> String
    var itemWidths: [PulseIslandModule: CGFloat]
    var updateItemWidths: ([PulseIslandModule: CGFloat]) -> Void
    var selectModule: (PulseIslandModule) -> Void

    private let modules = PulseIslandModule.allCases

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                HStack(spacing: moduleSelectorItemSpacing) {
                    ForEach(modules, id: \.self) { module in
                        IslandModuleSelectorItem(
                            module: module,
                            title: moduleTitle(module),
                            isSelected: module == selectedModule,
                            selectAction: {
                                selectModule(module)
                            }
                        )
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(height: proxy.size.height)
                        .background {
                            GeometryReader { itemProxy in
                                Color.clear.preference(
                                    key: IslandModuleSelectorItemWidthPreferenceKey.self,
                                    value: [module: itemProxy.size.width]
                                )
                            }
                        }
                    }
                }
                .offset(x: horizontalOffset(in: proxy.size.width))
                .animation(moduleSwitchAnimation, value: selectedModule)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
        }
        .clipped()
        .onPreferenceChange(IslandModuleSelectorItemWidthPreferenceKey.self) { widths in
            updateItemWidths(widths)
        }
        .accessibilityElement(children: .contain)
    }

    private func horizontalOffset(in width: CGFloat) -> CGFloat {
        let selectedCenterX = PulseIslandModuleInteractionGeometry.itemCenterX(
            module: selectedModule,
            modules: modules,
            itemWidths: itemWidths
        )

        return width / 2 - selectedCenterX
    }
}

private struct IslandModuleSelectorItemWidthPreferenceKey: PreferenceKey {
    static var defaultValue: [PulseIslandModule: CGFloat] = [:]

    static func reduce(
        value: inout [PulseIslandModule: CGFloat],
        nextValue: () -> [PulseIslandModule: CGFloat]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}

private struct IslandModuleSelectorItem: View {
    var module: PulseIslandModule
    var title: String
    var isSelected: Bool
    var selectAction: () -> Void

    var body: some View {
        HStack(spacing: PulseDesign.Spacing.xs) {
            Image(module.iconAssetName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .accessibilityHidden(true)

            Text(title)
                .font(.system(.callout, design: .rounded, weight: isSelected ? .semibold : .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(.white.opacity(isSelected ? 0.94 : 0.54))
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            selectAction()
        }
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

enum PulseIslandModuleInteractionGeometry {
    static func switchOffset(forHorizontalDragTranslation translation: CGFloat) -> Int {
        translation < 0 ? 1 : -1
    }

    static func switchOffset(forHorizontalScrollDelta delta: CGFloat) -> Int {
        delta < 0 ? 1 : -1
    }

    static func isModuleSwitchRegion(
        point: CGPoint,
        bounds: CGRect,
        moduleRowHeight: CGFloat
    ) -> Bool {
        bounds.contains(point) && !isHeaderControlRegion(
            point: point,
            bounds: bounds,
            moduleRowHeight: moduleRowHeight
        )
    }

    static func module(
        at point: CGPoint,
        bounds: CGRect,
        selectedModule: PulseIslandModule,
        moduleRowHeight: CGFloat,
        itemWidths: [PulseIslandModule: CGFloat] = [:]
    ) -> PulseIslandModule? {
        guard
            point.y >= bounds.minY,
            point.y <= bounds.minY + moduleRowHeight
        else {
            return nil
        }

        let modules = PulseIslandModule.allCases
        let selectedCenterX = itemCenterX(
            module: selectedModule,
            modules: modules,
            itemWidths: itemWidths
        )
        let rowOffsetX = bounds.midX - selectedCenterX
        var cursor = rowOffsetX

        for (index, module) in modules.enumerated() {
            if index > 0 {
                cursor += moduleSelectorItemSpacing
            }

            let itemMinX = cursor
            let itemMaxX = itemMinX + itemWidth(for: module, itemWidths: itemWidths)
            guard point.x >= itemMinX, point.x <= itemMaxX else {
                cursor = itemMaxX
                continue
            }

            return module
        }

        return nil
    }

    static func itemCenterX(
        module selectedModule: PulseIslandModule,
        modules: [PulseIslandModule],
        itemWidths: [PulseIslandModule: CGFloat]
    ) -> CGFloat {
        var cursor: CGFloat = 0

        for (index, module) in modules.enumerated() {
            if index > 0 {
                cursor += moduleSelectorItemSpacing
            }

            let width = itemWidth(for: module, itemWidths: itemWidths)
            if module == selectedModule {
                return cursor + width / 2
            }

            cursor += width
        }

        return moduleSelectorFallbackItemWidth / 2
    }

    private static func itemWidth(
        for module: PulseIslandModule,
        itemWidths: [PulseIslandModule: CGFloat]
    ) -> CGFloat {
        itemWidths[module] ?? moduleSelectorFallbackItemWidth
    }

    private static func isHeaderControlRegion(
        point: CGPoint,
        bounds: CGRect,
        moduleRowHeight: CGFloat
    ) -> Bool {
        let controlWidth = PulseDesign.Control.buttonSide * 2 + PulseDesign.Spacing.xs
        let minX = bounds.maxX - PulseIslandLayout.expandedContentHorizontalPadding - controlWidth
        let minY = bounds.maxY - moduleRowHeight

        return point.x >= minX && point.y >= minY
    }
}

private struct IslandModuleInteractionBridge: NSViewRepresentable {
    var selectedModule: PulseIslandModule
    var moduleRowHeight: CGFloat
    var itemWidths: [PulseIslandModule: CGFloat]
    var switchAction: (Int) -> Void
    var selectAction: (PulseIslandModule) -> Void

    func makeNSView(context: Context) -> InteractionView {
        let view = InteractionView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        view.selectedModule = selectedModule
        view.moduleRowHeight = moduleRowHeight
        view.itemWidths = itemWidths
        view.switchAction = switchAction
        view.selectAction = selectAction
        return view
    }

    func updateNSView(_ nsView: InteractionView, context: Context) {
        nsView.selectedModule = selectedModule
        nsView.moduleRowHeight = moduleRowHeight
        nsView.itemWidths = itemWidths
        nsView.switchAction = switchAction
        nsView.selectAction = selectAction
    }

    final class InteractionView: NSView {
        var selectedModule: PulseIslandModule = .resourceMonitor
        var moduleRowHeight: CGFloat = PulseIslandLayout.expandedHeaderRowHeight
        var itemWidths: [PulseIslandModule: CGFloat] = [:]
        var switchAction: ((Int) -> Void)?
        var selectAction: ((PulseIslandModule) -> Void)?

        private var mouseDownPoint: CGPoint?
        private var didSwitchDuringMouseDown = false
        private var didSwitchDuringScrollGesture = false
        private var accumulatedScrollDeltaX: CGFloat = 0
        private var lastScrollSwitchTime: TimeInterval = 0
        private var localEventMonitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()

            if window == nil {
                removeLocalEventMonitor()
            } else {
                installLocalEventMonitorIfNeeded()
            }
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }

        private func installLocalEventMonitorIfNeeded() {
            guard localEventMonitor == nil else {
                return
            }

            localEventMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp, .scrollWheel]
            ) { [weak self] event in
                self?.handleLocalEvent(event) ?? event
            }
        }

        private func removeLocalEventMonitor() {
            guard let localEventMonitor else {
                return
            }

            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }

        private func handleLocalEvent(_ event: NSEvent) -> NSEvent? {
            guard event.window === window else {
                return event
            }

            let point = convert(event.locationInWindow, from: nil)

            switch event.type {
            case .leftMouseDown:
                handleMouseDown(at: point)
                return event
            case .leftMouseDragged:
                return handleMouseDragged(at: point) ? nil : event
            case .leftMouseUp:
                handleMouseUp(at: point)
                return event
            case .scrollWheel:
                return handleScrollWheel(event, at: point) ? nil : event
            default:
                return event
            }
        }

        private func handleMouseDown(at point: CGPoint) {
            guard isModuleSwitchRegion(point) else {
                mouseDownPoint = nil
                didSwitchDuringMouseDown = false
                return
            }

            mouseDownPoint = point
            didSwitchDuringMouseDown = false
        }

        private func handleMouseDragged(at point: CGPoint) -> Bool {
            guard let mouseDownPoint, !didSwitchDuringMouseDown else {
                return false
            }

            let translation = CGSize(
                width: point.x - mouseDownPoint.x,
                height: point.y - mouseDownPoint.y
            )

            guard
                abs(translation.width) >= abs(translation.height),
                abs(translation.width) >= moduleSwitchHorizontalDragThreshold
            else {
                return false
            }

            switchAction?(PulseIslandModuleInteractionGeometry.switchOffset(
                forHorizontalDragTranslation: translation.width
            ))
            didSwitchDuringMouseDown = true
            return true
        }

        private func handleMouseUp(at point: CGPoint) {
            defer {
                mouseDownPoint = nil
                didSwitchDuringMouseDown = false
            }

            guard let mouseDownPoint, !didSwitchDuringMouseDown else {
                return
            }

            let movement = hypot(point.x - mouseDownPoint.x, point.y - mouseDownPoint.y)
            guard movement <= moduleSelectorClickMovementTolerance else {
                return
            }

            if let module = module(at: point) {
                selectAction?(module)
            }
        }

        private func module(at point: CGPoint) -> PulseIslandModule? {
            PulseIslandModuleInteractionGeometry.module(
                at: point,
                bounds: bounds,
                selectedModule: selectedModule,
                moduleRowHeight: moduleRowHeight,
                itemWidths: itemWidths
            )
        }

        private func isModuleSwitchRegion(_ point: CGPoint) -> Bool {
            PulseIslandModuleInteractionGeometry.isModuleSwitchRegion(
                point: point,
                bounds: bounds,
                moduleRowHeight: moduleRowHeight
            )
        }

        private func handleScrollWheel(_ event: NSEvent, at point: CGPoint) -> Bool {
            guard isModuleSwitchRegion(point) else {
                resetScrollGesture()
                return false
            }

            if event.phase.contains(.began) || event.phase.contains(.mayBegin) {
                resetScrollGesture()
            }

            guard event.momentumPhase.isEmpty else {
                if event.momentumPhase.contains(.ended) || event.momentumPhase.contains(.cancelled) {
                    resetScrollGesture()
                }
                return true
            }

            let endsScrollGesture = event.phase.contains(.ended) || event.phase.contains(.cancelled)
            defer {
                if endsScrollGesture {
                    resetScrollGesture()
                }
            }

            let deltaX = event.scrollingDeltaX
            guard
                abs(deltaX) >= abs(event.scrollingDeltaY),
                abs(deltaX) > 0
            else {
                return false
            }

            let isPhasedGesture = !event.phase.isEmpty
            guard shouldAcceptScrollSwitch(isPhasedGesture: isPhasedGesture) else {
                return true
            }

            accumulatedScrollDeltaX += deltaX

            guard abs(accumulatedScrollDeltaX) >= moduleSwitchHorizontalScrollThreshold else {
                return true
            }

            switchAction?(PulseIslandModuleInteractionGeometry.switchOffset(
                forHorizontalScrollDelta: accumulatedScrollDeltaX
            ))
            didSwitchDuringScrollGesture = isPhasedGesture
            lastScrollSwitchTime = ProcessInfo.processInfo.systemUptime
            accumulatedScrollDeltaX = 0
            return true
        }

        private func shouldAcceptScrollSwitch(isPhasedGesture: Bool) -> Bool {
            if isPhasedGesture {
                return !didSwitchDuringScrollGesture
            }

            return ProcessInfo.processInfo.systemUptime - lastScrollSwitchTime >= moduleSwitchInputLockDuration
        }

        private func resetScrollGesture() {
            didSwitchDuringScrollGesture = false
            accumulatedScrollDeltaX = 0
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
