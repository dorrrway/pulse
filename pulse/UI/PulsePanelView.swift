import AppKit
import SwiftUI

struct PulsePanelView: View {
    @Environment(PulseStore.self) private var store

    private enum Layout {
        static let width: CGFloat = 420
        static let height: CGFloat = 560
    }

    var body: some View {
        let strings = store.strings

        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                header
                coreMetrics(strings: strings)
                processLeaders(strings: strings)
                signalGrid(strings: strings)
                footer
            }
            .padding(16)
        }
        .frame(width: Layout.width, height: Layout.height)
        .background(.regularMaterial)
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

                Text(store.deviceName ?? strings.text(.thisMac))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(store.snapshot.capturedAt, style: .time)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        let strings = store.strings

        return HStack {
            Text(strings.text(.monitorOnly))
                .font(.caption2)
                .foregroundStyle(.secondary)

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
    }

    private func coreMetrics(strings: PulseStrings) -> some View {
        VStack(spacing: 10) {
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
    }

    private func signalGrid(strings: PulseStrings) -> some View {
        let snapshot = store.snapshot

        return VStack(spacing: 8) {
            HStack(spacing: 8) {
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

            HStack(spacing: 8) {
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

            PressureExplanationRow(
                text: strings.pressureExplanation(snapshot.memory),
                level: snapshot.memory.pressureLevel
            )
        }
    }

    private func processLeaders(strings: PulseStrings) -> some View {
        VStack(alignment: .leading, spacing: 12) {
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
    }
}

private struct MetricRow: View {
    private enum Layout {
        static let valueColumnWidth: CGFloat = 86
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
                    .minimumScaleFactor(0.8)
                    .frame(width: Layout.valueColumnWidth, alignment: .trailing)

                Text(detail)
                    .font(.system(.callout, design: .monospaced, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .allowsTightening(true)
                    .frame(width: Layout.detailColumnWidth, alignment: .trailing)
            }
        }
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
                    .minimumScaleFactor(0.8)
            }

            Text(value)
                .font(.system(.callout, design: .monospaced, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(detail)
                .font(.system(.caption2, design: .monospaced, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
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
                ProcessUsageShareChart(entries: entries, share: share)
                    .frame(width: Layout.chartSide, height: Layout.chartSide)
                    .padding(.top, Layout.titleLineHeight + Layout.titleToRowsSpacing)
            }
        }
    }
}

private struct ProcessUsageRow: View {
    var color: Color
    var name: String
    var value: String
    var height: CGFloat

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Rectangle()
                .fill(color)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)

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
                .minimumScaleFactor(0.78)
        }
        .frame(height: height)
    }
}

private struct ProcessUsageShareChart: View {
    var entries: [ProcessResourceUsage]
    var share: (ProcessResourceUsage) -> Double

    private static let gridSize = 11
    private static let cellSpacing: CGFloat = 1

    private var slices: [ProcessUsageShareSlice] {
        ProcessUsageShareSlice.make(from: entries, share: share)
    }

    var body: some View {
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
        .help(helpText)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entries.map(\.name).joined(separator: ", "))
        .accessibilityValue(helpText)
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
            return "No usage"
        }

        let total = slices.reduce(0) { $0 + $1.value }
        guard total > 0 else {
            return "No usage"
        }

        return slices.map { slice in
            let percent = slice.value / total * 100
            return "\(slice.name) \(percent.formatted(.number.precision(.fractionLength(0))))%"
        }
        .joined(separator: "\n")
    }
}

private struct ProcessUsageShareSlice: Identifiable, Hashable {
    var id: String { name }

    let name: String
    let value: Double
    let startDegrees: Double
    let endDegrees: Double

    static func make(
        from entries: [ProcessResourceUsage],
        share: (ProcessResourceUsage) -> Double
    ) -> [ProcessUsageShareSlice] {
        let values = entries
            .map { entry in
                (name: entry.name, value: max(share(entry), 0))
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
                name: value.name,
                value: value.value,
                startDegrees: cursor,
                endDegrees: cursor + angle
            )
        }
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
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

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
}
