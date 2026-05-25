import SwiftUI

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
