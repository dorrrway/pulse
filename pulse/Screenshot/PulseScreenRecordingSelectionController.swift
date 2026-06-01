import AppKit
import CoreGraphics
import QuartzCore

nonisolated struct PulseScreenRecordingSelectionDisplay: Equatable {
    let displayID: CGDirectDisplayID
    let screenFrame: CGRect
    let displayBounds: CGRect

    init(
        displayID: CGDirectDisplayID,
        screenFrame: CGRect,
        displayBounds: CGRect
    ) {
        self.displayID = displayID
        self.screenFrame = screenFrame
        self.displayBounds = displayBounds
    }

    @MainActor
    init?(screen: NSScreen) {
        guard
            let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else {
            return nil
        }

        let displayID = screenNumber.uint32Value
        self.init(
            displayID: displayID,
            screenFrame: screen.frame,
            displayBounds: CGDisplayBounds(displayID)
        )
    }

    nonisolated func cgPoint(fromAppKitScreenPoint point: CGPoint) -> CGPoint {
        let localX = point.x - screenFrame.minX
        let localYFromTop = screenFrame.maxY - point.y
        return CGPoint(
            x: displayBounds.minX + localX * xScale,
            y: displayBounds.minY + localYFromTop * yScale
        )
    }

    nonisolated func viewRect(fromCGRect rect: CGRect) -> CGRect? {
        let clippedRect = displayBounds.intersection(rect.standardized)
        guard !clippedRect.isNull, !clippedRect.isEmpty else {
            return nil
        }

        let width = clippedRect.width / xScale
        let height = clippedRect.height / yScale
        let x = (clippedRect.minX - displayBounds.minX) / xScale
        let yFromTop = (clippedRect.minY - displayBounds.minY) / yScale
        return CGRect(
            x: x,
            y: screenFrame.height - yFromTop - height,
            width: width,
            height: height
        )
    }

    nonisolated func clampedCGPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x, displayBounds.minX), displayBounds.maxX),
            y: min(max(point.y, displayBounds.minY), displayBounds.maxY)
        )
    }

    private nonisolated var xScale: CGFloat {
        displayBounds.width / max(1, screenFrame.width)
    }

    private nonisolated var yScale: CGFloat {
        displayBounds.height / max(1, screenFrame.height)
    }
}

nonisolated enum PulseScreenRecordingSelectionGeometry {
    static let minimumSelectionDimension: CGFloat = 8

    static func selectionRect(
        from startPoint: CGPoint,
        to currentPoint: CGPoint,
        in displayBounds: CGRect
    ) -> CGRect {
        let clampedStart = clamped(startPoint, to: displayBounds)
        let clampedCurrent = clamped(currentPoint, to: displayBounds)
        return CGRect(
            x: min(clampedStart.x, clampedCurrent.x),
            y: min(clampedStart.y, clampedCurrent.y),
            width: abs(clampedCurrent.x - clampedStart.x),
            height: abs(clampedCurrent.y - clampedStart.y)
        )
        .standardized
        .integral
    }

    static func isValidSelectionRect(_ rect: CGRect) -> Bool {
        rect.width >= minimumSelectionDimension
            && rect.height >= minimumSelectionDimension
            && rect.minX.isFinite
            && rect.minY.isFinite
            && rect.width.isFinite
            && rect.height.isFinite
    }

    static func renderableSelectionStrokeRect(
        from rect: CGRect,
        inset: CGFloat = 1
    ) -> CGRect? {
        let standardizedRect = rect.standardized
        guard
            standardizedRect.minX.isFinite,
            standardizedRect.minY.isFinite,
            standardizedRect.width.isFinite,
            standardizedRect.height.isFinite,
            standardizedRect.width > inset * 2,
            standardizedRect.height > inset * 2
        else {
            return nil
        }

        let strokeRect = standardizedRect.insetBy(dx: inset, dy: inset).standardized
        guard
            strokeRect.minX.isFinite,
            strokeRect.minY.isFinite,
            strokeRect.width.isFinite,
            strokeRect.height.isFinite,
            strokeRect.width > 0,
            strokeRect.height > 0
        else {
            return nil
        }

        return strokeRect
    }

    private static func clamped(_ point: CGPoint, to bounds: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(point.x, bounds.minX), bounds.maxX),
            y: min(max(point.y, bounds.minY), bounds.maxY)
        )
    }
}

