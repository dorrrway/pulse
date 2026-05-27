import AppKit
import SwiftUI

enum PulsePanelPresentation {
    case pinned
    case island
}

private struct PulsePanelPresentationKey: EnvironmentKey {
    static let defaultValue: PulsePanelPresentation = .pinned
}

private struct PulsePanelIsPinnedKey: EnvironmentKey {
    static let defaultValue = false
}

private struct PulsePanelPinActionKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var pulsePanelPresentation: PulsePanelPresentation {
        get { self[PulsePanelPresentationKey.self] }
        set { self[PulsePanelPresentationKey.self] = newValue }
    }

    var pulsePanelIsPinned: Bool {
        get { self[PulsePanelIsPinnedKey.self] }
        set { self[PulsePanelIsPinnedKey.self] = newValue }
    }

    var pulsePanelPinAction: () -> Void {
        get { self[PulsePanelPinActionKey.self] }
        set { self[PulsePanelPinActionKey.self] = newValue }
    }
}

enum PanelControlIcon {
    static let pin = "PanelPinIcon"
    static let pinFilled = "PanelPinFilledIcon"
    static let expand = "PanelExpandIcon"
    static let minimize = "PanelMinimizeIcon"
    static let runtimePulse = "RuntimePulseIcon"
}

struct PanelControlIconImage: View {
    var name: String
    var side: CGFloat

    var body: some View {
        Image(name)
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .frame(width: side, height: side)
            .accessibilityHidden(true)
    }
}

private struct PanelIconButton: View {
    private enum Layout {
        static let side: CGFloat = PulseDesign.Control.buttonSide
        static let iconFrameSide: CGFloat = PulseDesign.Control.iconFrameSide
        static let iconSide: CGFloat = PulseDesign.Control.iconSide
        static let cornerRadius: CGFloat = PulseDesign.Radius.control
    }

    var iconName: String
    var action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if isHovering {
                    RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
                        .fill(.primary.opacity(PulseDesign.Opacity.hoverFill))
                }

