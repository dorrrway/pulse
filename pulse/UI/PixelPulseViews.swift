import SwiftUI

struct PixelGlyph: View {
    var level: Double

    private let pattern: [[Bool]] = [
        [false, true, true, true, false],
        [true, false, true, false, true],
        [true, true, true, true, true],
        [true, false, true, false, true],
        [false, true, true, true, false],
    ]

    var body: some View {
        GeometryReader { proxy in
            let metrics = layoutMetrics(for: proxy.size)
            let activeRows = max(1, Int((normalizedLevel * 5).rounded(.up)))

            VStack(spacing: metrics.spacing) {
                ForEach(0..<5, id: \.self) { row in
                    HStack(spacing: metrics.spacing) {
                        ForEach(0..<5, id: \.self) { column in
                            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                                .fill(pixelColor(row: row, activeRows: activeRows))
                                .opacity(pattern[row][column] ? 1 : 0)
                                .frame(width: metrics.pixelSize, height: metrics.pixelSize)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private var normalizedLevel: Double {
        guard level.isFinite else {
            return 0
        }

        return min(max(level, 0), 1)
    }

    private func layoutMetrics(for size: CGSize) -> (pixelSize: Double, spacing: Double) {
        let side = min(size.width, size.height)

        guard side.isFinite, side > 0 else {
            return (0, 0)
        }

        let spacing = side > 8 ? max(side * 0.08, 1) : 0
        let availableSide = max(side - spacing * 4, 0)

        return (availableSide / 5, spacing)
    }

    private func pixelColor(row: Int, activeRows: Int) -> Color {
        let threshold = 5 - activeRows

        if row >= threshold {
            return .primary
        }

        return .secondary.opacity(0.55)
    }
}

struct PixelMeter: View {
    var value: Double
    var tint: Color
    var columns = 18

    var body: some View {
        let columnCount = max(columns, 0)
        let activeColumns = Int((min(max(value, 0), 1) * Double(columnCount)).rounded())

        HStack(spacing: 2) {
            ForEach(0..<columnCount, id: \.self) { index in
                Rectangle()
                    .fill(index < activeColumns ? tint : Color.secondary.opacity(0.18))
                    .frame(width: 4, height: 10)
            }
        }
        .frame(height: 10)
        .accessibilityHidden(true)
    }
}
