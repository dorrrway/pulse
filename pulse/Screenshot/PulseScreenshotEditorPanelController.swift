import AppKit
import SwiftUI

nonisolated enum PulseScreenshotEditorPanelLayout {
    static let edgeInset: CGFloat = 24
    static let cascadeOffset: CGFloat = 18
    static let cornerRadius: CGFloat = PulsePinnedScreenshotPanelLayout.cornerRadius
    static let toolbarHeight: CGFloat = 58
    static let toolbarGap: CGFloat = 10
    static let minimumToolbarWidth: CGFloat = 520
    static let maximumImageWidth: CGFloat = 1120
    static let maximumImageHeight: CGFloat = 700
    static let maximumScreenWidthFraction: CGFloat = 0.72
    static let maximumScreenHeightFraction: CGFloat = 0.60
    static let fallbackImageSize = CGSize(width: 480, height: 300)

    static func windowSize(imageSize: CGSize, visibleFrame: CGRect) -> CGSize {
        let imageContentSize = imageContentSize(imageSize: imageSize, visibleFrame: visibleFrame)
        return CGSize(
            width: max(minimumToolbarWidth, imageContentSize.width),
            height: imageContentSize.height + toolbarGap + toolbarHeight
        )
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
        let cascade = CGFloat(cascadeIndex % 6) * cascadeOffset
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

    private static func normalizedImageSize(_ imageSize: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return fallbackImageSize
        }

        return imageSize
    }

    private static func maximumImageSize(visibleFrame: CGRect) -> CGSize {
        let availableWidth = max(1, visibleFrame.width - edgeInset * 2)
        let availableHeight = max(1, visibleFrame.height - edgeInset * 2 - toolbarHeight - toolbarGap)
        let width = min(maximumImageWidth, availableWidth, visibleFrame.width * maximumScreenWidthFraction)
        let height = min(maximumImageHeight, availableHeight, visibleFrame.height * maximumScreenHeightFraction)

        return CGSize(width: max(1, width), height: max(1, height))
    }
}

@MainActor
final class PulseScreenshotEditorPanelController {
    private var panel: NSPanel?

    func edit(
        image: NSImage,
        strings: PulseStrings,
        near pointerLocation: CGPoint = NSEvent.mouseLocation,
        onComplete: @escaping (NSImage) -> Void
    ) {
        close()

        let screen = Self.screen(containing: pointerLocation)
        let visibleFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? CGRect(origin: .zero, size: .zero)
        let frame = PulseScreenshotEditorPanelLayout.windowFrame(
            imageSize: image.size,
            visibleFrame: visibleFrame,
            pointerLocation: pointerLocation,
            cascadeIndex: 0
        )
        let imageContentSize = PulseScreenshotEditorPanelLayout.imageContentSize(
            imageSize: image.size,
            visibleFrame: visibleFrame
        )
        let panel = makePanel(frame: frame)
        let rootView = PulseScreenshotEditorView(
            image: image,
            strings: strings,
            imageContentSize: imageContentSize,
            closeAction: { [weak self, weak panel] in
                panel?.close()
                self?.panel = nil
            },
            completeAction: { [weak self, weak panel] editedImage in
                onComplete(editedImage)
                panel?.close()
                self?.panel = nil
            }
        )
        let hostingView = PulseScreenshotEditorHostingView(rootView: AnyView(rootView))
        hostingView.frame = NSRect(origin: .zero, size: frame.size)
        hostingView.autoresizingMask = [.width, .height]

        panel.contentView = hostingView
        self.panel = panel
        panel.orderFrontRegardless()
        panel.invalidateShadow()
    }

    func close() {
        panel?.close()
        panel = nil
    }

    private func makePanel(frame: CGRect) -> NSPanel {
        let panel = PulseScreenshotEditorPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Pulse screenshot editor"
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.acceptsMouseMovedEvents = true
        panel.contentMinSize = frame.size
        panel.contentMaxSize = frame.size
        panel.appearance = NSAppearance(named: .darkAqua)

        return panel
    }