nonisolated enum PulseScreenRecordingRegionOverlayGeometry {
    static func selectedDisplayID(
        for selectionRect: CGRect,
        displays: [PulseScreenRecordingSelectionDisplay]
    ) -> CGDirectDisplayID? {
        displays
            .map { display in
                (
                    displayID: display.displayID,
                    area: display.displayBounds.intersection(selectionRect.standardized).area
                )
            }
            .filter { $0.area > 0 }
            .max { $0.area < $1.area }?
            .displayID
    }

    static func selectedViewRect(
        for selectionRect: CGRect,
        display: PulseScreenRecordingSelectionDisplay,
        selectedDisplayID: CGDirectDisplayID
    ) -> CGRect? {
        guard
            display.displayID == selectedDisplayID,
            let viewRect = display.viewRect(fromCGRect: selectionRect)
        else {
            return nil
        }

        let displayViewBounds = CGRect(origin: .zero, size: display.screenFrame.size)
        let clippedRect = viewRect.intersection(displayViewBounds).standardized
        guard
            !clippedRect.isNull,
            !clippedRect.isEmpty,
            clippedRect.width.isFinite,
            clippedRect.height.isFinite
        else {
            return nil
        }

        return clippedRect
    }
}

@MainActor
final class PulseScreenRecordingSelectionController {
    private var continuation: CheckedContinuation<CGRect?, Never>?
    private var windows: [PulseScreenRecordingSelectionWindow] = []
    private var overlayViews: [PulseScreenRecordingSelectionOverlayView] = []
    private var keyMonitor: Any?
    private var dragStartPoint: CGPoint?
    private var activeDisplay: PulseScreenRecordingSelectionDisplay?
    private var selectionRect: CGRect?
    private var didFinish = false

    func selectRegion(screens: [NSScreen] = NSScreen.screens) async -> CGRect? {
        let displays = screens.compactMap(PulseScreenRecordingSelectionDisplay.init(screen:))
        guard !displays.isEmpty else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            present(displays: displays)
        }
    }

    private func present(displays: [PulseScreenRecordingSelectionDisplay]) {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard event.keyCode == 53 else {
                return event
            }

            Task { @MainActor [weak self] in
                self?.finish(with: nil)
            }
            return nil
        }

        NSApp.activate(ignoringOtherApps: true)

        for display in displays {
            let window = PulseScreenRecordingSelectionWindow(
                contentRect: display.screenFrame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            let overlayView = PulseScreenRecordingSelectionOverlayView(display: display)
            overlayView.beginSelection = { [weak self] display, point in
                self?.beginSelection(on: display, at: point)
            }
            overlayView.updateSelection = { [weak self] point in
                self?.updateSelection(to: point)
            }
            overlayView.endSelection = { [weak self] in
                self?.endSelection()
            }
            overlayView.cancelSelection = { [weak self] in
                self?.finish(with: nil)
            }

            window.contentView = overlayView
            window.setFrame(display.screenFrame, display: true)
            window.level = .screenSaver
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.hidesOnDeactivate = false
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [
                .canJoinAllSpaces,
                .fullScreenAuxiliary,
                .ignoresCycle,
                .stationary
            ]
            window.orderFrontRegardless()

            windows.append(window)
            overlayViews.append(overlayView)
        }

        windows.first?.makeKey()
        updateOverlayViews()
    }

    private func beginSelection(
        on display: PulseScreenRecordingSelectionDisplay,
        at appKitScreenPoint: CGPoint
    ) {
        let startPoint = display.clampedCGPoint(display.cgPoint(fromAppKitScreenPoint: appKitScreenPoint))
        activeDisplay = display
        dragStartPoint = startPoint
        selectionRect = nil
        updateOverlayViews()
    }

    private func updateSelection(to appKitScreenPoint: CGPoint) {
        guard let activeDisplay, let dragStartPoint else {
            return
        }

        let currentPoint = activeDisplay.clampedCGPoint(
            activeDisplay.cgPoint(fromAppKitScreenPoint: appKitScreenPoint)
        )
        selectionRect = PulseScreenRecordingSelectionGeometry.selectionRect(
            from: dragStartPoint,
            to: currentPoint,
            in: activeDisplay.displayBounds
        )
        updateOverlayViews()
    }

    private func endSelection() {
        guard
            let rect = selectionRect,
            PulseScreenRecordingSelectionGeometry.isValidSelectionRect(rect)
        else {
            finish(with: nil)
            return
        }

        finish(with: rect)
    }

    private func updateOverlayViews() {
        let activeDisplayID = activeDisplay?.displayID
        for view in overlayViews {
            view.updateSelection(selectionRect, activeDisplayID: activeDisplayID)
        }
    }

    private func finish(with rect: CGRect?) {
        guard !didFinish else {
            return
        }

        didFinish = true
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = nil

        for window in windows {
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
        overlayViews.removeAll()
        NSCursor.arrow.set()

        continuation?.resume(returning: rect)
        continuation = nil
    }
}

