import AppKit
import SwiftUI

nonisolated enum PulsePinnedScreenshotPanelLayout {
    static let panelStyleMask: NSWindow.StyleMask = [
        .borderless,
        .resizable,
        .nonactivatingPanel,
    ]
    static let edgeInset: CGFloat = 24
    static let cascadeOffset: CGFloat = 24
    static let cornerRadius: CGFloat = 16
    static let minimumResizeShortEdge: CGFloat = 160
    static let maximumImageWidth: CGFloat = 1120
    static let maximumImageHeight: CGFloat = 760
    static let maximumScreenWidthFraction: CGFloat = 0.72
    static let maximumScreenHeightFraction: CGFloat = 0.68
    static let fallbackSize = CGSize(width: 360, height: 240)

    static func windowSize(imageSize: CGSize, visibleFrame: CGRect) -> CGSize {
        let imageContentSize = imageContentSize(imageSize: imageSize, visibleFrame: visibleFrame)

        return imageContentSize
    }

    static func contentAspectRatio(imageSize: CGSize) -> CGSize {
        normalizedImageSize(imageSize)
    }

    static func imageContentSize(imageSize: CGSize, visibleFrame: CGRect) -> CGSize {
        let imageSize = normalizedImageSize(imageSize)
        let availableSize = maximumImageSize(visibleFrame: visibleFrame)
        let scale = min(
            1,
            availableSize.width / imageSize.width,
            availableSize.height / imageSize.height
        )

        return CGSize(
            width: (imageSize.width * scale).rounded(.toNearestOrAwayFromZero),
            height: (imageSize.height * scale).rounded(.toNearestOrAwayFromZero)
        )
    }

    static func imageContentRect(windowSize: CGSize) -> CGRect {
        CGRect(
            origin: .zero,
            size: CGSize(
                width: max(1, windowSize.width),
                height: max(1, windowSize.height)
            )
        )
    }

    static func windowFrame(
        imageSize: CGSize,
        visibleFrame: CGRect,
        pointerLocation: CGPoint,
        cascadeIndex: Int
    ) -> CGRect {
        let size = windowSize(imageSize: imageSize, visibleFrame: visibleFrame)
        let safeFrame = visibleFrame.insetBy(
            dx: min(edgeInset, visibleFrame.width / 4),
            dy: min(edgeInset, visibleFrame.height / 4)
        )
        let anchor = visibleFrame.contains(pointerLocation)
            ? pointerLocation
            : CGPoint(x: visibleFrame.midX, y: visibleFrame.midY)
        let cascade = CGFloat(cascadeIndex % 8) * cascadeOffset
        let proposedOrigin = CGPoint(
            x: anchor.x - size.width / 2 + cascade,
            y: anchor.y - size.height / 2 - cascade
        )
        let maxX = max(safeFrame.minX, safeFrame.maxX - size.width)
        let maxY = max(safeFrame.minY, safeFrame.maxY - size.height)

        return CGRect(
            x: min(max(proposedOrigin.x, safeFrame.minX), maxX),
            y: min(max(proposedOrigin.y, safeFrame.minY), maxY),
            width: size.width,
            height: size.height
        )
    }

    static func minimumResizeSize(imageSize: CGSize) -> CGSize {
        let imageSize = normalizedImageSize(imageSize)
        let aspectRatio = imageSize.width / imageSize.height
        let shortEdge = min(minimumResizeShortEdge, min(imageSize.width, imageSize.height))

        if aspectRatio >= 1 {
            return CGSize(
                width: (shortEdge * aspectRatio).rounded(.toNearestOrAwayFromZero),
                height: shortEdge.rounded(.toNearestOrAwayFromZero)
            )
        }

        return CGSize(
            width: shortEdge.rounded(.toNearestOrAwayFromZero),
            height: (shortEdge / aspectRatio).rounded(.toNearestOrAwayFromZero)
        )
    }

    static func maximumResizeSize(imageSize: CGSize, visibleFrame: CGRect) -> CGSize {
        let imageSize = normalizedImageSize(imageSize)
        let availableWidth = max(1, visibleFrame.width - edgeInset * 2)
        let availableHeight = max(1, visibleFrame.height - edgeInset * 2)
        let scale = min(availableWidth / imageSize.width, availableHeight / imageSize.height)

        return CGSize(
            width: max(1, (imageSize.width * scale).rounded(.toNearestOrAwayFromZero)),
            height: max(1, (imageSize.height * scale).rounded(.toNearestOrAwayFromZero))
        )
    }

    private static func normalizedImageSize(_ imageSize: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return fallbackSize
        }

        return imageSize
    }

    private static func maximumImageSize(visibleFrame: CGRect) -> CGSize {
        let availableWidth = max(1, visibleFrame.width - edgeInset * 2)
        let availableHeight = max(1, visibleFrame.height - edgeInset * 2)
        let width = min(maximumImageWidth, availableWidth, visibleFrame.width * maximumScreenWidthFraction)
        let height = min(maximumImageHeight, availableHeight, visibleFrame.height * maximumScreenHeightFraction)

        return CGSize(width: max(1, width), height: max(1, height))
    }
}

