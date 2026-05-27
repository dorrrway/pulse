import AppKit

enum PulseScreenshotEditTool: CaseIterable, Equatable, Identifiable {
    case mosaic
    case rectangle
    case ellipse
    case arrow

    var id: Self {
        self
    }
}

enum PulseScreenshotEditInteractionPolicy {
    static let defaultSelectedTool: PulseScreenshotEditTool? = nil

    static func selectedTool(
        afterTapping tool: PulseScreenshotEditTool,
        currentSelection: PulseScreenshotEditTool?
    ) -> PulseScreenshotEditTool? {
        currentSelection == tool ? nil : tool
    }

    static func allowsImageWindowDragging(selectedTool: PulseScreenshotEditTool?) -> Bool {
        selectedTool == nil
    }
}

struct PulseScreenshotEditMark: Equatable, Identifiable {
    let id: UUID
    var tool: PulseScreenshotEditTool
    var start: CGPoint
    var end: CGPoint

    init(
        id: UUID = UUID(),
        tool: PulseScreenshotEditTool,
        start: CGPoint,
        end: CGPoint
    ) {
        self.id = id
        self.tool = tool
        self.start = start.clampedToUnit()
        self.end = end.clampedToUnit()
    }

    var unitRect: CGRect {
        let minX = min(start.x, end.x)
        let minY = min(start.y, end.y)
        return CGRect(
            x: minX,
            y: minY,
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    func resolvingTinyDrag(minimumUnitSpan: CGSize) -> PulseScreenshotEditMark {
        let span = CGSize(width: abs(end.x - start.x), height: abs(end.y - start.y))

        switch tool {
        case .arrow:
            guard span.width < minimumUnitSpan.width, span.height < minimumUnitSpan.height else {
                return self
            }

            let proposedEnd = CGPoint(
                x: min(1, start.x + minimumUnitSpan.width * 2.4),
                y: min(1, start.y + minimumUnitSpan.height * 1.6)
            )
            return PulseScreenshotEditMark(tool: tool, start: start, end: proposedEnd)

        case .mosaic, .rectangle, .ellipse:
            guard span.width < minimumUnitSpan.width || span.height < minimumUnitSpan.height else {
                return self
            }

            let halfWidth = max(span.width, minimumUnitSpan.width) / 2
            let halfHeight = max(span.height, minimumUnitSpan.height) / 2
            let resolvedStart = CGPoint(
                x: max(0, start.x - halfWidth),
                y: max(0, start.y - halfHeight)
            )
            let resolvedEnd = CGPoint(
                x: min(1, start.x + halfWidth),
                y: min(1, start.y + halfHeight)
            )
            return PulseScreenshotEditMark(tool: tool, start: resolvedStart, end: resolvedEnd)
        }
    }
}

extension PulseScreenshotEditMark {
    func rect(in imageSize: CGSize) -> CGRect {
        let rect = unitRect
        return CGRect(
            x: rect.minX * imageSize.width,
            y: (1 - rect.maxY) * imageSize.height,
            width: rect.width * imageSize.width,
            height: rect.height * imageSize.height
        )
    }

    func startPoint(in imageSize: CGSize) -> CGPoint {
        CGPoint(x: start.x * imageSize.width, y: (1 - start.y) * imageSize.height)
    }

    func endPoint(in imageSize: CGSize) -> CGPoint {
        CGPoint(x: end.x * imageSize.width, y: (1 - end.y) * imageSize.height)
    }
}

enum PulseScreenshotEditRenderer {
    private static let accentColor = NSColor(calibratedRed: 1, green: 0.57, blue: 0.12, alpha: 1)

    static func renderedImage(base image: NSImage, marks: [PulseScreenshotEditMark]) -> NSImage? {
        let size = normalizedImageSize(image.size)
        let renderedImage = NSImage(size: size)

        renderedImage.lockFocus()
        defer {
            renderedImage.unlockFocus()
        }

        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1
        )

        for mark in marks {
            draw(mark, imageSize: size)
        }

        return renderedImage
    }

    private static func normalizedImageSize(_ size: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0 else {
            return CGSize(width: 1, height: 1)
        }

        return size
    }

    private static func draw(_ mark: PulseScreenshotEditMark, imageSize: CGSize) {
        switch mark.tool {
        case .mosaic:
            drawMosaic(in: mark.rect(in: imageSize), imageSize: imageSize)
        case .rectangle:
            drawRectangle(in: mark.rect(in: imageSize), imageSize: imageSize)
        case .ellipse:
            drawEllipse(in: mark.rect(in: imageSize), imageSize: imageSize)
        case .arrow:
            drawArrow(from: mark.startPoint(in: imageSize), to: mark.endPoint(in: imageSize), imageSize: imageSize)
        }
    }

    private static func drawMosaic(in rect: CGRect, imageSize: CGSize) {
        guard rect.width > 1, rect.height > 1 else {
            return
        }

        let tileSide = max(8, min(rect.width, rect.height) / 8)
        let colors = [
            NSColor(calibratedWhite: 0.10, alpha: 1),
            NSColor(calibratedWhite: 0.26, alpha: 1),
            NSColor(calibratedWhite: 0.42, alpha: 1),
            NSColor(calibratedWhite: 0.64, alpha: 1)
        ]

        NSColor(calibratedWhite: 0.06, alpha: 1).setFill()
        rect.fill()

        let columns = max(1, Int(ceil(rect.width / tileSide)))
        let rows = max(1, Int(ceil(rect.height / tileSide)))
        for row in 0..<rows {
            for column in 0..<columns {
                colors[(row * 7 + column * 11) % colors.count].setFill()
                CGRect(
                    x: rect.minX + CGFloat(column) * tileSide,
                    y: rect.minY + CGFloat(row) * tileSide,
                    width: min(tileSide, rect.maxX - (rect.minX + CGFloat(column) * tileSide)),
                    height: min(tileSide, rect.maxY - (rect.minY + CGFloat(row) * tileSide))
                )
                .insetBy(dx: 0.5, dy: 0.5)
                .fill()
            }
        }

        accentColor.withAlphaComponent(0.32).setStroke()
        let outline = NSBezierPath(roundedRect: rect, xRadius: lineWidth(for: imageSize), yRadius: lineWidth(for: imageSize))
        outline.lineWidth = lineWidth(for: imageSize)
        outline.stroke()
    }

    private static func drawRectangle(in rect: CGRect, imageSize: CGSize) {
        guard rect.width > 1, rect.height > 1 else {
            return
        }

        let path = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
        accentColor.withAlphaComponent(0.12).setFill()
        path.fill()
        accentColor.setStroke()
        path.lineJoinStyle = .round
        path.lineWidth = lineWidth(for: imageSize)
        path.stroke()
    }

    private static func drawEllipse(in rect: CGRect, imageSize: CGSize) {
        guard rect.width > 1, rect.height > 1 else {
            return
        }

        let path = NSBezierPath(ovalIn: rect)
        accentColor.withAlphaComponent(0.10).setFill()
        path.fill()
        accentColor.setStroke()
        path.lineWidth = lineWidth(for: imageSize)
        path.stroke()
    }

    private static func drawArrow(from start: CGPoint, to end: CGPoint, imageSize: CGSize) {
        let distance = hypot(end.x - start.x, end.y - start.y)
        guard distance > 1 else {
            return
        }

        let lineWidth = lineWidth(for: imageSize)
        let linePath = NSBezierPath()
        linePath.move(to: start)
        linePath.line(to: end)
        linePath.lineCapStyle = .round
        linePath.lineJoinStyle = .round
        linePath.lineWidth = lineWidth
        accentColor.setStroke()
        linePath.stroke()

        let headLength = max(12, lineWidth * 4)
        let angle = atan2(end.y - start.y, end.x - start.x)
        let spread: CGFloat = 0.68
        let left = CGPoint(
            x: end.x - cos(angle - spread) * headLength,
            y: end.y - sin(angle - spread) * headLength
        )
        let right = CGPoint(
            x: end.x - cos(angle + spread) * headLength,
            y: end.y - sin(angle + spread) * headLength
        )
        let headPath = NSBezierPath()
        headPath.move(to: end)
        headPath.line(to: left)
        headPath.move(to: end)
        headPath.line(to: right)
        headPath.lineCapStyle = .round
        headPath.lineJoinStyle = .round
        headPath.lineWidth = lineWidth
        headPath.stroke()
    }

    private static func lineWidth(for imageSize: CGSize) -> CGFloat {
        max(3, min(imageSize.width, imageSize.height) * 0.005)
    }
}

private extension CGPoint {
    func clampedToUnit() -> CGPoint {
        CGPoint(
            x: min(max(x, 0), 1),
            y: min(max(y, 0), 1)
        )
    }
}