private final class PulseScreenRecordingSelectionWindow: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }
}

private final class PulseScreenRecordingSelectionOverlayView: NSView {
    private enum Appearance {
        static let dimmingOpacity: CGFloat = 0.66
        static let selectionCornerRadius: CGFloat = 5
        static let selectionStrokeWidth: CGFloat = 3
        static let cornerStrokeWidth: CGFloat = 5
        static let labelMargin: CGFloat = 8
        static let labelCornerRadius: CGFloat = 7
        static let labelHorizontalPadding: CGFloat = 18
        static let labelVerticalPadding: CGFloat = 10
    }

    var beginSelection: ((PulseScreenRecordingSelectionDisplay, CGPoint) -> Void)?
    var updateSelection: ((CGPoint) -> Void)?
    var endSelection: (() -> Void)?
    var cancelSelection: (() -> Void)?

    private let display: PulseScreenRecordingSelectionDisplay
    private var selectionRect: CGRect?
    private var activeDisplayID: CGDirectDisplayID?
    private let dimmingLayer = CAShapeLayer()
    private let selectionStrokeLayer = CAShapeLayer()
    private let cornerLayer = CAShapeLayer()
    private let labelBackgroundLayer = CAShapeLayer()
    private let labelTextLayer = CATextLayer()

    init(display: PulseScreenRecordingSelectionDisplay) {
        self.display = display
        super.init(frame: CGRect(origin: .zero, size: display.screenFrame.size))
        configureLayers()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    func updateSelection(_ selectionRect: CGRect?, activeDisplayID: CGDirectDisplayID?) {
        self.selectionRect = selectionRect
        self.activeDisplayID = activeDisplayID
        updateLayers()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else {
            return
        }

        let point = window.convertPoint(toScreen: event.locationInWindow)
        beginSelection?(display, point)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else {
            return
        }

        let point = window.convertPoint(toScreen: event.locationInWindow)
        updateSelection?(point)
    }

    override func mouseUp(with event: NSEvent) {
        endSelection?()
    }

    override func rightMouseDown(with event: NSEvent) {
        cancelSelection?()
    }

    override func keyDown(with event: NSEvent) {
        guard event.keyCode == 53 else {
            super.keyDown(with: event)
            return
        }

        cancelSelection?()
    }

    override func layout() {
        super.layout()
        updateLayers()
    }

    private func configureLayers() {
        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.masksToBounds = false

        dimmingLayer.fillColor = NSColor.black.withAlphaComponent(Appearance.dimmingOpacity).cgColor
        dimmingLayer.fillRule = .evenOdd

        selectionStrokeLayer.fillColor = NSColor.clear.cgColor
        selectionStrokeLayer.strokeColor = NSColor.systemBlue.cgColor
        selectionStrokeLayer.lineWidth = Appearance.selectionStrokeWidth
        selectionStrokeLayer.shadowColor = NSColor.systemBlue.cgColor
        selectionStrokeLayer.shadowOpacity = 0.75
        selectionStrokeLayer.shadowRadius = 10
        selectionStrokeLayer.shadowOffset = .zero

        cornerLayer.fillColor = NSColor.clear.cgColor
        cornerLayer.strokeColor = NSColor.systemBlue.cgColor
        cornerLayer.lineWidth = Appearance.cornerStrokeWidth
        cornerLayer.lineCap = .round
        cornerLayer.lineJoin = .round

        labelBackgroundLayer.fillColor = NSColor.black.withAlphaComponent(0.78).cgColor
        labelTextLayer.foregroundColor = NSColor.white.cgColor
        labelTextLayer.alignmentMode = .center
        labelTextLayer.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        labelTextLayer.fontSize = 12
        labelTextLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2

        layer?.addSublayer(dimmingLayer)
        layer?.addSublayer(selectionStrokeLayer)
        layer?.addSublayer(cornerLayer)
        layer?.addSublayer(labelBackgroundLayer)
        layer?.addSublayer(labelTextLayer)

        updateLayers()
    }

    private func updateLayers() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let currentBounds = bounds
        for layer in [dimmingLayer, selectionStrokeLayer, cornerLayer, labelBackgroundLayer, labelTextLayer] {
            layer.frame = currentBounds
        }

        guard
            currentBounds.width > 0,
            currentBounds.height > 0
        else {
            hideSelectionLayers()
            CATransaction.commit()
            return
        }

        let selectedViewRect = selectedViewRect()
        dimmingLayer.path = dimmingPath(in: currentBounds, selectionRect: selectedViewRect)

        guard
            let selectedViewRect,
            let strokeRect = PulseScreenRecordingSelectionGeometry.renderableSelectionStrokeRect(from: selectedViewRect)
        else {
            hideSelectionLayers()
            CATransaction.commit()
            return
        }

        selectionStrokeLayer.isHidden = false
        cornerLayer.isHidden = false
        selectionStrokeLayer.path = CGPath(
            roundedRect: strokeRect,
            cornerWidth: Appearance.selectionCornerRadius,
            cornerHeight: Appearance.selectionCornerRadius,
            transform: nil
        )
        cornerLayer.path = cornerPath(in: strokeRect)

        if let selectionRect {
            updateSizeLabel(for: selectionRect, in: strokeRect)
        } else {
            labelBackgroundLayer.isHidden = true
            labelTextLayer.isHidden = true
        }

        CATransaction.commit()
    }