@MainActor
final class PulsePinnedScreenshotPanelController {
    private var panels: [UUID: NSPanel] = [:]

    func pin(image: NSImage, strings: PulseStrings, near pointerLocation: CGPoint = NSEvent.mouseLocation) {
        let id = UUID()
        let screen = Self.screen(containing: pointerLocation)
        let visibleFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? CGRect(origin: .zero, size: .zero)
        let frame = PulsePinnedScreenshotPanelLayout.windowFrame(
            imageSize: image.size,
            visibleFrame: visibleFrame,
            pointerLocation: pointerLocation,
            cascadeIndex: panels.count
        )
        let panel = makePanel(frame: frame, imageSize: image.size, visibleFrame: visibleFrame)
        let rootView = PulsePinnedScreenshotView(
            image: image,
            closeTitle: strings.text(.screenshotUnpinAction)
        ) { [weak self, weak panel] in
            panel?.close()
            self?.panels[id] = nil
        }
        let hostingView = PulsePinnedScreenshotHostingView(rootView: AnyView(rootView))
        hostingView.frame = NSRect(origin: .zero, size: frame.size)
        hostingView.autoresizingMask = [.width, .height]

        panel.contentView = hostingView
        panels[id] = panel
        panel.orderFrontRegardless()
        panel.invalidateShadow()
    }

    private func makePanel(frame: CGRect, imageSize: CGSize, visibleFrame: CGRect) -> NSPanel {
        let panel = PulsePinnedScreenshotPanel(
            contentRect: frame,
            styleMask: PulsePinnedScreenshotPanelLayout.panelStyleMask,
            backing: .buffered,
            defer: false
        )
        panel.title = "Pulse pinned screenshot"
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.acceptsMouseMovedEvents = true
        panel.contentMinSize = PulsePinnedScreenshotPanelLayout.minimumResizeSize(imageSize: imageSize)
        panel.contentMaxSize = PulsePinnedScreenshotPanelLayout.maximumResizeSize(
            imageSize: imageSize,
            visibleFrame: visibleFrame
        )
        panel.contentAspectRatio = PulsePinnedScreenshotPanelLayout.contentAspectRatio(imageSize: imageSize)

        return panel
    }

    private static func screen(containing point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
    }
}

private struct PulsePinnedScreenshotView: View {
    let image: NSImage
    let closeTitle: String
    var closeAction: () -> Void

    @State private var isHovering = false

    var body: some View {
        GeometryReader { proxy in
            let imageContentRect = PulsePinnedScreenshotPanelLayout.imageContentRect(windowSize: proxy.size)

            ZStack(alignment: .bottomLeading) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .transaction { transaction in
                        transaction.animation = nil
                    }
                    .frame(
                        width: imageContentRect.width,
                        height: imageContentRect.height
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: PulsePinnedScreenshotPanelLayout.cornerRadius,
                            style: .continuous
                        )
                    )
                    .contentShape(
                        RoundedRectangle(
                            cornerRadius: PulsePinnedScreenshotPanelLayout.cornerRadius,
                            style: .continuous
                        )
                    )
                    .gesture(WindowDragGesture())
                    .allowsWindowActivationEvents(true)
                    .position(x: imageContentRect.midX, y: imageContentRect.midY)

                if isHovering {
                    Button(action: closeAction) {
                        PanelControlIconImage(name: PanelControlIcon.pinFilled, side: 15)
                            .frame(width: 28, height: 28)
                            .foregroundStyle(.white)
                            .background(.black.opacity(0.58), in: Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help(closeTitle)
                    .accessibilityLabel(closeTitle)
                    .padding(PulseDesign.Spacing.xs)
                    .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .bottomLeading)))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
    }
}

private final class PulsePinnedScreenshotPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }
}

@MainActor
private final class PulsePinnedScreenshotHostingView: NSHostingView<AnyView> {
    required init(rootView: AnyView) {
        super.init(rootView: rootView)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.cornerRadius = PulsePinnedScreenshotPanelLayout.cornerRadius
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
