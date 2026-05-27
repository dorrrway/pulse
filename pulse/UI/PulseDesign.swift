import SwiftUI

enum PulseDesign {
    enum Spacing {
        static let none: CGFloat = 0
        static let hairline: CGFloat = 1
        static let micro: CGFloat = 2
        static let xxs: CGFloat = 4
        static let fine: CGFloat = 6
        static let xs: CGFloat = 8
        static let compact: CGFloat = 10
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Radius {
        static let control: CGFloat = 8
        static let selectedControl: CGFloat = 7
        static let segmentedControl: CGFloat = 9
        static let card: CGFloat = 8
        static let panel: CGFloat = 16
        static let islandSeedBottom: CGFloat = 18
        static let islandExpandedBottom: CGFloat = 24
        static let islandSeedShoulder: CGFloat = 32
        static let islandExpandedShoulder: CGFloat = 36
    }

    enum Opacity {
        static let islandSeedSurface = 0.98
        static let islandExpandedSurface = 0.96
        static let islandSeedShadow = 0.24
        static let islandExpandedShadow = 0.0
        static let hoverFill = 0.10
        static let secondaryOnDark = 0.58
        static let selectedFillOnDark = 0.16
        static let hoverFillOnDark = 0.08
    }

    enum Shadow {
        static let islandSeedRadius: CGFloat = 10
        static let islandExpandedRadius: CGFloat = 0
    }

    enum Control {
        static let buttonSide: CGFloat = 28
        static let iconFrameSide: CGFloat = 20
        static let iconSide: CGFloat = 18
        static let symbolSize: CGFloat = 15
    }

    enum Typography {
        static let islandSeed = Font.system(.caption, design: .rounded, weight: .bold)
        static let islandNotchedSeed = Font.system(.callout, design: .rounded, weight: .semibold)
        static let panelTitle = Font.system(.title3, design: .rounded, weight: .semibold)
        static let panelLabel = Font.system(.caption, design: .rounded, weight: .medium)
        static let panelBody = Font.system(.callout, design: .rounded, weight: .medium)
        static let panelValue = Font.system(.callout, design: .monospaced, weight: .semibold)
        static let panelLargeValue = Font.system(.title3, design: .monospaced, weight: .semibold)
        static let panelDetail = Font.system(.caption2, design: .monospaced, weight: .medium)
    }

    enum Island {
        static let seedVisibleWidth: CGFloat = 164
        static let criticalSeedVisibleWidth: CGFloat = 380
        static let notchLaneSafetyInset = Spacing.xxs
        static let notchedSeedSideLaneWidth: CGFloat = 40
        static let notchedSeedContentHorizontalPadding = Spacing.sm
        static let defaultSeedVisibleHeight: CGFloat = 30
        static let expandedSurfaceHeightMultiplier: CGFloat = 2
        static let expandedHeaderExtraHeight: CGFloat = 12
        static let expandedSurfaceWidth: CGFloat = 560
        static let attachedPanelTopGap = Spacing.xs
        static let screenEdgeInset = Spacing.md
        static let seedSurfaceTopShoulderInset = Spacing.sm
        static let expandedSurfaceTopShoulderInset: CGFloat = 20
        static let seedSurfaceTopShoulderDepth = Spacing.sm
        static let expandedSurfaceTopShoulderDepth: CGFloat = 18
        static let seedContentHorizontalPadding = Spacing.sm
        static let expandedContentHorizontalPadding = Spacing.sm
        static let seedTopAttachmentDepth: CGFloat = 6
        static let expandedTopAttachmentDepth = Spacing.xs
    }

    enum Panel {
        static let contentWidth: CGFloat = 420
        static let outerPadding = Spacing.md
        static let sectionSpacing = Spacing.md
        static let metricRowHeight: CGFloat = 36
        static let metricRowSpacing: CGFloat = 10
        static let processSectionHeight: CGFloat = 82
        static let processSectionSpacing = Spacing.sm
        static let signalCardHeight: CGFloat = 68
        static let runtimeRowHeight: CGFloat = 34
        static let signalSpacing = Spacing.xs
        static let footerHeight: CGFloat = 36
        static let footerTopSpacing = Spacing.xs
        static let footerBottomPadding = Spacing.xs
        static let dragRegionHeight: CGFloat = 86
        static let minimalMetricGraphWidth: CGFloat = 106
    }
}