    private static func screen(containing point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
    }
}

private struct PulseScreenshotEditorView: View {
    let image: NSImage
    let strings: PulseStrings
    let imageContentSize: CGSize
    var closeAction: () -> Void
    var completeAction: (NSImage) -> Void

    @State private var selectedTool = PulseScreenshotEditInteractionPolicy.defaultSelectedTool
    @State private var marks: [PulseScreenshotEditMark] = []
    @State private var activeMark: PulseScreenshotEditMark?

    var body: some View {
        VStack(spacing: PulseScreenshotEditorPanelLayout.toolbarGap) {
            canvas

            toolbar
        }
        .frame(width: contentWidth, height: imageContentSize.height + PulseScreenshotEditorPanelLayout.toolbarGap + PulseScreenshotEditorPanelLayout.toolbarHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.clear)
    }

    private var contentWidth: CGFloat {
        max(PulseScreenshotEditorPanelLayout.minimumToolbarWidth, imageContentSize.width)
    }

    @ViewBuilder
    private var canvas: some View {
        let content = ZStack {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: imageContentSize.width, height: imageContentSize.height)

            PulseScreenshotEditorCanvasOverlay(
                marks: marks,
                activeMark: activeMark
            )
            .frame(width: imageContentSize.width, height: imageContentSize.height)
        }
        .frame(width: imageContentSize.width, height: imageContentSize.height)
        .clipShape(
            RoundedRectangle(
                cornerRadius: PulseScreenshotEditorPanelLayout.cornerRadius,
                style: .continuous
            )
        )
        .contentShape(Rectangle())
        .allowsWindowActivationEvents(true)

