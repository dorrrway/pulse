import AppKit
import SwiftUI
import UniformTypeIdentifiers

nonisolated enum PulseScreenshotEditorPanelLayout {
    static let edgeInset: CGFloat = 24
    static let cascadeOffset: CGFloat = 18
    static let cornerRadius: CGFloat = PulsePinnedScreenshotPanelLayout.cornerRadius
    static let toolbarHeight: CGFloat = 54
    static let toolbarGap: CGFloat = 10
    static let minimumToolbarWidth: CGFloat = 700
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
    private var activeSharingPicker: NSSharingServicePicker?

    func edit(
        image: NSImage,
        strings: PulseStrings,
        near pointerLocation: CGPoint = NSEvent.mouseLocation,
        pinAction: ((NSImage) -> Void)? = nil,
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
            saveAction: { image in
                Self.save(image)
            },
            shareAction: { [weak self, weak panel] image in
                self?.share(image, from: panel?.contentView)
            },
            pinAction: pinAction,
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

        return panel
    }

    private static func save(_ image: NSImage) {
        guard let pngData = PulseScreenshotImageExport.pngData(for: image) else {
            NSSound.beep()
            return
        }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.nameFieldStringValue = PulseScreenshotImageExport.suggestedFileName()

        NSApp.activate(ignoringOtherApps: true)

        guard savePanel.runModal() == .OK, let url = savePanel.url else {
            return
        }

        do {
            try pngData.write(to: url, options: .atomic)
        } catch {
            NSSound.beep()
        }
    }

    private func share(_ image: NSImage, from contentView: NSView?) {
        guard let contentView else {
            NSSound.beep()
            return
        }

        activeSharingPicker = NSSharingServicePicker(items: [image])
        let anchorRect = CGRect(
            x: contentView.bounds.midX,
            y: PulseScreenshotEditorPanelLayout.toolbarHeight / 2,
            width: 1,
            height: 1
        )
        activeSharingPicker?.show(relativeTo: anchorRect, of: contentView, preferredEdge: .minY)
    }

    private static func screen(containing point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
    }
}

private struct PulseScreenshotEditorView: View {
    let image: NSImage
    let mosaicPreviewImage: NSImage
    let strings: PulseStrings
    let imageContentSize: CGSize
    var saveAction: (NSImage) -> Void
    var shareAction: (NSImage) -> Void
    var pinAction: ((NSImage) -> Void)?
    var closeAction: () -> Void
    var completeAction: (NSImage) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTool = PulseScreenshotEditInteractionPolicy.defaultSelectedTool
    @State private var marks: [PulseScreenshotEditMark] = []
    @State private var activeMark: PulseScreenshotEditMark?
    @State private var activeStrokePoints: [CGPoint] = []
    @State private var textDraft: PulseScreenshotEditorTextDraft?
    @FocusState private var isTextDraftFocused: Bool

