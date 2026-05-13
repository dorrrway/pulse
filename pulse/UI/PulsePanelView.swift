import AppKit
import SwiftUI

enum PulsePanelPresentation {
    case menuBar
    case pinned
}

private struct PulsePanelPresentationKey: EnvironmentKey {
    static let defaultValue: PulsePanelPresentation = .menuBar
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

private struct PulsePanelWindowReader: NSViewRepresentable {
    var onResolve: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        resolveWindow(for: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        resolveWindow(for: nsView)
    }

    private func resolveWindow(for view: NSView) {
        DispatchQueue.main.async {
            onResolve(view.window)
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
    @State private var hostingWindow: NSWindow?
    @State private var isMinimalRestoreVisible = false

    var body: some View {
        let strings = store.strings

        panelContent(strings: strings)
            .background(.regularMaterial)
            .clipShape(panelShape)
            .background {
                PulsePanelWindowReader { window in
                    hostingWindow = window
                }
            }
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
        VStack(alignment: .leading, spacing: PulsePanelLayout.sectionSpacing) {
            header
            coreMetrics(strings: strings)
            processLeaders(strings: strings)
            signalGrid(strings: strings)
            footer
        }
        .padding(PulsePanelLayout.outerPadding)
        .frame(
            width: PulsePanelLayout.contentWidth,
            height: PulsePanelLayout.contentHeight,
            alignment: .top
        )
    }

    private func minimalPanel(strings: PulseStrings) -> some View {
        VStack(alignment: .leading, spacing: PulsePanelLayout.metricRowSpacing) {
            MetricGraphBlock(
                title: strings.text(.cpu),
                tint: .cyan,
                progress: store.snapshot.cpu.percentage,
                accessibilityValue: ResourceFormatters.percentage(store.snapshot.cpu.percentage)
            )

            MetricGraphBlock(
                title: strings.text(.memory),
                tint: .green,
                progress: store.snapshot.memory.percentage,
                accessibilityValue: ResourceFormatters.percentage(store.snapshot.memory.percentage)
            )

            MetricGraphBlock(
                title: strings.text(.network),
                tint: .indigo,
                progress: ResourceScales.networkActivityProgress(
                    bytesPerSecond: store.snapshot.network.incomingBytesPerSecond
                        + store.snapshot.network.outgoingBytesPerSecond
                ),
                accessibilityValue: ResourceFormatters.byteRate(
                    bytesPerSecond: store.snapshot.network.incomingBytesPerSecond
                        + store.snapshot.network.outgoingBytesPerSecond
                )
            )

            MetricGraphBlock(
                title: strings.text(.disk),
                tint: .orange,
                progress: store.snapshot.disk.percentage,
                accessibilityValue: ResourceFormatters.percentage(store.snapshot.disk.percentage)
            )
        }
        .padding(PulsePanelLayout.outerPadding)
        .frame(
            width: PulsePanelLayout.minimalContentWidth,
            height: PulsePanelLayout.minimalContentHeight,
            alignment: .topLeading
        )
        .overlay(alignment: .bottomTrailing) {
            if isMinimalRestoreVisible {
                Button(action: expandAction) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 12, weight: .semibold))
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
            cornerRadius: presentation == .pinned ? PulsePanelLayout.panelCornerRadius : 0,
            style: .continuous
        )
    }

    private var header: some View {
        let strings = store.strings

        return HStack(spacing: 12) {
            PixelGlyph(level: store.snapshot.cpu.percentage)
                .frame(width: 36, height: 36)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Pulse")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .lineLimit(1)

                Text(store.deviceName ?? strings.text(.thisMac))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(store.snapshot.capturedAt, style: .time)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(height: PulsePanelLayout.headerHeight)
    }

    private var footer: some View {
        let strings = store.strings

        return HStack {
            Button(action: togglePinnedPanel) {
                Label(
                    strings.text(isPinned ? .unpinPanel : .pinPanel),
                    systemImage: isPinned ? "pin.fill" : "pin"
                )
            }
            .labelStyle(.iconOnly)
            .help(strings.text(isPinned ? .unpinPanel : .pinPanel))

            if let update = updateController.availableUpdate {
                Button {
                    updateController.installAvailableUpdate()
                } label: {
                    Text(strings.updateButtonTitle())
                }
                .buttonStyle(.borderedProminent)
                .disabled(!updateController.canCheckForUpdates)
                .help(strings.updateButtonHelp(version: update.version))
            }

            if presentation == .pinned {
                Button(action: collapseAction) {
                    Label(strings.text(.minimalPanel), systemImage: "arrow.down.right.and.arrow.up.left")
                }
                .labelStyle(.iconOnly)
                .help(strings.text(.minimalPanel))
            }

            Spacer()

            SettingsLink {
                Label(strings.text(.settings), systemImage: "gearshape")
            }
            .labelStyle(.iconOnly)
            .help(strings.text(.settingsHelp))

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label(strings.text(.quit), systemImage: "power")
            }
            .labelStyle(.iconOnly)
            .help(strings.text(.quitHelp))
        }
        .frame(height: PulsePanelLayout.footerHeight, alignment: .center)
    }

    private func togglePinnedPanel() {
        let sourceWindow = hostingWindow
        pinAction()

        if presentation == .menuBar {
            sourceWindow?.resignKey()
            sourceWindow?.orderOut(nil)
        }
    }

    private func coreMetrics(strings: PulseStrings) -> some View {
        VStack(spacing: PulsePanelLayout.metricRowSpacing) {
            MetricRow(
                title: strings.text(.cpu),
                value: ResourceFormatters.percentage(store.snapshot.cpu.percentage),
                detail: strings.cores(store.snapshot.cpu.coreCount),
                tint: .cyan,
                progress: store.snapshot.cpu.percentage
            )

            MetricRow(
                title: strings.text(.memory),
                value: ResourceFormatters.percentage(store.snapshot.memory.percentage),
                detail: strings.memoryDetail(
                    used: ResourceFormatters.byteString(bytes: store.snapshot.memory.usedBytes),
                    total: ResourceFormatters.byteString(bytes: store.snapshot.memory.totalBytes)
                ),
                tint: .green,
                progress: store.snapshot.memory.percentage
            )

            MetricRow(
                title: strings.text(.network),
                value: ResourceFormatters.byteRate(bytesPerSecond: store.snapshot.network.incomingBytesPerSecond),
                detail: strings.networkUploadDetail(
                    rate: ResourceFormatters.byteRate(bytesPerSecond: store.snapshot.network.outgoingBytesPerSecond)
                ),
                tint: .indigo,
                progress: ResourceScales.networkActivityProgress(
                    bytesPerSecond: store.snapshot.network.incomingBytesPerSecond + store.snapshot.network.outgoingBytesPerSecond
                )
            )

            MetricRow(
                title: strings.text(.disk),
                value: ResourceFormatters.percentage(store.snapshot.disk.percentage),
                detail: strings.diskFreeDetail(ResourceFormatters.storageByteString(bytes: store.snapshot.disk.availableBytes)),
                tint: .orange,
                progress: store.snapshot.disk.percentage
            )
        }
        .frame(height: PulsePanelLayout.coreMetricsHeight)
    }

    private func signalGrid(strings: PulseStrings) -> some View {
        let snapshot = store.snapshot

        return VStack(spacing: PulsePanelLayout.signalSpacing) {
            HStack(spacing: PulsePanelLayout.signalSpacing) {
                SignalCard(
                    title: strings.text(.memoryPressure),
                    value: strings.pressure(snapshot.memory.pressureLevel),
                    detail: strings.pressureDetail(snapshot.memory),
                    tint: .green
                )

                SignalCard(
                    title: strings.text(.thermal),
                    value: strings.thermal(snapshot.thermal.condition),
                    detail: strings.thermalDetail(snapshot.thermal),
                    tint: .red
                )
            }
            .frame(height: PulsePanelLayout.signalCardHeight)

            HStack(spacing: PulsePanelLayout.signalSpacing) {
                SignalCard(
                    title: strings.text(.power),
                    value: strings.powerTitle(snapshot.power),
                    detail: strings.powerDetail(snapshot.power),
                    tint: .yellow
                )

                SignalCard(
                    title: strings.text(.diskIO),
                    value: "\(strings.text(.read)) \(ResourceFormatters.byteRate(bytesPerSecond: snapshot.diskIO.readBytesPerSecond))",
                    detail: "\(strings.text(.write)) \(ResourceFormatters.byteRate(bytesPerSecond: snapshot.diskIO.writeBytesPerSecond))",
                    tint: .orange
                )
            }
            .frame(height: PulsePanelLayout.signalCardHeight)

            PressureExplanationRow(
                text: strings.pressureExplanation(snapshot.memory),
                level: snapshot.memory.pressureLevel
            )
            .frame(height: PulsePanelLayout.pressureRowHeight)
        }
        .frame(height: PulsePanelLayout.signalGridHeight)
    }

    private func processLeaders(strings: PulseStrings) -> some View {
        VStack(alignment: .leading, spacing: PulsePanelLayout.processSectionSpacing) {
            ProcessUsageSection(
                title: strings.text(.topCPUProcesses),
                entries: store.snapshot.processes.topCPU,
                emptyText: strings.text(.collecting),
                value: { ResourceFormatters.processPercentage($0.cpuPercentage) },
                share: \.cpuPercentage
            )

            ProcessUsageSection(
                title: strings.text(.topMemoryProcesses),
                entries: store.snapshot.processes.topMemory,
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

    var body: some View {
        HStack(alignment: .center, spacing: Layout.groupSpacing) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(.callout, design: .rounded, weight: .medium))
                    .lineLimit(1)

                PixelMeter(value: progress, tint: tint)
                    .accessibilityLabel("\(title) \(value)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .firstTextBaseline, spacing: Layout.valueSpacing) {
                Text(value)
                    .font(.system(.title3, design: .monospaced, weight: .semibold))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(width: Layout.valueColumnWidth, alignment: .trailing)

                Text(detail)
                    .font(.system(.callout, design: .monospaced, weight: .semibold))
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
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.callout, design: .rounded, weight: .medium))
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
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Circle()
                    .fill(tint)
                    .frame(width: 6, height: 6)

                Text(title)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Text(value)
                .font(.system(.callout, design: .monospaced, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)

            Text(detail)
                .font(.system(.caption2, design: .monospaced, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
    var height: CGFloat

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            ProcessUsageLeadingIcon(color: color, appBundlePath: appBundlePath)

            Text(name)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 8)

            Text(value)
                .font(.system(.caption, design: .monospaced, weight: .semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(height: height)
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

private struct PressureExplanationRow: View {
    var text: String
    var level: PressureLevel

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)
                .padding(.top, 5)

            Text(text)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityLabel(text)
    }

    private var tint: Color {
        switch level {
        case .nominal:
            .green
        case .elevated:
            .yellow
        case .high:
            .orange
        }
    }
}

#Preview {
    PulsePanelView()
        .environment(PulseStore())
        .environment(PulseUpdateController(startingUpdater: false))
}