                PanelControlIconImage(name: iconName, side: Layout.iconSide)
                    .frame(width: Layout.iconFrameSide, height: Layout.iconFrameSide)
            }
            .frame(width: Layout.side, height: Layout.side)
            .contentShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
            .animation(.easeOut(duration: 0.12), value: isHovering)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct PulsePanelView: View {
    var style: PulsePanelStyle = .full
    var collapseAction: () -> Void = {}
    var expandAction: () -> Void = {}

    @Environment(PulseStore.self) private var store
    @Environment(\.pulsePanelPresentation) private var presentation
    @Environment(\.pulsePanelIsPinned) private var isPinned
    @Environment(\.pulsePanelPinAction) private var pinAction
    @Environment(PulseUpdateController.self) private var updateController
    @State private var isMinimalRestoreVisible = false

    var body: some View {
        let strings = store.strings

        panelContent(strings: strings)
            .background {
                panelBackground
            }
            .clipShape(panelShape)
            .overlay(alignment: .top) {
                if presentation == .pinned && style == .full {
                    Color.clear
                        .frame(height: PulsePanelLayout.dragRegionHeight)
                        .contentShape(Rectangle())
                        .gesture(WindowDragGesture())
                        .allowsWindowActivationEvents(true)
                }
            }
    }

    @ViewBuilder
    private func panelContent(strings: PulseStrings) -> some View {
        switch style {
        case .full:
            fullPanel(strings: strings)
        case .minimal:
            minimalPanel(strings: strings)
        }
    }

    private func fullPanel(strings: PulseStrings) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            coreMetrics(strings: strings)
            processLeaders(strings: strings)
                .padding(.top, PulsePanelLayout.sectionSpacing)

            signalGrid(strings: strings)
                .padding(.top, PulsePanelLayout.sectionSpacing)

            footer
                .padding(.top, PulsePanelLayout.footerTopSpacing)
        }
        .padding(.horizontal, PulsePanelLayout.outerPadding)
        .padding(.top, PulsePanelLayout.outerPadding)
        .padding(.bottom, PulsePanelLayout.footerBottomPadding)
        .frame(
            width: fullPanelContentWidth,
            height: PulsePanelLayout.contentHeight,
            alignment: .top
        )
    }

    private func minimalPanel(strings: PulseStrings) -> some View {
        MinimalMetricsContent(strings: strings)
        .padding(PulsePanelLayout.outerPadding)
        .frame(
            width: PulsePanelLayout.minimalContentWidth,
            height: PulsePanelLayout.minimalContentHeight,
            alignment: .topLeading
        )
        .overlay(alignment: .bottomTrailing) {
            if isMinimalRestoreVisible {
                Button(action: expandAction) {
                    PanelControlIconImage(name: PanelControlIcon.expand, side: 18)
                        .frame(width: 26, height: 26)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                .background(.regularMaterial, in: Circle())
                .shadow(color: .black.opacity(0.16), radius: 6, x: 0, y: 2)
                .padding(8)
                .help(strings.text(.expandPanel))
                .accessibilityLabel(strings.text(.expandPanel))
                .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .bottomTrailing)))
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(WindowDragGesture())
        .onTapGesture(count: 2, perform: expandAction)
        .onHover { isHovering in
            withAnimation(.easeOut(duration: 0.14)) {
                isMinimalRestoreVisible = isHovering
            }
        }
        .contextMenu {
            Button(strings.text(.expandPanel), action: expandAction)
            Button(strings.text(.unpinPanel), action: pinAction)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(strings.text(.minimalPanel))
    }

    private var panelShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: PulsePanelLayout.panelCornerRadius,
            style: .continuous
        )
    }

    @ViewBuilder
    private var panelBackground: some View {
        if presentation != .island {
            panelShape.fill(.regularMaterial)
        }
    }

    private var fullPanelContentWidth: CGFloat {
        switch presentation {
        case .island:
            PulseIslandLayout.attachedPanelSize.width
        case .pinned:
            PulsePanelLayout.contentWidth
        }
    }

    private var footer: some View {
        let strings = store.strings

        return HStack {
            PanelIconButton(
                iconName: isPinned ? PanelControlIcon.pinFilled : PanelControlIcon.pin,
                action: togglePinnedPanel
            )
            .labelStyle(.iconOnly)
            .help(strings.text(isPinned ? .unpinPanel : .pinPanel))
            .accessibilityLabel(strings.text(isPinned ? .unpinPanel : .pinPanel))

            if let update = updateController.availableUpdate {
                Button {
                    updateController.installAvailableUpdate()
                } label: {
                    Text(strings.updateButtonTitle())
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .environment(\.controlActiveState, .key)
                .disabled(!updateController.canCheckForUpdates)
                .help(strings.updateButtonHelp(version: update.version))
            }

            Spacer()

            if presentation == .island {
                Text(store.capturedAt, style: .time)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            if presentation == .pinned {
                PanelIconButton(iconName: PanelControlIcon.minimize, action: collapseAction)
                .labelStyle(.iconOnly)
                .help(strings.text(.minimalPanel))
                .accessibilityLabel(strings.text(.minimalPanel))
            }
        }
        .frame(height: PulsePanelLayout.footerHeight, alignment: .center)
    }

    private func togglePinnedPanel() {
        pinAction()

        if presentation == .island {
            collapseAction()
        }
    }

    private func coreMetrics(strings: PulseStrings) -> some View {
        CoreMetricsSection(strings: strings)
    }

    private func signalGrid(strings: PulseStrings) -> some View {
        SignalGridSection(strings: strings)
    }

    private func processLeaders(strings: PulseStrings) -> some View {
        ProcessLeadersView(strings: strings)
    }
}

private struct MinimalMetricsContent: View {
    var strings: PulseStrings

    @Environment(PulseStore.self) private var store

    var body: some View {
        let metrics = store.coreMetrics
        let networkBytesPerSecond = metrics.network.incomingBytesPerSecond
            + metrics.network.outgoingBytesPerSecond

        VStack(alignment: .leading, spacing: PulsePanelLayout.metricRowSpacing) {
            MetricGraphBlock(
                title: strings.text(.cpu),
                tint: .cyan,
                progress: metrics.cpu.percentage,
                accessibilityValue: ResourceFormatters.percentage(metrics.cpu.percentage)
            )

            MetricGraphBlock(
                title: strings.text(.memory),
                tint: .green,
                progress: metrics.memory.percentage,
                accessibilityValue: ResourceFormatters.percentage(metrics.memory.percentage)
            )

            MetricGraphBlock(
                title: strings.text(.network),
                tint: .indigo,
                progress: ResourceScales.networkActivityProgress(bytesPerSecond: networkBytesPerSecond),
                accessibilityValue: ResourceFormatters.byteRate(bytesPerSecond: networkBytesPerSecond)
            )

            MetricGraphBlock(
                title: strings.text(.disk),
                tint: .orange,
                progress: metrics.disk.percentage,
                accessibilityValue: ResourceFormatters.percentage(metrics.disk.percentage)
            )
        }
    }
}

private struct CoreMetricsSection: View {
    var strings: PulseStrings

    @Environment(PulseStore.self) private var store
    @Environment(\.pulsePanelPresentation) private var presentation

    var body: some View {
        let metrics = store.coreMetrics

        VStack(spacing: PulsePanelLayout.metricRowSpacing) {
            MetricRow(
                title: strings.text(.cpu),
                value: ResourceFormatters.percentage(metrics.cpu.percentage),
                detail: strings.cores(metrics.cpu.coreCount),
                tint: .cyan,
                progress: metrics.cpu.percentage,
                meterColumns: meterColumns
            )

            MetricRow(
                title: strings.text(.memory),
                value: ResourceFormatters.percentage(metrics.memory.percentage),
                detail: strings.memoryDetail(
                    used: ResourceFormatters.byteString(bytes: metrics.memory.usedBytes),
                    total: ResourceFormatters.byteString(bytes: metrics.memory.totalBytes)
                ),
                tint: .green,
                progress: metrics.memory.percentage,
                meterColumns: meterColumns
            )

            MetricRow(
                title: strings.text(.network),
                value: ResourceFormatters.byteRate(bytesPerSecond: metrics.network.incomingBytesPerSecond),
                detail: strings.networkUploadDetail(
                    rate: ResourceFormatters.byteRate(bytesPerSecond: metrics.network.outgoingBytesPerSecond)
                ),
                tint: .indigo,
                progress: ResourceScales.networkActivityProgress(
                    bytesPerSecond: metrics.network.incomingBytesPerSecond + metrics.network.outgoingBytesPerSecond
                ),
                meterColumns: meterColumns
            )

            MetricRow(
                title: strings.text(.disk),
                value: ResourceFormatters.percentage(metrics.disk.percentage),
                detail: strings.diskFreeDetail(ResourceFormatters.storageByteString(bytes: metrics.disk.availableBytes)),
                tint: .orange,
                progress: metrics.disk.percentage,
                meterColumns: meterColumns
            )
        }
        .frame(height: PulsePanelLayout.coreMetricsHeight)
    }

    private var meterColumns: Int {
        presentation == .island ? 32 : 18
    }
}

private struct SignalGridSection: View {
    var strings: PulseStrings

    @Environment(PulseStore.self) private var store

    var body: some View {
        let metrics = store.signalMetrics
        let memoryPressureColor = SignalStatusColor.memoryPressure(metrics.memory.pressureLevel)
        let thermalColor = SignalStatusColor.thermal(metrics.thermal.condition)
        let powerColor = SignalStatusColor.power(metrics.power)
        let diskIOColor = SignalStatusColor.diskIO(metrics.diskIO)

        VStack(spacing: PulsePanelLayout.signalSpacing) {
            HStack(spacing: PulsePanelLayout.signalSpacing) {
                SignalCard(
                    title: strings.text(.memoryPressure),
                    value: strings.pressure(metrics.memory.pressureLevel),
                    detail: strings.pressureDetail(metrics.memory),
                    helpText: strings.pressureExplanation(metrics.memory),
                    tint: memoryPressureColor
                )

                SignalCard(
                    title: strings.text(.thermal),
                    value: strings.thermal(metrics.thermal.condition),
                    detail: strings.thermalDetail(metrics.thermal),
                    helpText: strings.thermalExplanation(metrics.thermal),
                    tint: thermalColor
                )
            }
            .frame(height: PulsePanelLayout.signalCardHeight)

            HStack(spacing: PulsePanelLayout.signalSpacing) {
                SignalCard(
                    title: strings.text(.power),
                    value: strings.powerTitle(metrics.power),
                    detail: strings.powerDetail(metrics.power),
                    helpText: strings.powerExplanation(metrics.power),
                    tint: powerColor,
                    isTintBreathing: SignalStatusColor.powerIsBreathing(metrics.power)
                )

                SignalCard(
                    title: strings.text(.diskIO),
                    value: "\(strings.text(.read)) \(ResourceFormatters.byteRate(bytesPerSecond: metrics.diskIO.readBytesPerSecond))",
                    detail: "\(strings.text(.write)) \(ResourceFormatters.byteRate(bytesPerSecond: metrics.diskIO.writeBytesPerSecond))",
                    helpText: strings.diskIOExplanation(metrics.diskIO),
                    tint: diskIOColor
                )
            }
            .frame(height: PulsePanelLayout.signalCardHeight)

            RuntimeSummaryRow(
                title: strings.text(.systemRuntime),
                text: strings.runtimeSummary(metrics.runtime),
                tint: .cyan
            )
            .frame(height: PulsePanelLayout.runtimeRowHeight)
        }
        .frame(height: PulsePanelLayout.signalGridHeight)
    }
}

private struct ProcessLeadersView: View {
    var strings: PulseStrings

    @Environment(PulseStore.self) private var store

    var body: some View {
        let processLeaders = store.processLeaders

        VStack(alignment: .leading, spacing: PulsePanelLayout.processSectionSpacing) {
            ProcessUsageSection(
                title: strings.text(.topCPUProcesses),
                entries: processLeaders.topCPU,
                emptyText: strings.text(.collecting),
                value: { ResourceFormatters.processPercentage($0.cpuPercentage) },
                valueColor: { ProcessUsageValueColor.cpu(for: $0.cpuPercentage) },
                nameColor: { ProcessUsageValueColor.cpu(for: $0.cpuPercentage) },
                share: \.cpuPercentage
            )

            ProcessUsageSection(
                title: strings.text(.topMemoryProcesses),
                entries: processLeaders.topMemory,
                emptyText: strings.text(.collecting),
                value: { ResourceFormatters.byteString(bytes: $0.memoryBytes) },
                share: { Double(max($0.memoryBytes, 0)) }
            )
        }
        .frame(height: PulsePanelLayout.processLeadersHeight)
    }
}

private struct MetricRow: View {
    private enum Layout {
        static let rowHeight: CGFloat = 36
        static let valueColumnWidth: CGFloat = 104
        static let detailColumnWidth: CGFloat = 128
        static let valueSpacing: CGFloat = 8
        static let groupSpacing: CGFloat = 12
    }

    var title: String
    var value: String
    var detail: String
    var tint: Color
    var progress: Double
    var meterColumns: Int

    var body: some View {
        HStack(alignment: .center, spacing: Layout.groupSpacing) {
            VStack(alignment: .leading, spacing: PulseDesign.Spacing.fine) {
                Text(title)
                    .font(PulseDesign.Typography.panelBody)
                    .lineLimit(1)

                PixelMeter(value: progress, tint: tint, columns: meterColumns)
                    .accessibilityLabel("\(title) \(value)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .firstTextBaseline, spacing: Layout.valueSpacing) {
                Text(value)
                    .font(PulseDesign.Typography.panelLargeValue)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(width: Layout.valueColumnWidth, alignment: .trailing)

                Text(detail)
                    .font(PulseDesign.Typography.panelValue)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(width: Layout.detailColumnWidth, alignment: .trailing)
            }
        }
        .frame(height: Layout.rowHeight)
    }
}

private struct MetricGraphBlock: View {
    var title: String
    var tint: Color
    var progress: Double
    var accessibilityValue: String

    var body: some View {
        VStack(alignment: .leading, spacing: PulseDesign.Spacing.fine) {
            Text(title)
                .font(PulseDesign.Typography.panelBody)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            PixelMeter(value: progress, tint: tint)
        }
        .frame(width: PulsePanelLayout.minimalMetricGraphWidth, height: PulsePanelLayout.metricRowHeight, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(accessibilityValue)
    }
}

private struct SignalCard: View {
    var title: String
    var value: String
    var detail: String
    var helpText: String
    var tint: Color
    var isTintBreathing = false

    var body: some View {
        VStack(alignment: .leading, spacing: PulseDesign.Spacing.fine - PulseDesign.Spacing.hairline) {
            HStack(spacing: PulseDesign.Spacing.fine) {
                SignalLegendDot(tint: tint, isBreathing: isTintBreathing)

                Text(title)
                    .font(PulseDesign.Typography.panelLabel)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Text(value)
                .font(PulseDesign.Typography.panelValue)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Text(detail)
                .font(PulseDesign.Typography.panelDetail)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(PulseDesign.Spacing.compact)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: PulseDesign.Radius.card, style: .continuous))
        .help(helpText)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(helpText)
    }
}

private struct RuntimeSummaryRow: View {
    private enum Layout {
        static let iconSide: CGFloat = 14
    }

    var title: String
    var text: String
    var tint: Color

    var body: some View {
        HStack(alignment: .center, spacing: PulseDesign.Spacing.xs) {
            PanelControlIconImage(name: PanelControlIcon.runtimePulse, side: Layout.iconSide)
                .foregroundStyle(tint)

            Text(text)
                .font(PulseDesign.Typography.panelValue)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, PulseDesign.Spacing.compact)
        .padding(.vertical, PulseDesign.Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: PulseDesign.Radius.card, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(text)
    }
}

enum SignalStatusColor {
    private static let activeDiskIOThresholdBytesPerSecond: Double = 50_000_000

    static func memoryPressure(_ level: PressureLevel) -> Color {
        switch level {
        case .nominal:
            return .green
        case .elevated:
            return .yellow
        case .high:
            return .orange
        }
    }

    static func thermal(_ condition: ThermalCondition) -> Color {
        switch condition {
        case .nominal:
            return .green
        case .fair:
            return .yellow
        case .serious:
            return .orange
        case .critical:
            return .red
        }
    }

    static func power(_ usage: PowerUsage) -> Color {
        guard usage.hasBattery else {
            return .green
        }

        guard !usage.isPluggedIn else {
            return .green
        }

        guard let percentage = usage.batteryPercentage else {
            return .green
        }

        if percentage <= 0.1 {
            return .red
        }

        if percentage <= 0.2 {
            return .orange
        }

        if percentage < 0.4 {
            return .yellow
        }

        return .green
    }

    static func powerIsBreathing(_ usage: PowerUsage) -> Bool {
        usage.hasBattery && usage.isPluggedIn && usage.isCharging
    }

    static func bluetoothBattery(_ alert: BluetoothBatteryAlert) -> Color {
        switch alert.severity {
        case .critical:
            return .red
        case .low:
            return .orange
        }
    }

    static func diskIO(_ usage: DiskIOUsage) -> Color {
        let totalBytesPerSecond = max(usage.readBytesPerSecond, 0) + max(usage.writeBytesPerSecond, 0)
        return totalBytesPerSecond >= activeDiskIOThresholdBytesPerSecond ? .purple : .blue
    }
}

private struct SignalLegendDot: View {
    var tint: Color
    var isBreathing = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBright = true

    var body: some View {
        Circle()
            .fill(tint.opacity(opacity))
            .frame(width: 8, height: 8)
            .animation(animation, value: isBright)
            .onAppear(perform: updateBreathing)
            .onChange(of: isBreathing) { _, _ in
                updateBreathing()
            }
            .onChange(of: reduceMotion) { _, _ in
                updateBreathing()
            }
            .accessibilityHidden(true)
    }

    private var opacity: Double {
        isBreathing && !reduceMotion && !isBright ? 0.45 : 1
    }

    private var animation: Animation? {
        guard isBreathing && !reduceMotion else {
            return nil
        }

        return .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
    }

    private func updateBreathing() {
        guard isBreathing && !reduceMotion else {
            isBright = true
            return
        }

        isBright = false
    }
}

private struct ProcessUsageSection: View {
    private enum Layout {
        static let chartSide: CGFloat = 62
        static let visibleRowLimit = 3
        static let titleLineHeight: CGFloat = 14
        static let titleToRowsSpacing: CGFloat = 6
        static let rowHeight: CGFloat = 18
        static let rowSpacing: CGFloat = 4
    }

    var title: String
    var entries: [ProcessResourceUsage]
    var emptyText: String
    var value: (ProcessResourceUsage) -> String
    var valueColor: (ProcessResourceUsage) -> Color = { _ in .secondary }
    var nameColor: (ProcessResourceUsage) -> Color = { _ in .primary }
    var share: (ProcessResourceUsage) -> Double

    var body: some View {
        let visibleEntries = Array(entries.prefix(Layout.visibleRowLimit))

        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: Layout.titleToRowsSpacing) {
                Text(title)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: false, vertical: true)

                if entries.isEmpty {
                    Text(emptyText)
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(height: Layout.chartSide, alignment: .topLeading)
                } else {
                    VStack(spacing: Layout.rowSpacing) {
                        ForEach(Array(visibleEntries.enumerated()), id: \.element.id) { index, usage in
                            ProcessUsageRow(
                                color: ProcessUsagePalette.color(at: index),
                                name: usage.name,
                                appBundlePath: usage.appBundlePath,
                                value: value(usage),
                                valueColor: valueColor(usage),
                                nameColor: nameColor(usage),
                                height: Layout.rowHeight
                            )
                        }
                    }
                    .frame(height: Layout.chartSide, alignment: .center)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !entries.isEmpty {
                ProcessUsageShareChart(title: title, entries: entries, share: share, emptyText: emptyText)
                    .frame(width: Layout.chartSide, height: Layout.chartSide)
                    .padding(.top, Layout.titleLineHeight + Layout.titleToRowsSpacing)
            }
        }
        .frame(height: Layout.chartSide + Layout.titleLineHeight + Layout.titleToRowsSpacing)
    }
}

private struct ProcessUsageRow: View {
    var color: Color
    var name: String
    var appBundlePath: String?
    var value: String
    var valueColor: Color
    var nameColor: Color
    var height: CGFloat

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            ProcessUsageLeadingIcon(color: color, appBundlePath: appBundlePath)

            Text(name)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(nameColor)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 8)

            Text(value)
                .font(.system(.caption, design: .monospaced, weight: .semibold))
                .foregroundStyle(valueColor)
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(height: height)
    }
}

private enum ProcessUsageValueColor {
    private static let elevatedCPUThreshold = 1.0
    private static let highCPUThreshold = 2.0

    static func cpu(for cpuPercentage: Double) -> Color {
        if cpuPercentage >= highCPUThreshold {
            return .orange
        }

        if cpuPercentage >= elevatedCPUThreshold {
            return .yellow
        }

        return .secondary
    }
}

private struct ProcessUsageLeadingIcon: View {
    var color: Color
    var appBundlePath: String?

    var body: some View {
        Group {
            if let icon = ProcessIconCache.shared.icon(forBundlePath: appBundlePath) {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            } else {
                Rectangle()
                    .fill(color)
                    .frame(width: 8, height: 8)
            }
        }
        .frame(width: 14, height: 14)
        .accessibilityHidden(true)
    }
}

@MainActor
private final class ProcessIconCache {
    static let shared = ProcessIconCache()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 64
    }

    func icon(forBundlePath appBundlePath: String?) -> NSImage? {
        guard let appBundlePath else {
            return nil
        }

        let key = appBundlePath as NSString
        if let icon = cache.object(forKey: key) {
            return icon
        }

        let icon = NSWorkspace.shared.icon(forFile: appBundlePath)
        cache.setObject(icon, forKey: key)
        return icon
    }
}

