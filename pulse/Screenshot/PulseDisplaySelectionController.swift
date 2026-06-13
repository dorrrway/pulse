import AppKit
import CoreGraphics

@MainActor
final class PulseDisplaySelectionController {
    private var continuation: CheckedContinuation<CGDirectDisplayID?, Never>?
    private var windows: [PulseDisplaySelectionWindow] = []
    private var keyMonitor: Any?
    private var didFinish = false

    func selectDisplay(
        strings: PulseStrings,
        preferredScreen: NSScreen?,
        screens: [NSScreen] = NSScreen.screens
    ) async -> CGDirectDisplayID? {
        let displays = screens.enumerated().compactMap { index, screen -> PulseSelectableDisplay? in
            guard let display = PulseScreenRecordingSelectionDisplay(screen: screen) else {
                return nil
            }

            return PulseSelectableDisplay(
                display: display,
                title: screen.localizedName,
                ordinal: index + 1
            )
        }

        guard !displays.isEmpty else {
            return PulseCaptureDisplayResolver.displayID(for: preferredScreen)
        }

        guard displays.count > 1 else {
            return displays[0].display.displayID
        }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            present(displays: displays, strings: strings)
        }
    }

    private func present(displays: [PulseSelectableDisplay], strings: PulseStrings) {
        didFinish = false
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

        for selectableDisplay in displays {
            let window = PulseDisplaySelectionWindow(
                contentRect: selectableDisplay.display.screenFrame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            let overlayView = PulseDisplaySelectionOverlayView(
                display: selectableDisplay,
                hint: strings.text(.displaySelectionHint),
                hoveredHint: strings.text(.displaySelectionHoveredHint)
            )
            overlayView.selectAction = { [weak self] displayID in
                self?.finish(with: displayID)
            }
            overlayView.cancelAction = { [weak self] in
                self?.finish(with: nil)
            }

            window.contentView = overlayView
            window.setFrame(selectableDisplay.display.screenFrame, display: true)
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
        }

        windows.first?.makeKey()
    }

    private func finish(with displayID: CGDirectDisplayID?) {
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
        NSCursor.arrow.set()

        continuation?.resume(returning: displayID)
        continuation = nil
    }
}

private struct PulseSelectableDisplay {
    var display: PulseScreenRecordingSelectionDisplay
    var title: String
    var ordinal: Int
}

private final class PulseDisplaySelectionWindow: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }
}

private final class PulseDisplaySelectionOverlayView: NSView {
    private enum Appearance {
        static let dimmingOpacity: CGFloat = 0.58
        static let hoveredDimmingOpacity: CGFloat = 0.38
        static let cardSize = CGSize(width: 260, height: 132)
        static let cardCornerRadius: CGFloat = 24
        static let numberDiameter: CGFloat = 44
    }

    var selectAction: ((CGDirectDisplayID) -> Void)?
    var cancelAction: (() -> Void)?

    private let display: PulseSelectableDisplay
    private let hint: String
    private let hoveredHint: String
    private var trackingArea: NSTrackingArea?
    private var isHovered = false {
        didSet {
            guard oldValue != isHovered else {
                return
            }

            needsDisplay = true
        }
    }

    init(display: PulseSelectableDisplay, hint: String, hoveredHint: String) {
        self.display = display
        self.hint = hint
        self.hoveredHint = hoveredHint
        super.init(frame: CGRect(origin: .zero, size: display.display.screenFrame.size))
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        refreshHoverState()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .mouseMoved, .inVisibleRect],
            owner: self
        )
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
        refreshHoverState()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }

    override func mouseMoved(with event: NSEvent) {
        isHovered = bounds.contains(convert(event.locationInWindow, from: nil))
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }

    override func mouseDown(with event: NSEvent) {
        selectAction?(display.display.displayID)
    }

    override func mouseUp(with event: NSEvent) {}

    override func rightMouseDown(with event: NSEvent) {
        cancelAction?()
    }

    override func keyDown(with event: NSEvent) {
        guard event.keyCode == 53 else {
            super.keyDown(with: event)
            return
        }

        cancelAction?()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.black.withAlphaComponent(isHovered ? Appearance.hoveredDimmingOpacity : Appearance.dimmingOpacity).setFill()
        bounds.fill()

        let cardRect = CGRect(
            x: bounds.midX - Appearance.cardSize.width / 2,
            y: bounds.midY - Appearance.cardSize.height / 2,
            width: Appearance.cardSize.width,
            height: Appearance.cardSize.height
        )
        let cardPath = NSBezierPath(
            roundedRect: cardRect,
            xRadius: Appearance.cardCornerRadius,
            yRadius: Appearance.cardCornerRadius
        )
        NSColor.black.withAlphaComponent(isHovered ? 0.86 : 0.62).setFill()
        cardPath.fill()
        NSColor.white.withAlphaComponent(isHovered ? 0.20 : 0.08).setStroke()
        cardPath.lineWidth = 1
        cardPath.stroke()

        let numberRect = CGRect(
            x: cardRect.midX - Appearance.numberDiameter / 2,
            y: cardRect.maxY - Appearance.numberDiameter - 22,
            width: Appearance.numberDiameter,
            height: Appearance.numberDiameter
        )
        let numberPath = NSBezierPath(ovalIn: numberRect)
        NSColor.systemBlue.withAlphaComponent(isHovered ? 0.96 : 0.62).setFill()
        numberPath.fill()

        drawCenteredText(
            "\(display.ordinal)",
            in: numberRect.offsetBy(dx: 0, dy: -1),
            font: .systemFont(ofSize: 22, weight: .bold),
            color: .white
        )

        drawCenteredText(
            display.title,
            in: CGRect(x: cardRect.minX + 18, y: cardRect.minY + 34, width: cardRect.width - 36, height: 24),
            font: .systemFont(ofSize: 16, weight: .semibold),
            color: NSColor.white.withAlphaComponent(isHovered ? 0.94 : 0.68)
        )

        drawCenteredText(
            isHovered ? hoveredHint : hint,
            in: CGRect(x: cardRect.minX + 18, y: cardRect.minY + 14, width: cardRect.width - 36, height: 18),
            font: .systemFont(ofSize: 12, weight: .medium),
            color: NSColor.white.withAlphaComponent(isHovered ? 0.76 : 0.42)
        )
    }

    private func refreshHoverState() {
        guard let window else {
            isHovered = false
            return
        }

        isHovered = bounds.contains(convert(window.mouseLocationOutsideOfEventStream, from: nil))
    }

    private func drawCenteredText(
        _ text: String,
        in rect: CGRect,
        font: NSFont,
        color: NSColor
    ) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedString.size()
        let textRect = CGRect(
            x: rect.minX,
            y: rect.midY - textSize.height / 2,
            width: rect.width,
            height: textSize.height
        )
        attributedString.draw(in: textRect)
    }
}