    private func selectedViewRect() -> CGRect? {
        guard
            activeDisplayID == display.displayID,
            let selectionRect,
            let selectionViewRect = display.viewRect(fromCGRect: selectionRect)
        else {
            return nil
        }

        return selectionViewRect.intersection(bounds).standardized
    }

    private func dimmingPath(in bounds: CGRect, selectionRect: CGRect?) -> CGPath {
        let path = CGMutablePath()
        path.addRect(bounds)

        if
            let selectionRect,
            selectionRect.width > 0,
            selectionRect.height > 0
        {
            path.addRoundedRect(
                in: selectionRect,
                cornerWidth: Appearance.selectionCornerRadius,
                cornerHeight: Appearance.selectionCornerRadius
            )
        }

        return path
    }

    private func cornerPath(in rect: CGRect) -> CGPath {
        let handleLength: CGFloat = min(22, max(12, min(rect.width, rect.height) * 0.24))
        let path = CGMutablePath()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + handleLength))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + handleLength, y: rect.minY))

        path.move(to: CGPoint(x: rect.maxX - handleLength, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + handleLength))

        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - handleLength))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - handleLength, y: rect.maxY))

        path.move(to: CGPoint(x: rect.minX + handleLength, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - handleLength))

        return path
    }

    private func updateSizeLabel(for cgRect: CGRect, in selectionRect: CGRect) {
        let text = "\(Int(cgRect.width)) x \(Int(cgRect.height))"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let textSize = NSAttributedString(string: text, attributes: attributes).size()
        let labelSize = CGSize(
            width: textSize.width + Appearance.labelHorizontalPadding,
            height: textSize.height + Appearance.labelVerticalPadding
        )
        let labelOrigin = labelOrigin(
            size: labelSize,
            selectionRect: selectionRect,
            bounds: bounds
        )
        let labelRect = CGRect(origin: labelOrigin, size: labelSize)

        labelBackgroundLayer.isHidden = false
        labelTextLayer.isHidden = false
        labelBackgroundLayer.path = CGPath(
            roundedRect: labelRect,
            cornerWidth: Appearance.labelCornerRadius,
            cornerHeight: Appearance.labelCornerRadius,
            transform: nil
        )
        labelTextLayer.string = text
        labelTextLayer.frame = labelRect.insetBy(dx: 0, dy: 4)
    }

    private func labelOrigin(
        size: CGSize,
        selectionRect: CGRect,
        bounds: CGRect
    ) -> CGPoint {
        let margin = Appearance.labelMargin
        let preferredInsideY = selectionRect.maxY - size.height - margin
        if preferredInsideY >= selectionRect.minY + margin {
            return CGPoint(
                x: min(selectionRect.minX + margin, bounds.maxX - size.width - margin),
                y: preferredInsideY
            )
        }

        let belowY = selectionRect.minY - size.height - margin
        if belowY >= bounds.minY + margin {
            return CGPoint(
                x: min(selectionRect.minX + margin, bounds.maxX - size.width - margin),
                y: belowY
            )
        }

        return CGPoint(
            x: min(selectionRect.minX + margin, bounds.maxX - size.width - margin),
            y: min(selectionRect.maxY + margin, bounds.maxY - size.height - margin)
        )
    }

    private func hideSelectionLayers() {
        selectionStrokeLayer.isHidden = true
        cornerLayer.isHidden = true
        labelBackgroundLayer.isHidden = true
        labelTextLayer.isHidden = true
        selectionStrokeLayer.path = nil
        cornerLayer.path = nil
        labelBackgroundLayer.path = nil
        labelTextLayer.string = nil
    }
}

