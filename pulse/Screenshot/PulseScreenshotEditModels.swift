import AppKit

enum PulseScreenshotEditTool: CaseIterable, Equatable, Identifiable {
    case rectangle
    case ellipse
    case arrow
    case pen
    case mosaic
    case text

    var id: Self {
        self
    }

    var usesFreehandStroke: Bool {
        switch self {
        case .pen, .mosaic:
            true
        case .rectangle, .ellipse, .arrow, .text:
            false
        }
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

enum PulseScreenshotMosaicBrush {
    static let displayDiameter: CGFloat = 34
    static let minimumDisplayPointSpacing: CGFloat = 3

    static func unitDiameter(for displaySize: CGSize) -> CGFloat {
        displayDiameter / max(1, min(displaySize.width, displaySize.height))
    }
}

enum PulseScreenshotInkBrush {
    static let displayDiameter: CGFloat = 5
    static let minimumDisplayPointSpacing: CGFloat = 2

    static func unitDiameter(for displaySize: CGSize) -> CGFloat {
        displayDiameter / max(1, min(displaySize.width, displaySize.height))
    }
}

enum PulseScreenshotTextStyle {
    static func fontSize(for imageSize: CGSize) -> CGFloat {
        max(18, min(42, min(imageSize.width, imageSize.height) * 0.04))
    }
}

enum PulseScreenshotMosaicImageFactory {
    static func pixelatedImage(base image: NSImage, size: CGSize) -> NSImage {
        let canvasSize = normalizedImageSize(size)
        let side = pixelSide(for: canvasSize)
        let sampleSize = CGSize(
            width: max(1, ceil(canvasSize.width / side)),
            height: max(1, ceil(canvasSize.height / side))
        )
        let sampleImage = NSImage(size: sampleSize)

        sampleImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .medium
        image.draw(
            in: NSRect(origin: .zero, size: sampleSize),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1
        )
        sampleImage.unlockFocus()

        let pixelatedImage = NSImage(size: canvasSize)
        pixelatedImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .none
        sampleImage.draw(
            in: NSRect(origin: .zero, size: canvasSize),
            from: NSRect(origin: .zero, size: sampleSize),
            operation: .copy,
            fraction: 1
        )
        pixelatedImage.unlockFocus()

        return pixelatedImage
    }

    private static func normalizedImageSize(_ size: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0 else {
            return CGSize(width: 1, height: 1)
        }

        return size
    }

    private static func pixelSide(for size: CGSize) -> CGFloat {
        max(9, min(22, min(size.width, size.height) * 0.018))
    }
}

enum PulseScreenshotImageExport {
    static func pngData(for image: NSImage) -> Data? {
        if
            let tiffData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData),
            let pngData = bitmap.representation(using: .png, properties: [:])
        {
            return pngData
        }

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        bitmap.size = image.size
        return bitmap.representation(using: .png, properties: [:])
    }

    static func suggestedFileName(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return "Pulse Screenshot \(formatter.string(from: now)).png"
    }
}

struct PulseScreenshotEditStroke: Equatable {
    var points: [CGPoint]
    var brushDiameter: CGFloat

    init(points: [CGPoint], brushDiameter: CGFloat) {
        self.points = points.map { $0.clampedToUnit() }
        self.brushDiameter = min(max(brushDiameter, 0.001), 1)
    }
}

struct PulseScreenshotEditMark: Equatable, Identifiable {
    let id: UUID
    var tool: PulseScreenshotEditTool
    var start: CGPoint
    var end: CGPoint
    private(set) var stroke: PulseScreenshotEditStroke?
    private(set) var text: String?

    init(
        id: UUID = UUID(),
        tool: PulseScreenshotEditTool,
        start: CGPoint,
        end: CGPoint,
        stroke: PulseScreenshotEditStroke? = nil,
        text: String? = nil
    ) {
        self.id = id
        self.tool = tool
        self.start = start.clampedToUnit()
        self.end = end.clampedToUnit()
        self.stroke = tool.usesFreehandStroke ? stroke : nil
        let trimmedText = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.text = tool == .text && trimmedText?.isEmpty == false ? trimmedText : nil
    }