private struct ProcessUsageShareChart: View {
    var title: String
    var entries: [ProcessResourceUsage]
    var share: (ProcessResourceUsage) -> Double
    var emptyText: String

    private static let gridSize = 11
    private static let cellSpacing: CGFloat = 1
    @State private var isDetailPresented = false

    private var slices: [ProcessUsageShareSlice] {
        ProcessUsageShareSlice.make(from: entries, share: share)
    }

    var body: some View {
        Button {
            isDetailPresented.toggle()
        } label: {
            GeometryReader { proxy in
                let side = min(proxy.size.width, proxy.size.height)
                let cellSize = (side - CGFloat(Self.gridSize - 1) * Self.cellSpacing) / CGFloat(Self.gridSize)

                VStack(spacing: Self.cellSpacing) {
                    ForEach(0..<Self.gridSize, id: \.self) { row in
                        HStack(spacing: Self.cellSpacing) {
                            ForEach(0..<Self.gridSize, id: \.self) { column in
                                Rectangle()
                                    .fill(color(row: row, column: column))
                                    .frame(width: cellSize, height: cellSize)
                                    .opacity(isInsideDisc(row: row, column: column) ? 1 : 0)
                            }
                        }
                    }
                }
                .frame(width: side, height: side)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .help(helpText)
        .popover(isPresented: $isDetailPresented, arrowEdge: .trailing) {
            ProcessUsageShareDetailPopover(title: title, slices: slices, emptyText: emptyText)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entries.map(\.name).joined(separator: ", "))
        .accessibilityValue(helpText)
        .accessibilityAddTraits(.isButton)
    }

    private func isInsideDisc(row: Int, column: Int) -> Bool {
        let center = (Double(Self.gridSize) - 1) / 2
        let dx = Double(column) - center
        let dy = Double(row) - center
        let radius = Double(Self.gridSize) / 2

        return dx * dx + dy * dy <= radius * radius
    }

    private func color(row: Int, column: Int) -> Color {
        guard isInsideDisc(row: row, column: column),
              let sliceIndex = sliceIndex(row: row, column: column) else {
            return ProcessUsagePalette.inactive
        }

        return ProcessUsagePalette.color(at: sliceIndex)
    }

    private func sliceIndex(row: Int, column: Int) -> Int? {
        guard !slices.isEmpty else {
            return nil
        }

        let center = (Double(Self.gridSize) - 1) / 2
        let dx = Double(column) - center
        let dy = Double(row) - center
        var degrees = atan2(dy, dx) * 180 / .pi

        if degrees < -90 {
            degrees += 360
        }

        return slices.firstIndex { slice in
            degrees >= slice.startDegrees && degrees < slice.endDegrees
        } ?? slices.indices.last
    }

    private var helpText: String {
        guard !slices.isEmpty else {
            return emptyText
        }

        let total = slices.reduce(0) { $0 + $1.value }
        guard total > 0 else {
            return emptyText
        }

        return slices.map { slice in
            let percent = slice.value / total * 100
            return "\(slice.name) \(percent.formatted(.number.precision(.fractionLength(0))))%"
        }
        .joined(separator: "\n")
    }
}

private struct ProcessUsageShareSlice: Identifiable, Hashable {
    let id: Int
    let name: String
    let value: Double
    let startDegrees: Double
    let endDegrees: Double

    static func make(
        from entries: [ProcessResourceUsage],
        share: (ProcessResourceUsage) -> Double
    ) -> [ProcessUsageShareSlice] {
        let values = entries.enumerated()
            .map { index, entry in
                (id: index, name: entry.name, value: max(share(entry), 0))
            }
            .filter { $0.value > 0 }

        let total = values.reduce(0) {
            $0 + $1.value
        }

        guard total > 0 else {
            return []
        }

        var cursor = -90.0
        return values.map { value in
            let angle = value.value / total * 360.0
            defer { cursor += angle }

            return ProcessUsageShareSlice(
                id: value.id,
                name: value.name,
                value: value.value,
                startDegrees: cursor,
                endDegrees: cursor + angle
            )
        }
    }
}

private struct ProcessUsageShareDetailPopover: View {
    var title: String
    var slices: [ProcessUsageShareSlice]
    var emptyText: String

    private var total: Double {
        slices.reduce(0) { $0 + $1.value }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if slices.isEmpty {
                Text(emptyText)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(slices.enumerated()), id: \.element.id) { index, slice in
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(ProcessUsagePalette.color(at: index))
                                .frame(width: 10, height: 10)
                                .accessibilityHidden(true)

                            Text(slice.name)
                                .font(.system(.caption, design: .rounded, weight: .medium))
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer(minLength: 12)

                            Text(percentText(for: slice))
                                .font(.system(.caption, design: .monospaced, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 220, alignment: .leading)
    }

    private func percentText(for slice: ProcessUsageShareSlice) -> String {
        guard total > 0 else {
            return "0%"
        }

        let percent = slice.value / total * 100
        return "\(percent.formatted(.number.precision(.fractionLength(0))))%"
    }
}

private enum ProcessUsagePalette {
    static let inactive = Color.secondary.opacity(0.16)

    static func color(at index: Int) -> Color {
        switch index {
        case 0:
            Color(red: 0.22, green: 0.55, blue: 0.86).opacity(0.92)
        case 1:
            Color(red: 0.42, green: 0.62, blue: 0.38).opacity(0.92)
        case 2:
            Color(red: 0.52, green: 0.46, blue: 0.78).opacity(0.92)
        case 3:
            Color(red: 0.86, green: 0.62, blue: 0.28).opacity(0.92)
        case 4:
            Color(red: 0.56, green: 0.58, blue: 0.60).opacity(0.92)
        default:
            Color.secondary.opacity(0.72)
        }
    }
}

#Preview {
    PulsePanelView()
        .environment(PulseStore())
        .environment(PulseUpdateController(startingUpdater: false))
}