        if PulseScreenshotEditInteractionPolicy.allowsImageWindowDragging(selectedTool: selectedTool) {
            content.gesture(WindowDragGesture())
        } else if let selectedTool {
            content.gesture(editGesture(for: selectedTool))
        }
    }

    private func editGesture(for tool: PulseScreenshotEditTool) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                activeMark = PulseScreenshotEditMark(
                    tool: tool,
                    start: normalizedPoint(value.startLocation),
                    end: normalizedPoint(value.location)
                )
            }
            .onEnded { value in
                let mark = PulseScreenshotEditMark(
                    tool: tool,
                    start: normalizedPoint(value.startLocation),
                    end: normalizedPoint(value.location)
                )
                .resolvingTinyDrag(minimumUnitSpan: minimumUnitSpan)
                marks.append(mark)
                activeMark = nil
            }
    }

    private var minimumUnitSpan: CGSize {
        CGSize(
            width: min(0.12, max(0.02, 18 / max(1, imageContentSize.width))),
            height: min(0.12, max(0.02, 18 / max(1, imageContentSize.height)))
        )
    }

    private var toolbar: some View {
        HStack(spacing: PulseDesign.Spacing.sm) {
            HStack(spacing: PulseDesign.Spacing.xxs) {
                ForEach(PulseScreenshotEditTool.allCases) { tool in
                    toolButton(tool)
                }
            }

            Divider()
                .frame(height: 24)
                .overlay(.white.opacity(0.16))

            Button(action: undoLastMark) {
                Text(strings.text(.screenshotEditorUndo))
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(marks.isEmpty ? 0.42 : 0.86))
                    .frame(height: 30)
                    .padding(.horizontal, PulseDesign.Spacing.sm)
                    .background(
                        .white.opacity(marks.isEmpty ? 0.04 : 0.10),
                        in: RoundedRectangle(cornerRadius: PulseDesign.Radius.control, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .disabled(marks.isEmpty)

            Spacer(minLength: PulseDesign.Spacing.sm)

            Button(action: closeAction) {
                Text(strings.text(.screenshotEditorCancel))
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.78))
                    .frame(height: 30)
                    .padding(.horizontal, PulseDesign.Spacing.sm)
                    .background(
                        .white.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: PulseDesign.Radius.control, style: .continuous)
                    )
            }
            .buttonStyle(.plain)

            Button(action: completeEditing) {
                Text(strings.text(.screenshotEditorDone))
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.88))
                    .frame(height: 30)
                    .padding(.horizontal, PulseDesign.Spacing.sm)
                    .background(
                        .orange.opacity(0.94),
                        in: RoundedRectangle(cornerRadius: PulseDesign.Radius.control, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, PulseDesign.Spacing.compact)
        .frame(width: contentWidth)
        .frame(height: PulseScreenshotEditorPanelLayout.toolbarHeight)
        .background(
            .black.opacity(0.72),
            in: RoundedRectangle(
                cornerRadius: PulseScreenshotEditorPanelLayout.cornerRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: PulseScreenshotEditorPanelLayout.cornerRadius,
                style: .continuous
            )
            .stroke(.white.opacity(0.10), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: PulseScreenshotEditorPanelLayout.cornerRadius, style: .continuous))
        .simultaneousGesture(WindowDragGesture())
        .allowsWindowActivationEvents(true)
    }

    private func toolButton(_ tool: PulseScreenshotEditTool) -> some View {
        let isSelected = selectedTool == tool
        return Button {
            activeMark = nil
            selectedTool = PulseScreenshotEditInteractionPolicy.selectedTool(
                afterTapping: tool,
                currentSelection: selectedTool
            )
        } label: {
            VStack(spacing: PulseDesign.Spacing.micro) {
                PulseScreenshotEditorToolIcon(tool: tool)
                    .frame(width: 18, height: 18)

                Text(strings.screenshotEditorToolTitle(tool))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(isSelected ? .black.opacity(0.88) : .white.opacity(0.84))
            .frame(width: 54, height: 42)
            .background(
                isSelected ? .orange.opacity(0.94) : .white.opacity(0.08),
                in: RoundedRectangle(cornerRadius: PulseDesign.Radius.control, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .help(strings.screenshotEditorToolTitle(tool))
        .accessibilityLabel(strings.screenshotEditorToolTitle(tool))
    }

    private func undoLastMark() {
        guard !marks.isEmpty else {
            return
        }

        marks.removeLast()
    }

    private func completeEditing() {
        guard let editedImage = PulseScreenshotEditRenderer.renderedImage(base: image, marks: marks) else {
            NSSound.beep()
            return
        }

        completeAction(editedImage)
    }

    private func normalizedPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x / max(1, imageContentSize.width), 0), 1),
            y: min(max(point.y / max(1, imageContentSize.height), 0), 1)
        )
    }
}

private struct PulseScreenshotEditorCanvasOverlay: View {
    var marks: [PulseScreenshotEditMark]
    var activeMark: PulseScreenshotEditMark?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(marks) { mark in
                    PulseScreenshotEditorMarkView(mark: mark, canvasSize: proxy.size)
                }