    static func mosaicStroke(
        id: UUID = UUID(),
        points: [CGPoint],
        brushDiameter: CGFloat
    ) -> PulseScreenshotEditMark {
        let stroke = PulseScreenshotEditStroke(points: points, brushDiameter: brushDiameter)
        let firstPoint = stroke.points.first ?? .zero
        let lastPoint = stroke.points.last ?? firstPoint

        return PulseScreenshotEditMark(
            id: id,
            tool: .mosaic,
            start: firstPoint,
            end: lastPoint,
            stroke: stroke
        )
    }

    static func penStroke(
        id: UUID = UUID(),
        points: [CGPoint],
        brushDiameter: CGFloat
    ) -> PulseScreenshotEditMark {
        let stroke = PulseScreenshotEditStroke(points: points, brushDiameter: brushDiameter)
        let firstPoint = stroke.points.first ?? .zero
        let lastPoint = stroke.points.last ?? firstPoint

        return PulseScreenshotEditMark(
            id: id,
            tool: .pen,
            start: firstPoint,
            end: lastPoint,
            stroke: stroke
        )
    }

    static func text(
        id: UUID = UUID(),
        _ value: String,
        at point: CGPoint
    ) -> PulseScreenshotEditMark {
        PulseScreenshotEditMark(
            id: id,
            tool: .text,
            start: point,
            end: point,
            text: value
        )
    }