    init(
        image: NSImage,
        strings: PulseStrings,
        imageContentSize: CGSize,
        saveAction: @escaping (NSImage) -> Void,
        shareAction: @escaping (NSImage) -> Void,
        pinAction: ((NSImage) -> Void)?,
        closeAction: @escaping () -> Void,
        completeAction: @escaping (NSImage) -> Void
    ) {
        self.image = image
        self.mosaicPreviewImage = PulseScreenshotMosaicImageFactory.pixelatedImage(
            base: image,
            size: imageContentSize
        )
        self.strings = strings
        self.imageContentSize = imageContentSize
        self.saveAction = saveAction
        self.shareAction = shareAction
        self.pinAction = pinAction
        self.closeAction = closeAction
        self.completeAction = completeAction
    }

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
                activeMark: activeMark,
                mosaicImage: mosaicPreviewImage
            )
            .frame(width: imageContentSize.width, height: imageContentSize.height)

            textDraftEditor
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
        } else if selectedTool == .text, textDraft != nil {
            content
        } else if let selectedTool {
            content.gesture(editGesture(for: selectedTool))
        }
    }

    @ViewBuilder
    private var textDraftEditor: some View {
        if let textDraft {
            TextField(strings.text(.screenshotEditorText), text: textDraftBinding)
                .textFieldStyle(.plain)
                .font(.system(size: textPreviewFontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(.orange.opacity(0.96))
                .padding(.horizontal, PulseDesign.Spacing.xs)
                .padding(.vertical, PulseDesign.Spacing.fine)
                .frame(width: min(max(150, imageContentSize.width * 0.26), 280), alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: PulseDesign.Radius.control, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: PulseDesign.Radius.control, style: .continuous)
                        .stroke(.orange.opacity(0.55), lineWidth: 1)
                }
                .position(
                    x: textDraft.point.x * imageContentSize.width,
                    y: textDraft.point.y * imageContentSize.height
                )
                .focused($isTextDraftFocused)
                .onSubmit {
                    commitTextDraftIfNeeded()
                }
                .onChange(of: isTextDraftFocused) { _, isFocused in
                    if !isFocused {
                        commitTextDraftIfNeeded()
                    }
                }
                .task(id: textDraft.id) {
                    isTextDraftFocused = true
                }
        }
    }

    private func editGesture(for tool: PulseScreenshotEditTool) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if tool == .mosaic {
                    updateActiveMosaicStroke(value)
                } else if tool == .pen {
                    updateActivePenStroke(value)
                } else if tool == .text {
                    beginTextDraft(at: value.startLocation)
                } else {
                    activeMark = PulseScreenshotEditMark(
                        tool: tool,
                        start: normalizedPoint(value.startLocation),
                        end: normalizedPoint(value.location)
                    )
                }
            }
            .onEnded { value in
                if tool == .mosaic {
                    marks.append(finalMosaicStroke(value))
                    activeStrokePoints = []
                } else if tool == .pen {
                    marks.append(finalPenStroke(value))
                    activeStrokePoints = []
                } else if tool == .text {
                    beginTextDraft(at: value.location)
                } else {
                    let mark = PulseScreenshotEditMark(
                        tool: tool,
                        start: normalizedPoint(value.startLocation),
                        end: normalizedPoint(value.location)
                    )
                    .resolvingTinyDrag(minimumUnitSpan: minimumUnitSpan)
                    marks.append(mark)
                }
                activeMark = nil
            }
    }

    private func updateActiveMosaicStroke(_ value: DragGesture.Value) {
        let currentPoint = normalizedPoint(value.location)
        var points = activeStrokePoints
        if points.isEmpty {
            points = [normalizedPoint(value.startLocation)]
        }

        if shouldAppendMosaicPoint(currentPoint, after: points.last) {
            points.append(currentPoint)
        }

        activeStrokePoints = points
        activeMark = PulseScreenshotEditMark.mosaicStroke(
            points: points,
            brushDiameter: mosaicBrushUnitDiameter
        )
    }

    private func finalMosaicStroke(_ value: DragGesture.Value) -> PulseScreenshotEditMark {
        let finalPoint = normalizedPoint(value.location)
        var points = activeStrokePoints.isEmpty ? [normalizedPoint(value.startLocation)] : activeStrokePoints
        if finalPoint != points.last {
            points.append(finalPoint)
        }

        return PulseScreenshotEditMark.mosaicStroke(
            points: points,
            brushDiameter: mosaicBrushUnitDiameter
        )
    }

    private func updateActivePenStroke(_ value: DragGesture.Value) {
        let currentPoint = normalizedPoint(value.location)
        var points = activeStrokePoints
        if points.isEmpty {
            points = [normalizedPoint(value.startLocation)]
        }

        if shouldAppendStrokePoint(
            currentPoint,
            after: points.last,
            minimumDisplaySpacing: PulseScreenshotInkBrush.minimumDisplayPointSpacing
        ) {
            points.append(currentPoint)
        }

        activeStrokePoints = points
        activeMark = PulseScreenshotEditMark.penStroke(
            points: points,
            brushDiameter: penBrushUnitDiameter
        )
    }

    private func finalPenStroke(_ value: DragGesture.Value) -> PulseScreenshotEditMark {
        let finalPoint = normalizedPoint(value.location)
        var points = activeStrokePoints.isEmpty ? [normalizedPoint(value.startLocation)] : activeStrokePoints
        if finalPoint != points.last {
            points.append(finalPoint)
        }

        return PulseScreenshotEditMark.penStroke(
            points: points,
            brushDiameter: penBrushUnitDiameter
        )
    }

    private func shouldAppendMosaicPoint(_ point: CGPoint, after previousPoint: CGPoint?) -> Bool {
        shouldAppendStrokePoint(
            point,
            after: previousPoint,
            minimumDisplaySpacing: PulseScreenshotMosaicBrush.minimumDisplayPointSpacing
        )
    }

    private func shouldAppendStrokePoint(
        _ point: CGPoint,
        after previousPoint: CGPoint?,
        minimumDisplaySpacing: CGFloat
    ) -> Bool {
        guard let previousPoint else {
            return true
        }

        let deltaX = (point.x - previousPoint.x) * imageContentSize.width
        let deltaY = (point.y - previousPoint.y) * imageContentSize.height
        return hypot(deltaX, deltaY) >= minimumDisplaySpacing
    }

    private var mosaicBrushUnitDiameter: CGFloat {
        PulseScreenshotMosaicBrush.unitDiameter(for: imageContentSize)
    }

    private var penBrushUnitDiameter: CGFloat {
        PulseScreenshotInkBrush.unitDiameter(for: imageContentSize)
    }

    private var textPreviewFontSize: CGFloat {
        PulseScreenshotTextStyle.fontSize(for: imageContentSize)
    }

    private var textDraftBinding: Binding<String> {
        Binding(
            get: {
                textDraft?.text ?? ""
            },
            set: { newValue in
                guard var draft = textDraft else {
                    return
                }
                draft.text = newValue
                textDraft = draft
            }
        )
    }

    private func beginTextDraft(at location: CGPoint) {
        guard textDraft == nil else {
            return
        }

        activeMark = nil
        activeStrokePoints = []
        textDraft = PulseScreenshotEditorTextDraft(point: normalizedPoint(location))
        isTextDraftFocused = true
    }

    private func commitTextDraftIfNeeded() {
        guard let mark = textDraftMark() else {
            textDraft = nil
            return
        }

        marks.append(mark)
        textDraft = nil
    }

    private func textDraftMark() -> PulseScreenshotEditMark? {
        guard let textDraft else {
            return nil
        }

        return textDraft.mark()
    }

    private func currentMarks() -> [PulseScreenshotEditMark] {
        guard let mark = textDraftMark() else {
            return marks
        }

        return marks + [mark]
    }

    private var minimumUnitSpan: CGSize {
        CGSize(
            width: min(0.12, max(0.02, 18 / max(1, imageContentSize.width))),
            height: min(0.12, max(0.02, 18 / max(1, imageContentSize.height)))
        )
    }

    private var toolbar: some View {
        HStack(spacing: PulseDesign.Spacing.sm) {
            HStack(spacing: PulseDesign.Spacing.xs) {
                moveButton
            }

            toolbarDivider

            HStack(spacing: PulseDesign.Spacing.xs) {
                ForEach(PulseScreenshotEditTool.allCases) { tool in
                    toolButton(tool)
                }
            }

            toolbarDivider

            HStack(spacing: PulseDesign.Spacing.xs) {
                toolbarIconButton(
                    title: strings.text(.screenshotEditorUndo),
                    systemName: "arrow.uturn.backward",
                    isEnabled: canUndo,
                    action: undoLastMark
                )

                toolbarIconButton(
                    title: strings.text(.screenshotSaveAction),
                    systemName: "square.and.arrow.down",
                    action: saveEditing
                )

                toolbarIconButton(
                    title: strings.text(.screenshotShareAction),
                    systemName: "square.and.arrow.up",
                    action: shareEditing
                )

                toolbarIconButton(
                    title: strings.text(.screenshotPinAction),
                    systemName: "pin",
                    isEnabled: pinAction != nil,
                    action: pinEditing
                )
            }

            toolbarDivider

            HStack(spacing: PulseDesign.Spacing.xs) {
                toolbarIconButton(
                    title: strings.text(.screenshotEditorCancel),
                    systemName: "xmark",
                    tint: .red.opacity(0.92),
                    action: closeAction
                )

                toolbarIconButton(
                    title: strings.text(.screenshotEditorDone),
                    systemName: "checkmark",
                    tint: .green.opacity(0.92),
                    action: completeEditing
                )
            }
        }
        .padding(.horizontal, PulseDesign.Spacing.md)
        .frame(width: contentWidth)
        .frame(height: PulseScreenshotEditorPanelLayout.toolbarHeight)
        .background(
            toolbarBackground,
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
            .stroke(toolbarBorderColor, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: PulseScreenshotEditorPanelLayout.cornerRadius, style: .continuous))
        .simultaneousGesture(WindowDragGesture())
        .allowsWindowActivationEvents(true)
    }

    private var moveButton: some View {
        toolbarIconButton(
            title: strings.text(.screenshotEditorMove),
            systemName: "hand.raised",
            isSelected: selectedTool == nil,
            action: selectMoveTool
        )
    }

    private func toolButton(_ tool: PulseScreenshotEditTool) -> some View {
        let isSelected = selectedTool == tool
        return toolbarIconButton(
            title: strings.screenshotEditorToolTitle(tool),
            isSelected: isSelected,
            action: {
                selectTool(tool)
            }
        ) {
            PulseScreenshotEditorToolIcon(tool: tool)
                .frame(width: 22, height: 22)
        }
    }

    private func toolbarIconButton(
        title: String,
        systemName: String,
        isSelected: Bool = false,
        isEnabled: Bool = true,
        tint: Color? = nil,
        action: @escaping () -> Void
    ) -> some View {
        toolbarIconButton(
            title: title,
            isSelected: isSelected,
            isEnabled: isEnabled,
            tint: tint,
            action: action
        ) {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .regular))
        }
    }

    private func toolbarIconButton<Icon: View>(
        title: String,
        isSelected: Bool = false,
        isEnabled: Bool = true,
        tint: Color? = nil,
        action: @escaping () -> Void,
        @ViewBuilder icon: @escaping () -> Icon
    ) -> some View {
        Button(action: action) {
            icon()
                .foregroundStyle(iconColor(isSelected: isSelected, isEnabled: isEnabled, tint: tint))
                .frame(width: 24, height: 24)
                .frame(width: 40, height: 40)
                .background(
                    buttonBackground(isSelected: isSelected, isEnabled: isEnabled),
                    in: RoundedRectangle(cornerRadius: PulseDesign.Radius.control, style: .continuous)
                )
                .contentShape(RoundedRectangle(cornerRadius: PulseDesign.Radius.control, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .help(title)
        .accessibilityLabel(title)
    }

    private var toolbarDivider: some View {
        Rectangle()
            .fill(toolbarDividerColor)
            .frame(width: 1, height: 24)
    }

    private var toolbarBackground: Color {
        colorScheme == .dark
            ? Color(nsColor: .controlBackgroundColor).opacity(0.96)
            : .white.opacity(0.96)
    }

    private var toolbarBorderColor: Color {
        colorScheme == .dark ? .white.opacity(0.10) : .black.opacity(0.12)
    }

    private var toolbarDividerColor: Color {
        colorScheme == .dark ? .white.opacity(0.12) : .black.opacity(0.12)
    }

    private func buttonBackground(isSelected: Bool, isEnabled: Bool) -> Color {
        guard isEnabled else {
            return .clear
        }

        if isSelected {
            return colorScheme == .dark ? .white.opacity(0.16) : .black.opacity(0.10)
        }

        return .clear
    }

    private func iconColor(isSelected: Bool, isEnabled: Bool, tint: Color?) -> Color {
        guard isEnabled else {
            return colorScheme == .dark ? .white.opacity(0.28) : .black.opacity(0.24)
        }

        if let tint {
            return tint
        }

        if isSelected {
            return .orange.opacity(0.96)
        }

        return colorScheme == .dark ? .white.opacity(0.82) : .black.opacity(0.82)
    }

    private var canUndo: Bool {
        !marks.isEmpty || textDraft != nil
    }

    private func selectTool(_ tool: PulseScreenshotEditTool) {
        commitTextDraftIfNeeded()
        activeMark = nil
        activeStrokePoints = []
        selectedTool = PulseScreenshotEditInteractionPolicy.selectedTool(
            afterTapping: tool,
            currentSelection: selectedTool
        )
    }

    private func selectMoveTool() {
        commitTextDraftIfNeeded()
        activeMark = nil
        activeStrokePoints = []
        selectedTool = nil
    }

    private func undoLastMark() {
        if textDraft != nil {
            textDraft = nil
            return
        }

        guard !marks.isEmpty else {
            return
        }

        marks.removeLast()
    }

    private func saveEditing() {
        performImageAction(saveAction)
    }

    private func shareEditing() {
        performImageAction(shareAction)
    }

    private func pinEditing() {
        guard let pinAction else {
            return
        }

        performImageAction(pinAction)
    }

    private func performImageAction(_ action: (NSImage) -> Void) {
        let renderingMarks = currentMarks()
        guard let editedImage = PulseScreenshotEditRenderer.renderedImage(base: image, marks: renderingMarks) else {
            NSSound.beep()
            return
        }

        commitTextDraftIfNeeded()
        action(editedImage)
    }

    private func completeEditing() {
        let renderingMarks = currentMarks()
        guard let editedImage = PulseScreenshotEditRenderer.renderedImage(base: image, marks: renderingMarks) else {
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

private struct PulseScreenshotEditorTextDraft: Equatable, Identifiable {
    let id = UUID()
    var point: CGPoint
    var text = ""

    func mark() -> PulseScreenshotEditMark? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return nil
        }

        return PulseScreenshotEditMark.text(text, at: point)
    }
}

private struct PulseScreenshotEditorCanvasOverlay: View {
    var marks: [PulseScreenshotEditMark]
    var activeMark: PulseScreenshotEditMark?
    var mosaicImage: NSImage

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(marks) { mark in
                    PulseScreenshotEditorMarkView(
                        mark: mark,
                        canvasSize: proxy.size,
                        mosaicImage: mosaicImage
                    )
                }

                if let activeMark {
                    PulseScreenshotEditorMarkView(
                        mark: activeMark,
                        canvasSize: proxy.size,
                        mosaicImage: mosaicImage
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct PulseScreenshotEditorMarkView: View {
    var mark: PulseScreenshotEditMark
    var canvasSize: CGSize
    var mosaicImage: NSImage

    var body: some View {
        switch mark.tool {
        case .mosaic:
            if let stroke = mark.mosaicStroke {
                Image(nsImage: mosaicImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: canvasSize.width, height: canvasSize.height)
                    .clipShape(PulseScreenshotEditorStrokeShape(stroke: stroke))
            } else {
                Image(nsImage: mosaicImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: canvasSize.width, height: canvasSize.height)
                    .mask {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                    }
            }
        case .pen:
            if let stroke = mark.stroke {
                PulseScreenshotEditorStrokeShape(stroke: stroke)
                    .fill(.orange.opacity(0.96))
            }
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
        case .text:
            if let text = mark.textValue {
                Text(text)
                    .font(.system(size: PulseScreenshotTextStyle.fontSize(for: canvasSize), weight: .semibold, design: .rounded))
                    .foregroundStyle(.orange.opacity(0.96))
                    .shadow(color: .black.opacity(0.22), radius: 2, y: 1)
                    .fixedSize()
                    .position(point(mark.start))
            }
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

private struct PulseScreenshotEditorStrokeShape: Shape {
    var stroke: PulseScreenshotEditStroke

    func path(in rect: CGRect) -> Path {
        let points = stroke.points.map { point in
            CGPoint(x: point.x * rect.width, y: point.y * rect.height)
        }
        let brushDiameter = max(1, stroke.brushDiameter * min(rect.width, rect.height))
        guard let firstPoint = points.first else {
            return Path()
        }

        if points.count == 1 {
            return Path(ellipseIn: CGRect(
                x: firstPoint.x - brushDiameter / 2,
                y: firstPoint.y - brushDiameter / 2,
                width: brushDiameter,
                height: brushDiameter
            ))
        }

        var centerPath = Path()
        centerPath.move(to: firstPoint)
        for point in points.dropFirst() {
            centerPath.addLine(to: point)
        }

        return centerPath.strokedPath(StrokeStyle(lineWidth: brushDiameter, lineCap: .round, lineJoin: .round))
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
        switch tool {
        case .rectangle:
            Image(systemName: "rectangle")
                .font(.system(size: 23, weight: .regular))
        case .ellipse:
            Image(systemName: "circle")
                .font(.system(size: 23, weight: .regular))
        case .arrow:
            Image(systemName: "arrow.up.right")
                .font(.system(size: 24, weight: .regular))
        case .pen:
            Image(systemName: "pencil")
                .font(.system(size: 23, weight: .regular))
        case .mosaic:
            PulseScreenshotMosaicToolbarIcon()
        case .text:
            Image(systemName: "textformat")
                .font(.system(size: 23, weight: .regular))
        }
    }
}

private struct PulseScreenshotMosaicToolbarIcon: View {
    var body: some View {
        ZStack {
            Rectangle()
                .stroke(lineWidth: 1.8)

            Grid(horizontalSpacing: 1.2, verticalSpacing: 1.2) {
                ForEach(0..<3, id: \.self) { row in
                    GridRow {
                        ForEach(0..<3, id: \.self) { column in
                            Rectangle()
                                .fill(.primary.opacity((row + column).isMultiple(of: 2) ? 0.82 : 0.28))
                        }
                    }
                }
            }
            .padding(3.5)
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