                if let activeMark {
                    PulseScreenshotEditorMarkView(mark: activeMark, canvasSize: proxy.size)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct PulseScreenshotEditorMarkView: View {
    var mark: PulseScreenshotEditMark
    var canvasSize: CGSize

    var body: some View {
        switch mark.tool {
        case .mosaic:
            PulseScreenshotMosaicPattern()
                .frame(width: rect.width, height: rect.height)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(.orange.opacity(0.42), lineWidth: 2)
                }
                .position(x: rect.midX, y: rect.midY)
        case .rectangle:
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(.orange.opacity(0.10))
                .overlay {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(.orange.opacity(0.96), lineWidth: 3)
                }
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
        case .ellipse:
            Ellipse()
                .fill(.orange.opacity(0.10))
                .overlay {
                    Ellipse()
                        .stroke(.orange.opacity(0.96), lineWidth: 3)
                }
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
        case .arrow:
            PulseScreenshotArrowShape(
                start: point(mark.start),
                end: point(mark.end)
            )
            .stroke(.orange.opacity(0.96), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
        }
    }

    private var rect: CGRect {
        let unitRect = mark.unitRect
        return CGRect(
            x: unitRect.minX * canvasSize.width,
            y: unitRect.minY * canvasSize.height,
            width: max(1, unitRect.width * canvasSize.width),
            height: max(1, unitRect.height * canvasSize.height)
        )
    }

    private func point(_ unitPoint: CGPoint) -> CGPoint {
        CGPoint(x: unitPoint.x * canvasSize.width, y: unitPoint.y * canvasSize.height)
    }
}

private struct PulseScreenshotMosaicPattern: View {
    private let tileSide: CGFloat = 10
    private let colors: [Color] = [
        Color(white: 0.08),
        Color(white: 0.24),
        Color(white: 0.40),
        Color(white: 0.62)
    ]

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let columns = max(1, Int(ceil(size.width / tileSide)))
                let rows = max(1, Int(ceil(size.height / tileSide)))

                for row in 0..<rows {
                    for column in 0..<columns {
                        let color = colors[(row * 7 + column * 11) % colors.count]
                        context.fill(
                            Path(
                                CGRect(
                                    x: CGFloat(column) * tileSide,
                                    y: CGFloat(row) * tileSide,
                                    width: min(tileSide, size.width - CGFloat(column) * tileSide),
                                    height: min(tileSide, size.height - CGFloat(row) * tileSide)
                                )
                                .insetBy(dx: 0.5, dy: 0.5)
                            ),
                            with: .color(color)
                        )
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private struct PulseScreenshotArrowShape: Shape {
    var start: CGPoint
    var end: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)

        let angle = atan2(end.y - start.y, end.x - start.x)
        let headLength: CGFloat = 14
        let spread: CGFloat = 0.68
        let left = CGPoint(
            x: end.x - cos(angle - spread) * headLength,
            y: end.y - sin(angle - spread) * headLength
        )
        let right = CGPoint(
            x: end.x - cos(angle + spread) * headLength,
            y: end.y - sin(angle + spread) * headLength
        )
        path.move(to: end)
        path.addLine(to: left)
        path.move(to: end)
        path.addLine(to: right)
        return path
    }
}

private struct PulseScreenshotEditorToolIcon: View {
    var tool: PulseScreenshotEditTool

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size).insetBy(dx: 2, dy: 2)
                switch tool {
                case .mosaic:
                    let tileSide = max(3, rect.width / 3)
                    for row in 0..<3 {
                        for column in 0..<3 {
                            let shade = 0.22 + Double((row + column) % 3) * 0.22
                            context.fill(
                                Path(
                                    CGRect(
                                        x: rect.minX + CGFloat(column) * tileSide,
                                        y: rect.minY + CGFloat(row) * tileSide,
                                        width: tileSide - 1,
                                        height: tileSide - 1
                                    )
                                ),
                                with: .color(Color(white: shade))
                            )
                        }
                    }
                case .rectangle:
                    context.stroke(Path(roundedRect: rect, cornerRadius: 2), with: .color(.primary), lineWidth: 2)
                case .ellipse:
                    context.stroke(Path(ellipseIn: rect), with: .color(.primary), lineWidth: 2)
                case .arrow:
                    var path = Path()
                    path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
                    path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
                    path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
                    path.addLine(to: CGPoint(x: rect.maxX - 7, y: rect.minY + 1))
                    path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
                    path.addLine(to: CGPoint(x: rect.maxX - 1, y: rect.minY + 7))
                    context.stroke(path, with: .color(.primary), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private final class PulseScreenshotEditorPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override func cancelOperation(_ sender: Any?) {
        close()
    }
}

@MainActor
private final class PulseScreenshotEditorHostingView: NSHostingView<AnyView> {
    override var mouseDownCanMoveWindow: Bool {
        false
    }

    required init(rootView: AnyView) {
        super.init(rootView: rootView)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.cornerRadius = PulseScreenshotEditorPanelLayout.cornerRadius
        layer?.cornerCurve = .continuous
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
