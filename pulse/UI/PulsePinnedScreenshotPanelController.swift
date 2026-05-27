import AppKit
import SwiftUI

nonisolated enum PulsePinnedScreenshotResizeHandle: Equatable {
    case top
    case bottom
    case left
    case right
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var horizontalDirection: CGFloat {
        switch self {
        case .left, .topLeft, .bottomLeft:
            -1
        case .right, .topRight, .bottomRight:
            1
        case .top, .bottom:
            0
        }
    }

    var verticalDirection: CGFloat {
        switch self {
        case .bottom, .bottomLeft, .bottomRight:
            -1
        case .top, .topLeft, .topRight:
            1
        case .left, .right:
            0
        }
    }

    var isCorner: Bool {
        horizontalDirection != 0 && verticalDirection != 0
    }
}

nonisolated enum PulsePinnedScreenshotResizeDriver: Equatable {
    case horizontal
    case vertical
}

nonisolated enum PulsePinnedScreenshotPanelLayout {
    static let edgeInset: CGFloat = 24
    static let cascadeOffset: CGFloat = 24
    static let cornerRadius: CGFloat = 16
    static let resizeHandleThickness: CGFloat = 12
    static let resizeDriverLockThreshold: CGFloat = 4
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

    static func resizeHandle(at location: CGPoint, in bounds: CGRect) -> PulsePinnedScreenshotResizeHandle? {
        guard bounds.width > 0, bounds.height > 0, bounds.contains(location) else {
            return nil
        }

        let thickness = min(resizeHandleThickness, bounds.width / 3, bounds.height / 3)
        let isNearLeft = location.x <= bounds.minX + thickness
        let isNearRight = location.x >= bounds.maxX - thickness
        let isNearBottom = location.y <= bounds.minY + thickness
        let isNearTop = location.y >= bounds.maxY - thickness

        switch (isNearLeft, isNearRight, isNearBottom, isNearTop) {
        case (true, false, false, true):
            return .topLeft
        case (false, true, false, true):
            return .topRight
        case (true, false, true, false):
            return .bottomLeft
        case (false, true, true, false):
            return .bottomRight
        case (true, false, false, false):
            return .left
        case (false, true, false, false):
            return .right
        case (false, false, false, true):
            return .top
        case (false, false, true, false):
            return .bottom
        default:
            return nil
        }
    }

    static func resizedWindowFrame(
        initialFrame: CGRect,
        imageSize: CGSize,
        visibleFrame: CGRect,
        handle: PulsePinnedScreenshotResizeHandle,
        dragDelta: CGVector,
        resizeDriver: PulsePinnedScreenshotResizeDriver
    ) -> CGRect {
        let proposedSize = proposedResizeSize(
            initialSize: initialFrame.size,
            imageSize: imageSize,
            handle: handle,
            dragDelta: dragDelta,
            resizeDriver: resizeDriver
        )
        let size = clampedResizeSize(
            proposedSize,
            imageSize: imageSize,
            visibleFrame: visibleFrame
        )
        let horizontalDirection = handle.horizontalDirection
        let verticalDirection = handle.verticalDirection
        let originX: CGFloat
        let originY: CGFloat

        if horizontalDirection < 0 {
            originX = initialFrame.maxX - size.width
        } else if horizontalDirection > 0 {
            originX = initialFrame.minX
        } else {
            originX = initialFrame.midX - size.width / 2
        }

        if verticalDirection < 0 {
            originY = initialFrame.maxY - size.height
        } else if verticalDirection > 0 {
            originY = initialFrame.minY
        } else {
            originY = initialFrame.midY - size.height / 2
        }

        return constrainedWindowFrame(
            CGRect(x: originX, y: originY, width: size.width, height: size.height),
            visibleFrame: visibleFrame
        )
    }

    static func defaultResizeDriver(for handle: PulsePinnedScreenshotResizeHandle) -> PulsePinnedScreenshotResizeDriver {
        handle.verticalDirection != 0 && handle.horizontalDirection == 0 ? .vertical : .horizontal
    }

    static func lockedCornerResizeDriver(
        initialSize: CGSize,
        dragDelta: CGVector
    ) -> PulsePinnedScreenshotResizeDriver? {
        let horizontalDistance = abs(dragDelta.dx)
        let verticalDistance = abs(dragDelta.dy)

        guard max(horizontalDistance, verticalDistance) >= resizeDriverLockThreshold else {
            return nil
        }

        let horizontalMagnitude = horizontalDistance / max(1, initialSize.width)
        let verticalMagnitude = verticalDistance / max(1, initialSize.height)

        return horizontalMagnitude >= verticalMagnitude ? .horizontal : .vertical
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

    private static func proposedResizeSize(
        initialSize: CGSize,
        imageSize: CGSize,
        handle: PulsePinnedScreenshotResizeHandle,
        dragDelta: CGVector,
        resizeDriver: PulsePinnedScreenshotResizeDriver
    ) -> CGSize {
        let aspectRatio = normalizedImageSize(imageSize).width / normalizedImageSize(imageSize).height
        let horizontalDirection = handle.horizontalDirection
        let verticalDirection = handle.verticalDirection

        if resizeDriver == .horizontal {
            let width = initialSize.width + horizontalDirection * dragDelta.dx

            return CGSize(width: width, height: width / aspectRatio)
        }

        let height = initialSize.height + verticalDirection * dragDelta.dy

        return CGSize(width: height * aspectRatio, height: height)
    }

    private static func clampedResizeSize(
        _ proposedSize: CGSize,
        imageSize: CGSize,
        visibleFrame: CGRect
    ) -> CGSize {
        let aspectRatio = normalizedImageSize(imageSize).width / normalizedImageSize(imageSize).height
        let minimumSize = minimumResizeSize(imageSize: imageSize)
        let maximumSize = maximumResizeSize(imageSize: imageSize, visibleFrame: visibleFrame)
        let minimumWidth = min(minimumSize.width, maximumSize.width)
        let maximumWidth = max(minimumWidth, maximumSize.width)
        let width = min(max(proposedSize.width, minimumWidth), maximumWidth)

        return CGSize(
            width: width,
            height: width / aspectRatio
        )
    }

    private static func constrainedWindowFrame(_ frame: CGRect, visibleFrame: CGRect) -> CGRect {
        let safeFrame = visibleFrame.insetBy(
            dx: min(edgeInset, visibleFrame.width / 4),
            dy: min(edgeInset, visibleFrame.height / 4)
        )
        let maxX = max(safeFrame.minX, safeFrame.maxX - frame.width)
        let maxY = max(safeFrame.minY, safeFrame.maxY - frame.height)

        return CGRect(
            x: min(max(frame.minX, safeFrame.minX), maxX),
            y: min(max(frame.minY, safeFrame.minY), maxY),
            width: frame.width,
            height: frame.height
        )
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
        let hostingView = PulsePinnedScreenshotHostingView(rootView: AnyView(rootView), imageSize: image.size)
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
            styleMask: [.borderless, .nonactivatingPanel],
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
    private struct ResizeSession {
        var handle: PulsePinnedScreenshotResizeHandle
        var resizeDriver: PulsePinnedScreenshotResizeDriver
        var isResizeDriverLocked: Bool
        var initialFrame: CGRect
        var initialMouseLocation: CGPoint
    }

    private let imageSize: CGSize
    private var trackingArea: NSTrackingArea?
    private var resizeSession: ResizeSession?

    override var mouseDownCanMoveWindow: Bool {
        guard let window else {
            return true
        }

        let location = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        return PulsePinnedScreenshotPanelLayout.resizeHandle(at: location, in: bounds) == nil
    }

    init(rootView: AnyView, imageSize: CGSize) {
        self.imageSize = imageSize
        super.init(rootView: rootView)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.cornerRadius = PulsePinnedScreenshotPanelLayout.cornerRadius
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
    }

    @available(*, unavailable)
    required init(rootView: AnyView) {
        fatalError("init(rootView:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
            owner: self
        )
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }

    override func resetCursorRects() {
        super.resetCursorRects()

        let thickness = min(
            PulsePinnedScreenshotPanelLayout.resizeHandleThickness,
            bounds.width / 3,
            bounds.height / 3
        )
        let leftRect = NSRect(x: bounds.minX, y: bounds.minY, width: thickness, height: bounds.height)
        let rightRect = NSRect(x: bounds.maxX - thickness, y: bounds.minY, width: thickness, height: bounds.height)
        let bottomRect = NSRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: thickness)
        let topRect = NSRect(x: bounds.minX, y: bounds.maxY - thickness, width: bounds.width, height: thickness)

        addCursorRect(leftRect, cursor: .resizeLeftRight)
        addCursorRect(rightRect, cursor: .resizeLeftRight)
        addCursorRect(bottomRect, cursor: .resizeUpDown)
        addCursorRect(topRect, cursor: .resizeUpDown)
    }

    override func mouseMoved(with event: NSEvent) {
        updateCursor(for: event)
        super.mouseMoved(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
        super.mouseExited(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)

        guard let handle = PulsePinnedScreenshotPanelLayout.resizeHandle(at: location, in: bounds),
              let window else {
            super.mouseDown(with: event)
            return
        }

        resizeSession = ResizeSession(
            handle: handle,
            resizeDriver: PulsePinnedScreenshotPanelLayout.defaultResizeDriver(for: handle),
            isResizeDriverLocked: !handle.isCorner,
            initialFrame: window.frame,
            initialMouseLocation: NSEvent.mouseLocation
        )
        cursor(for: handle).set()
    }

    override func mouseDragged(with event: NSEvent) {
        guard var resizeSession, let window else {
            super.mouseDragged(with: event)
            return
        }

        let currentMouseLocation = NSEvent.mouseLocation
        let dragDelta = CGVector(
            dx: currentMouseLocation.x - resizeSession.initialMouseLocation.x,
            dy: currentMouseLocation.y - resizeSession.initialMouseLocation.y
        )

        if resizeSession.handle.isCorner, !resizeSession.isResizeDriverLocked {
            guard let lockedDriver = PulsePinnedScreenshotPanelLayout.lockedCornerResizeDriver(
                initialSize: resizeSession.initialFrame.size,
                dragDelta: dragDelta
            ) else {
                return
            }

            resizeSession.resizeDriver = lockedDriver
            resizeSession.isResizeDriverLocked = true
            self.resizeSession = resizeSession
        }

        let visibleFrame = window.screen?.visibleFrame
            ?? NSScreen.screens.first { $0.visibleFrame.intersects(resizeSession.initialFrame) }?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? resizeSession.initialFrame
        let frame = PulsePinnedScreenshotPanelLayout.resizedWindowFrame(
            initialFrame: resizeSession.initialFrame,
            imageSize: imageSize,
            visibleFrame: visibleFrame,
            handle: resizeSession.handle,
            dragDelta: dragDelta,
            resizeDriver: resizeSession.resizeDriver
        )

        window.setFrame(frame, display: true)
    }

    override func mouseUp(with event: NSEvent) {
        window?.invalidateShadow()
        resizeSession = nil
        super.mouseUp(with: event)
    }

    private func updateCursor(for event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        guard let handle = PulsePinnedScreenshotPanelLayout.resizeHandle(at: location, in: bounds) else {
            NSCursor.arrow.set()
            return
        }

        cursor(for: handle).set()
    }

    private func cursor(for handle: PulsePinnedScreenshotResizeHandle) -> NSCursor {
        switch handle {
        case .left, .right, .topLeft, .topRight, .bottomLeft, .bottomRight:
            .resizeLeftRight
        case .top, .bottom:
            .resizeUpDown
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