    func movingText(to point: CGPoint) -> PulseScreenshotEditMark {
        guard tool == .text, let text else {
            return self
        }

        return PulseScreenshotEditMark.text(id: id, text, at: point)
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
        if stroke != nil {
            return self
        }

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

        case .pen, .text:
            return self
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

    var mosaicStroke: PulseScreenshotEditStroke? {
        tool == .mosaic ? stroke : nil
    }

    func strokePoints(in imageSize: CGSize) -> [CGPoint] {
        guard let stroke else {
            return []
        }

        return stroke.points.map { point in
            CGPoint(x: point.x * imageSize.width, y: (1 - point.y) * imageSize.height)
        }
    }

    func strokeBrushDiameter(in imageSize: CGSize) -> CGFloat {
        guard let stroke else {
            return 0
        }

        return max(1, stroke.brushDiameter * min(imageSize.width, imageSize.height))
    }

    var textValue: String? {
        tool == .text ? text : nil
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

        let mosaicImage = marks.contains { $0.tool == .mosaic }
            ? PulseScreenshotMosaicImageFactory.pixelatedImage(base: image, size: size)
            : nil

        for mark in marks {
            draw(mark, imageSize: size, mosaicImage: mosaicImage)
        }

        return renderedImage
    }

    private static func normalizedImageSize(_ size: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0 else {
            return CGSize(width: 1, height: 1)
        }

        return size
    }

    private static func draw(_ mark: PulseScreenshotEditMark, imageSize: CGSize, mosaicImage: NSImage?) {
        switch mark.tool {
        case .mosaic:
            guard let mosaicImage else {
                return
            }

            if mark.mosaicStroke != nil {
                drawMosaicStroke(
                    points: mark.strokePoints(in: imageSize),
                    brushDiameter: mark.strokeBrushDiameter(in: imageSize),
                    imageSize: imageSize,
                    mosaicImage: mosaicImage
                )
            } else {
                drawMosaic(in: mark.rect(in: imageSize), imageSize: imageSize, mosaicImage: mosaicImage)
            }
        case .rectangle:
            drawRectangle(in: mark.rect(in: imageSize), imageSize: imageSize)
        case .ellipse:
            drawEllipse(in: mark.rect(in: imageSize), imageSize: imageSize)
        case .arrow:
            drawArrow(from: mark.startPoint(in: imageSize), to: mark.endPoint(in: imageSize), imageSize: imageSize)
        case .pen:
            drawPenStroke(
                points: mark.strokePoints(in: imageSize),
                brushDiameter: mark.strokeBrushDiameter(in: imageSize),
                imageSize: imageSize
            )
        case .text:
            if let text = mark.textValue {
                drawText(text, at: mark.startPoint(in: imageSize), imageSize: imageSize)
            }
        }
    }

    private static func drawMosaic(in rect: CGRect, imageSize: CGSize, mosaicImage: NSImage) {
        guard rect.width > 1, rect.height > 1, let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        context.saveGState()
        defer {
            context.restoreGState()
        }

        context.clip(to: rect)
        mosaicImage.draw(
            in: NSRect(origin: .zero, size: imageSize),
            from: NSRect(origin: .zero, size: imageSize),
            operation: .sourceOver,
            fraction: 1
        )
    }

    private static func drawMosaicStroke(
        points: [CGPoint],
        brushDiameter: CGFloat,
        imageSize: CGSize,
        mosaicImage: NSImage
    ) {
        guard brushDiameter > 1, !points.isEmpty, let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        let imageRect = CGRect(origin: .zero, size: imageSize)
        let drawingRect = strokeBounds(points: points, brushDiameter: brushDiameter)
            .intersection(imageRect)
        guard drawingRect.width > 0, drawingRect.height > 0 else {
            return
        }

        context.saveGState()
        defer {
            context.restoreGState()
        }

        if points.count == 1, let point = points.first {
            context.addEllipse(in: CGRect(
                x: point.x - brushDiameter / 2,
                y: point.y - brushDiameter / 2,
                width: brushDiameter,
                height: brushDiameter
            ))
            context.clip()
        } else {
            let path = CGMutablePath()
            path.move(to: points[0])
            for point in points.dropFirst() {
                path.addLine(to: point)
            }

            context.addPath(path)
            context.setLineWidth(brushDiameter)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.replacePathWithStrokedPath()
            context.clip()
        }

        mosaicImage.draw(
            in: NSRect(origin: .zero, size: imageSize),
            from: NSRect(origin: .zero, size: imageSize),
            operation: .sourceOver,
            fraction: 1
        )
    }

    private static func strokeBounds(points: [CGPoint], brushDiameter: CGFloat) -> CGRect {
        guard let firstPoint = points.first else {
            return .zero
        }

        var minX = firstPoint.x
        var minY = firstPoint.y
        var maxX = firstPoint.x
        var maxY = firstPoint.y

        for point in points.dropFirst() {
            minX = min(minX, point.x)
            minY = min(minY, point.y)
            maxX = max(maxX, point.x)
            maxY = max(maxY, point.y)
        }

        return CGRect(
            x: minX - brushDiameter / 2,
            y: minY - brushDiameter / 2,
            width: maxX - minX + brushDiameter,
            height: maxY - minY + brushDiameter
        )
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

    private static func drawPenStroke(points: [CGPoint], brushDiameter: CGFloat, imageSize: CGSize) {
        guard brushDiameter > 1, let firstPoint = points.first else {
            return
        }

        let path = NSBezierPath()
        path.move(to: firstPoint)
        if points.count == 1 {
            path.line(to: CGPoint(x: firstPoint.x + 0.1, y: firstPoint.y + 0.1))
        } else {
            for point in points.dropFirst() {
                path.line(to: point)
            }
        }

        accentColor.setStroke()
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.lineWidth = max(lineWidth(for: imageSize), brushDiameter)
        path.stroke()
    }

    private static func drawText(_ text: String, at point: CGPoint, imageSize: CGSize) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        let font = NSFont.systemFont(ofSize: PulseScreenshotTextStyle.fontSize(for: imageSize), weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: accentColor,
            .paragraphStyle: paragraphStyle,
        ]
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedText.size()
        let origin = CGPoint(
            x: min(max(0, point.x - textSize.width / 2), max(0, imageSize.width - textSize.width)),
            y: min(max(0, point.y - textSize.height / 2), max(0, imageSize.height - textSize.height))
        )

        attributedText.draw(at: origin)
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