@MainActor
final class PulseScreenRecordingRegionOverlayController {
    private var windows: [PulseScreenRecordingRegionOverlayWindow] = []
    private(set) var windowIDs: Set<CGWindowID> = []

    func show(
        selectionRect: CGRect,
        screens: [NSScreen] = NSScreen.screens
    ) {
        hide()

        let displays = screens.compactMap(PulseScreenRecordingSelectionDisplay.init(screen:))
        guard
            !displays.isEmpty,
            let selectedDisplayID = PulseScreenRecordingRegionOverlayGeometry.selectedDisplayID(
                for: selectionRect,
                displays: displays
            )
        else {
            return
        }

        for display in displays {
            let window = PulseScreenRecordingRegionOverlayWindow(
                contentRect: display.screenFrame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            window.contentView = PulseScreenRecordingRegionOverlayView(
                display: display,
                selectionRect: selectionRect,
                selectedDisplayID: selectedDisplayID
            )
            window.setFrame(display.screenFrame, display: true)
            window.level = .modalPanel
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.hidesOnDeactivate = false
            window.isReleasedWhenClosed = false
            window.sharingType = .none
            window.collectionBehavior = [
                .canJoinAllSpaces,
                .fullScreenAuxiliary,
                .ignoresCycle,
                .stationary
            ]
            window.orderFrontRegardless()

            windows.append(window)
            if window.windowNumber > 0 {
                windowIDs.insert(CGWindowID(window.windowNumber))
            }
        }
    }

    func hide() {
        for window in windows {
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
        windowIDs.removeAll()
    }
}

private final class PulseScreenRecordingRegionOverlayWindow: NSPanel {
    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}

private final class PulseScreenRecordingRegionOverlayView: NSView {
    private enum Appearance {
        static let dimmingOpacity: CGFloat = 0.66
        static let selectionCornerRadius: CGFloat = 5
        static let selectionStrokeWidth: CGFloat = 3
        static let cornerStrokeWidth: CGFloat = 5
    }

    private let display: PulseScreenRecordingSelectionDisplay
    private let selectionRect: CGRect
    private let selectedDisplayID: CGDirectDisplayID
    private let dimmingLayer = CAShapeLayer()
    private let selectionStrokeLayer = CAShapeLayer()
    private let cornerLayer = CAShapeLayer()

    init(
        display: PulseScreenRecordingSelectionDisplay,
        selectionRect: CGRect,
        selectedDisplayID: CGDirectDisplayID
    ) {
        self.display = display
        self.selectionRect = selectionRect
        self.selectedDisplayID = selectedDisplayID
        super.init(frame: CGRect(origin: .zero, size: display.screenFrame.size))
        configureLayers()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        updateLayers()
    }

    private func configureLayers() {
        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor.clear.cgColor

        dimmingLayer.fillColor = NSColor.black.withAlphaComponent(Appearance.dimmingOpacity).cgColor
        dimmingLayer.fillRule = .evenOdd

        selectionStrokeLayer.fillColor = NSColor.clear.cgColor
        selectionStrokeLayer.strokeColor = NSColor.systemBlue.cgColor
        selectionStrokeLayer.lineWidth = Appearance.selectionStrokeWidth
        selectionStrokeLayer.shadowColor = NSColor.systemBlue.cgColor
        selectionStrokeLayer.shadowOpacity = 0.75
        selectionStrokeLayer.shadowRadius = 10
        selectionStrokeLayer.shadowOffset = .zero

        cornerLayer.fillColor = NSColor.clear.cgColor
        cornerLayer.strokeColor = NSColor.systemBlue.cgColor
        cornerLayer.lineWidth = Appearance.cornerStrokeWidth
        cornerLayer.lineCap = .round
        cornerLayer.lineJoin = .round

        layer?.addSublayer(dimmingLayer)
        layer?.addSublayer(selectionStrokeLayer)
        layer?.addSublayer(cornerLayer)

        updateLayers()
    }

    private func updateLayers() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let currentBounds = bounds
        for layer in [dimmingLayer, selectionStrokeLayer, cornerLayer] {
            layer.frame = currentBounds
        }

        guard
            currentBounds.width > 0,
            currentBounds.height > 0
        else {
            hideSelectionLayers()
            CATransaction.commit()
            return
        }

        let selectedViewRect = PulseScreenRecordingRegionOverlayGeometry.selectedViewRect(
            for: selectionRect,
            display: display,
            selectedDisplayID: selectedDisplayID
        )
        dimmingLayer.path = dimmingPath(in: currentBounds, selectionRect: selectedViewRect)

        guard
            let selectedViewRect,
            let strokeRect = PulseScreenRecordingSelectionGeometry.renderableSelectionStrokeRect(from: selectedViewRect)
        else {
            hideSelectionLayers()
            CATransaction.commit()
            return
        }

        selectionStrokeLayer.isHidden = false
        cornerLayer.isHidden = false
        selectionStrokeLayer.path = CGPath(
            roundedRect: strokeRect,
            cornerWidth: Appearance.selectionCornerRadius,
            cornerHeight: Appearance.selectionCornerRadius,
            transform: nil
        )
        cornerLayer.path = cornerPath(in: strokeRect)

        CATransaction.commit()
    }

    private func dimmingPath(in bounds: CGRect, selectionRect: CGRect?) -> CGPath {
        let path = CGMutablePath()
        path.addRect(bounds)

        if
            let selectionRect,
            selectionRect.width > 0,
            selectionRect.height > 0
        {
            path.addRoundedRect(
                in: selectionRect,
                cornerWidth: Appearance.selectionCornerRadius,
                cornerHeight: Appearance.selectionCornerRadius
            )
        }

        return path
    }

    private func cornerPath(in rect: CGRect) -> CGPath {
        let handleLength: CGFloat = min(22, max(12, min(rect.width, rect.height) * 0.24))
        let path = CGMutablePath()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + handleLength))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + handleLength, y: rect.minY))

        path.move(to: CGPoint(x: rect.maxX - handleLength, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + handleLength))

        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - handleLength))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - handleLength, y: rect.maxY))

        path.move(to: CGPoint(x: rect.minX + handleLength, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - handleLength))

        return path
    }

    private func hideSelectionLayers() {
        selectionStrokeLayer.isHidden = true
        cornerLayer.isHidden = true
        selectionStrokeLayer.path = nil
        cornerLayer.path = nil
    }
}

private extension CGRect {
    nonisolated var area: CGFloat {
        guard !isNull, !isEmpty else {
            return 0
        }

        return width * height
    }
}
