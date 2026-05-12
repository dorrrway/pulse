import AppKit
import SwiftUI

struct PulsePanelView: View {
    @Environment(PulseStore.self) private var store

    private enum Layout {
        static let width: CGFloat = 420
        static let height: CGFloat = 482
    }

    var body: some View {
        let strings = store.strings

        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                header
                coreMetrics(strings: strings)
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

                Text(strings.text(.macResourceSignal))
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
                progress: min((store.snapshot.network.incomingBytesPerSecond + store.snapshot.network.outgoingBytesPerSecond) / 5_000_000, 1)
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
