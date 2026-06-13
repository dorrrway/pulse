import AppKit
import AppKit
import SwiftUI

private enum MemoPanelMetrics {
    static let emptyStateHeight: CGFloat = 170
    static let composerMinHeight: CGFloat = 82
    static let composerMaxHeight: CGFloat = 132
}

struct MemoPanelView: View {
    @Environment(PulseStore.self) private var store
    @FocusState private var isComposerFocused: Bool
    @FocusState private var isSearchFocused: Bool
    @State private var editingEntryID: UUID?
    @State private var editingText = ""
    @State private var isSearchFooterVisible = false
    @State private var isClearCompletedConfirmationVisible = false

    private var memos: MemoStore {
        store.memos
    }

    var body: some View {
        let strings = store.strings
        let entries = memos.filteredEntries

        VStack(alignment: .leading, spacing: PulseDesign.Spacing.xs) {
            if !memos.entries.isEmpty {
                MemoFilterControl(
                    selectedFilter: memos.selectedFilter,
                    strings: strings
                ) { filter in
                    memos.selectedFilter = filter
                    isClearCompletedConfirmationVisible = false
                }
            }

            if let persistenceIssue = memos.persistenceIssue {
                MemoPersistenceIssueBanner(message: persistenceIssue, strings: strings)
            }

            content(entries: entries, strings: strings)
                .frame(maxHeight: .infinity, alignment: .top)
                .layoutPriority(1)

            MemoComposer(
                text: Binding(
                    get: { memos.draftText },
                    set: { memos.draftText = $0 }
                ),
                strings: strings,
                addNoteAction: {
                    memos.addNote()
                }
            )
            .focused($isComposerFocused)

            footer(strings: strings)
                .padding(.top, PulseDesign.Spacing.xxs)
        }
        .padding(.horizontal, PulsePanelLayout.outerPadding)
        .padding(.top, PulsePanelLayout.outerPadding)
        .padding(.bottom, PulsePanelLayout.footerBottomPadding)
        .frame(
            width: PulseIslandLayout.attachedPanelSize.width,
            height: PulseIslandLayout.attachedPanelSize.height,
            alignment: .top
        )
        .onChange(of: memos.entries.count) { _, count in
            guard count == 0 else {
                return
            }

            editingEntryID = nil
            editingText = ""
            isClearCompletedConfirmationVisible = false
            isSearchFooterVisible = false
            isSearchFocused = false
        }
        .onChange(of: isSearchFocused) { _, isFocused in
            guard !isFocused, memos.searchText.isEmpty else {
                return
            }

            withAnimation(.easeInOut(duration: 0.16)) {
                isSearchFooterVisible = false
            }
        }
    }

    @ViewBuilder
    private func content(entries: [MemoEntry], strings: PulseStrings) -> some View {
        if memos.entries.isEmpty {
            MemoEmptyState(
                title: strings.text(.memoEmptyTitle),
                detail: strings.text(.memoEmptyDetail)
            )
            .frame(height: MemoPanelMetrics.emptyStateHeight)
        } else if entries.isEmpty {
            MemoEmptyState(
                title: strings.text(.memoNoResultsTitle),
                detail: strings.text(.memoNoResultsDetail)
            )
            .frame(height: MemoPanelMetrics.emptyStateHeight)
        } else {
            ScrollView {
                LazyVStack(spacing: PulseDesign.Spacing.xs) {
                    memoEntryRows(entries: entries, strings: strings)
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    @ViewBuilder
    private func memoEntryRows(entries: [MemoEntry], strings: PulseStrings) -> some View {
        ForEach(entries) { entry in
            MemoEntryRow(
                entry: entry,
                strings: strings,
                isEditing: editingEntryID == entry.id,
                editingText: Binding(
                    get: { editingText },
                    set: { editingText = $0 }
                ),
                toggleCompletionAction: {
                    memos.toggleCompletion(entry)
                },
                markAsTaskAction: {
                    memos.markAsTask(entry)
                },
                togglePinAction: {
                    memos.togglePin(entry)
                },
                startEditingAction: {
                    startEditing(entry)
                },
                saveEditingAction: {
                    saveEditing(entry)
                },
                cancelEditingAction: {
                    cancelEditing()
                },
                copyAction: {
                    copy(entry)
                },
                deleteAction: {
                    delete(entry)
                }
            )
        }
    }

    @ViewBuilder
    private func footer(strings: PulseStrings) -> some View {
        Group {
            if isClearCompletedConfirmationVisible {
                clearCompletedConfirmationFooter(strings: strings)
                    .transition(.opacity)
            } else if isSearchFooterVisible || !memos.searchText.isEmpty {
                searchFooter(strings: strings)
                    .transition(.opacity)
            } else {
                defaultFooter(strings: strings)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.16), value: isClearCompletedConfirmationVisible)
        .animation(.easeInOut(duration: 0.16), value: isSearchFooterVisible)
        .frame(maxWidth: .infinity)
        .frame(height: PulsePanelLayout.footerHeight, alignment: .center)
    }

    private func searchField(strings: PulseStrings) -> some View {
        HStack(spacing: PulseDesign.Spacing.xs) {
            Image("ClipboardSearchIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .foregroundStyle(.white.opacity(0.42))

            TextField(
                strings.text(.memoSearchPlaceholder),
                text: Binding(
                    get: { memos.searchText },
                    set: { memos.searchText = $0 }
                )
            )
            .textFieldStyle(.plain)
            .font(.system(.callout, design: .rounded, weight: .medium))
            .foregroundStyle(.white.opacity(0.92))
            .focused($isSearchFocused)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, PulseDesign.Spacing.sm)
        .frame(maxWidth: .infinity)
        .frame(height: 34)
        .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: PulseDesign.Radius.card, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: PulseDesign.Radius.card, style: .continuous))
        .onTapGesture {
            isSearchFocused = true
        }
    }

    private func searchFooterControl(strings: PulseStrings) -> some View {
        Button {
            showSearchFooter()
        } label: {
            HStack(spacing: PulseDesign.Spacing.fine) {
                Image("ClipboardSearchIcon")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                    .accessibilityHidden(true)

                Text(strings.text(.clipboardSearchAction))
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(.white.opacity(0.54))
            .padding(.horizontal, PulseDesign.Spacing.fine)
            .frame(minWidth: PulseDesign.Control.buttonSide, alignment: .leading)
            .frame(height: PulseDesign.Control.buttonSide)
            .contentShape(RoundedRectangle(cornerRadius: PulseDesign.Radius.selectedControl, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(memos.entries.isEmpty)
        .help(strings.text(.clipboardSearchAction))
        .accessibilityLabel(strings.text(.clipboardSearchAction))
    }

    private func searchFooter(strings: PulseStrings) -> some View {
        HStack(spacing: PulseDesign.Spacing.xs) {
            searchField(strings: strings)
                .frame(maxWidth: .infinity)

            MemoIconButton(systemName: "xmark", help: strings.text(.closeMemoSearch)) {
                closeSearchFooter()
            }
        }
    }

    private func showSearchFooter() {
        isComposerFocused = false

        withAnimation(.easeInOut(duration: 0.16)) {
            isClearCompletedConfirmationVisible = false
            isSearchFooterVisible = true
        }

        DispatchQueue.main.async {
            isSearchFocused = true
        }
    }

    private func closeSearchFooter() {
        memos.searchText = ""
        isSearchFocused = false

        withAnimation(.easeInOut(duration: 0.16)) {
            isSearchFooterVisible = false
        }
    }

    private func defaultFooter(strings: PulseStrings) -> some View {
        HStack(spacing: PulseDesign.Spacing.xs) {
            searchFooterControl(strings: strings)

            Spacer(minLength: 0)

            Text(memoSummaryText(strings))
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.white.opacity(0.46))
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            MemoClearHistoryButton(
                title: strings.text(.clearCompletedMemos),
                isDisabled: memos.completedTaskCount == 0
            ) {
                showClearCompletedConfirmation()
            }
        }
    }

    private func showClearCompletedConfirmation() {
        isSearchFocused = false
        isComposerFocused = false
        withAnimation(.easeInOut(duration: 0.16)) {
            isSearchFooterVisible = false
            isClearCompletedConfirmationVisible = true
        }
    }

    private func memoSummaryText(_ strings: PulseStrings) -> String {
        let memoCount = memos.entries.filter { $0.kind == .note }.count
        let todoCount = memos.activeTaskCount
        let completedCount = memos.completedTaskCount

        return "\(strings.memoFilterTitle(.notes)) \(memoCount) · \(strings.memoFilterTitle(.todo)) \(todoCount) · \(strings.memoFilterTitle(.completed)) \(completedCount)"
    }

    private func clearCompletedConfirmationFooter(strings: PulseStrings) -> some View {
        HStack(spacing: PulseDesign.Spacing.sm) {
            Spacer(minLength: 0)

            Text(strings.text(.clearCompletedMemosConfirmation))
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            HStack(spacing: PulseDesign.Spacing.xs) {
                MemoFooterActionButton(title: strings.text(.cancelClearCompletedMemos)) {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        isClearCompletedConfirmationVisible = false
                    }
                }

                MemoFooterActionButton(
                    title: strings.text(.confirmClearCompletedMemos),
                    role: .destructive
                ) {
                    memos.clearCompletedTasks()
                    withAnimation(.easeInOut(duration: 0.16)) {
                        isClearCompletedConfirmationVisible = false
                    }
                }
            }
        }
    }

    private func startEditing(_ entry: MemoEntry) {
        editingEntryID = entry.id
        editingText = entry.text
    }

    private func saveEditing(_ entry: MemoEntry) {
        guard memos.update(entry, text: editingText) else {
            return
        }

        cancelEditing()
    }

    private func cancelEditing() {
        editingEntryID = nil
        editingText = ""
    }

    private func copy(_ entry: MemoEntry) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.text, forType: .string)
    }

    private func delete(_ entry: MemoEntry) {
        if editingEntryID == entry.id {
            cancelEditing()
        }

        memos.delete(entry)
    }
}

private struct MemoComposer: View {
    @Binding var text: String
    var strings: PulseStrings
    var addNoteAction: () -> Void
    @State private var isSendButtonHovered = false
    @State private var composerTextHeight = MemoPanelMetrics.composerMinHeight

    var body: some View {
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        ZStack(alignment: .bottomTrailing) {
            ZStack(alignment: .topLeading) {
                MemoComposerTextView(
                    text: $text,
                    submitAction: addNoteAction,
                    heightChangeAction: { composerTextHeight = $0 }
                )

                if text.isEmpty {
                    Text(strings.text(.memoDraftPlaceholder))
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundStyle(.white.opacity(0.58))
                        .allowsHitTesting(false)
                }
            }
                .padding(.leading, PulseDesign.Spacing.sm)
                .padding(.trailing, PulseDesign.Control.buttonSide + PulseDesign.Spacing.md)
                .padding(.vertical, PulseDesign.Spacing.sm)
                .frame(maxWidth: .infinity)
                .frame(
                    height: min(
                        max(composerTextHeight + PulseDesign.Spacing.sm * 2, MemoPanelMetrics.composerMinHeight),
                        MemoPanelMetrics.composerMaxHeight
                    ),
                    alignment: .topLeading
                )
                .fixedSize(horizontal: false, vertical: true)
                .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: PulseDesign.Radius.card, style: .continuous))

            Button {
                addNoteAction()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(hasText ? .white.opacity(0.94) : .white.opacity(0.24))
                    .frame(width: PulseDesign.Control.buttonSide, height: PulseDesign.Control.buttonSide)
                    .background {
                        RoundedRectangle(cornerRadius: PulseDesign.Radius.selectedControl, style: .continuous)
                            .fill(hasText ? (isSendButtonHovered ? .white.opacity(0.21) : .white.opacity(0.16)) : .white.opacity(0.11))
                    }
            }
            .buttonStyle(.plain)
            .disabled(!hasText)
            .onHover { isSendButtonHovered = $0 }
            .padding(.trailing, PulseDesign.Spacing.sm)
            .padding(.bottom, PulseDesign.Spacing.sm)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct MemoComposerTextView: NSViewRepresentable {
    @Binding var text: String
    var submitAction: () -> Void
    var heightChangeAction: (CGFloat) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, submitAction: submitAction, heightChangeAction: heightChangeAction)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = MemoComposerScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay

        let textView = MemoComposerNSTextView()
        textView.delegate = context.coordinator
        textView.submitAction = submitAction
        textView.string = text
        textView.drawsBackground = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        textView.textColor = NSColor.white.withAlphaComponent(0.92)
        textView.insertionPointColor = .controlAccentColor
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.updateMeasuredHeight(for: textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.submitAction = submitAction
        context.coordinator.heightChangeAction = heightChangeAction

        guard let textView = scrollView.documentView as? MemoComposerNSTextView else {
            return
        }

        textView.submitAction = submitAction
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)
        if textView.string != text {
            textView.string = text
        }
        context.coordinator.updateMeasuredHeight(for: textView)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        var submitAction: () -> Void
        var heightChangeAction: (CGFloat) -> Void
        weak var textView: NSTextView?

        init(
            text: Binding<String>,
            submitAction: @escaping () -> Void,
            heightChangeAction: @escaping (CGFloat) -> Void
        ) {
            _text = text
            self.submitAction = submitAction
            self.heightChangeAction = heightChangeAction
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }

            text = textView.string
            updateMeasuredHeight(for: textView)
        }

        func updateMeasuredHeight(for textView: NSTextView) {
            guard let layoutManager = textView.layoutManager, let textContainer = textView.textContainer else {
                return
            }

            layoutManager.ensureLayout(for: textContainer)
            let usedHeight = ceil(layoutManager.usedRect(for: textContainer).height)
            let lineHeight = ceil(textView.font.map { $0.ascender - $0.descender + $0.leading } ?? NSFont.systemFontSize)
            let measuredHeight = max(usedHeight, lineHeight)

            Task { @MainActor [heightChangeAction] in
                heightChangeAction(measuredHeight)
            }
        }
    }
}

private final class MemoComposerNSTextView: NSTextView {
    var submitAction: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        guard event.keyCode == 36 || event.keyCode == 76 else {
            super.keyDown(with: event)
            return
        }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers.contains(.shift) {
            insertText("\n", replacementRange: selectedRange())
            return
        }

        guard modifiers.isDisjoint(with: [.command, .control, .option]) else {
            super.keyDown(with: event)
            return
        }

        submitAction?()
    }
}

private final class MemoComposerScrollView: NSScrollView {
    override func scrollWheel(with event: NSEvent) {
        let verticalDelta = event.scrollingDeltaY

        guard abs(verticalDelta) >= abs(event.scrollingDeltaX) else {
            return
        }

        guard let documentView else {
            return
        }

        let visibleHeight = contentView.bounds.height
        let documentHeight = documentView.bounds.height
        let maxY = max(0, documentHeight - visibleHeight)
        let proposedY = contentView.bounds.origin.y - verticalDelta
        let clampedY = min(max(proposedY, 0), maxY)
        let targetOrigin = CGPoint(x: contentView.bounds.origin.x, y: clampedY)

        contentView.scroll(to: targetOrigin)
        reflectScrolledClipView(contentView)
    }
}

private struct MemoFilterControl: View {
    var selectedFilter: MemoEntryFilter
    var strings: PulseStrings
    var selectFilter: (MemoEntryFilter) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(MemoEntryFilter.allCases, id: \.self) { filter in
                MemoFilterButton(
                    title: strings.memoFilterTitle(filter),
                    systemImageName: filter.systemImageName,
                    isSelected: selectedFilter == filter
                ) {
                    selectFilter(filter)
                }
            }
        }
        .padding(PulseDesign.Spacing.micro)
        .background {
            RoundedRectangle(cornerRadius: PulseDesign.Radius.segmentedControl, style: .continuous)
                .fill(.white.opacity(PulseDesign.Opacity.hoverFillOnDark))
        }
        .accessibilityElement(children: .contain)
    }
}

private struct MemoFilterButton: View {
    var title: String
    var systemImageName: String
    var isSelected: Bool
    var action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: PulseDesign.Spacing.fine) {
                Image(systemName: systemImageName)
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 14, height: 14)
                    .accessibilityHidden(true)

                Text(title)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(.white.opacity(isSelected ? 0.94 : 0.58))
            .frame(maxWidth: .infinity, minHeight: 26)
            .background {
                if isSelected || isHovering {
                    RoundedRectangle(cornerRadius: PulseDesign.Radius.selectedControl, style: .continuous)
                        .fill(.white.opacity(isSelected ? PulseDesign.Opacity.selectedFillOnDark : PulseDesign.Opacity.hoverFillOnDark))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: PulseDesign.Radius.selectedControl, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .onHover { hovering in
            isHovering = hovering
        }
        .frame(maxWidth: .infinity)
    }
}

private extension MemoEntryFilter {
    var systemImageName: String {
        switch self {
        case .all:
            "tray.full"
        case .todo:
            "circle"
        case .notes:
            "note.text"
        case .completed:
            "checkmark.circle"
        }
    }
}

private struct MemoEntryRow: View {
    var entry: MemoEntry
    var strings: PulseStrings
    var isEditing: Bool
    @Binding var editingText: String
    var toggleCompletionAction: () -> Void
    var markAsTaskAction: () -> Void
    var togglePinAction: () -> Void
    var startEditingAction: () -> Void
    var saveEditingAction: () -> Void
    var cancelEditingAction: () -> Void
    var copyAction: () -> Void
    var deleteAction: () -> Void

    @State private var isHovering = false
    @State private var editingTextHeight: CGFloat = 54

    var body: some View {
        HStack(alignment: .top, spacing: PulseDesign.Spacing.xs) {
            completionControl

            VStack(alignment: .leading, spacing: PulseDesign.Spacing.xs) {
                header

                if isEditing {
                    editingField
                } else {
                    Text(entry.text)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white.opacity(entry.isCompleted ? 0.50 : 0.86))
                        .strikethrough(entry.isCompleted, color: .white.opacity(0.42))
                        .lineLimit(3)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, PulseDesign.Spacing.xs)
        .padding(.vertical, PulseDesign.Spacing.xs)
        .background {
            RoundedRectangle(cornerRadius: PulseDesign.Radius.card, style: .continuous)
                .fill(.white.opacity(isHovering ? 0.11 : 0.07))
        }
        .contentShape(RoundedRectangle(cornerRadius: PulseDesign.Radius.card, style: .continuous))
        .contextMenu {
            Button {
                copyAction()
            } label: {
                Label(strings.text(.copyMemo), systemImage: "doc.on.doc")
            }

            Button {
                startEditingAction()
            } label: {
                Label(strings.text(.editMemo), systemImage: "pencil")
            }

            if entry.kind == .note {
                Button {
                    markAsTaskAction()
                } label: {
                    Label(strings.text(.setMemoAsTodo), systemImage: "checklist")
                }
            }

            Button {
                togglePinAction()
            } label: {
                Label(
                    entry.isPinned ? strings.text(.unpinMemo) : strings.text(.pinMemo),
                    systemImage: entry.isPinned ? "pin.slash" : "pin"
                )
            }

            Divider()

            Button(role: .destructive) {
                deleteAction()
            } label: {
                Label(strings.text(.deleteMemo), systemImage: "trash")
            }
        }
        .accessibilityAction(named: Text(strings.text(.copyMemo)), copyAction)
        .accessibilityAction(named: Text(strings.text(.editMemo)), startEditingAction)
        .accessibilityAction(named: Text(strings.text(.deleteMemo)), deleteAction)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    @ViewBuilder
    private var completionControl: some View {
        if entry.kind == .task {
            Button(action: toggleCompletionAction) {
                Image(systemName: entry.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(entry.isCompleted ? .green.opacity(0.86) : .white.opacity(0.42))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(entry.isCompleted ? strings.text(.markTodoOpen) : strings.text(.markTodoDone))
            .accessibilityLabel(entry.isCompleted ? strings.text(.markTodoOpen) : strings.text(.markTodoDone))
        } else {
            Image(systemName: "note.text")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.42))
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)
        }
    }

    private var header: some View {
        HStack(spacing: PulseDesign.Spacing.xxs) {
            if entry.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.orange.opacity(0.84))
                    .accessibilityHidden(true)
            }

            Text(strings.memoKindTitle(entry.kind))
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.44))
                .lineLimit(1)

            Text(entry.updatedAt, style: .time)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.white.opacity(0.36))
                .lineLimit(1)
        }
        .frame(height: 24, alignment: .center)
    }

    private var editingField: some View {
        HStack(alignment: .bottom, spacing: PulseDesign.Spacing.xs) {
            ZStack(alignment: .topLeading) {
                MemoComposerTextView(
                    text: $editingText,
                    submitAction: saveEditingAction,
                    heightChangeAction: { editingTextHeight = $0 }
                )

                if editingText.isEmpty {
                    Text(strings.text(.memoDraftPlaceholder))
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundStyle(.white.opacity(0.58))
                        .allowsHitTesting(false)
                }
            }
                .padding(.horizontal, PulseDesign.Spacing.xs)
                .padding(.vertical, PulseDesign.Spacing.fine)
                .frame(
                    height: min(max(editingTextHeight + PulseDesign.Spacing.fine * 2, 54), 132),
                    alignment: .topLeading
                )
                .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: PulseDesign.Radius.selectedControl, style: .continuous))

            MemoIconButton(
                systemName: "checkmark",
                help: strings.text(.saveMemo),
                isDisabled: editingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) {
                saveEditingAction()
            }

            MemoIconButton(systemName: "xmark", help: strings.text(.cancelMemoEdit)) {
                cancelEditingAction()
            }
        }
    }

}

private struct MemoPersistenceIssueBanner: View {
    var message: String
    var strings: PulseStrings

    var body: some View {
        HStack(alignment: .top, spacing: PulseDesign.Spacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.orange.opacity(0.94))
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(strings.text(.memoStorageIssueTitle))
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))

                Text(message)
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundStyle(.white.opacity(0.56))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, PulseDesign.Spacing.xs)
        .padding(.vertical, PulseDesign.Spacing.xs)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: PulseDesign.Radius.card, style: .continuous))
    }
}

private struct MemoEmptyState: View {
    var title: String
    var detail: String

    var body: some View {
        VStack(spacing: PulseDesign.Spacing.xs) {
            Image("ClipboardTextFilterIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 34, height: 34)
                .foregroundStyle(.white.opacity(0.34))

            Text(title)
                .font(.system(.callout, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.76))

            Text(detail)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.white.opacity(0.46))
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, PulseDesign.Spacing.lg)
    }
}

private struct MemoIconButton: View {
    var systemName: String
    var help: String
    var isDisabled = false
    var action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if isHovering && !isDisabled {
                    RoundedRectangle(cornerRadius: PulseDesign.Radius.selectedControl, style: .continuous)
                        .fill(.white.opacity(PulseDesign.Opacity.hoverFillOnDark))
                }

                Image(systemName: systemName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(isDisabled ? 0.22 : 0.62))
                    .frame(width: PulseDesign.Control.iconSide, height: PulseDesign.Control.iconSide)
                    .accessibilityHidden(true)
            }
            .frame(width: PulseDesign.Control.buttonSide, height: PulseDesign.Control.buttonSide)
            .contentShape(RoundedRectangle(cornerRadius: PulseDesign.Radius.selectedControl, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .help(help)
        .accessibilityLabel(help)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

private struct MemoClearHistoryButton: View {
    var title: String
    var isDisabled: Bool
    var action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: PulseDesign.Radius.selectedControl, style: .continuous)
                    .fill(.white.opacity(isHovering && !isDisabled ? PulseDesign.Opacity.hoverFillOnDark : 0))

                Image("ClipboardClearIcon")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                    .accessibilityHidden(true)
                    .foregroundStyle(.white.opacity(isDisabled ? 0.24 : 0.54))
            }
            .frame(width: PulseDesign.Control.buttonSide, height: PulseDesign.Control.buttonSide)
            .contentShape(RoundedRectangle(cornerRadius: PulseDesign.Radius.selectedControl, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .help(title)
        .accessibilityLabel(title)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

private struct MemoFooterActionButton: View {
    var title: String
    var role: ButtonRole?
    var action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(role: role, action: action) {
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(foregroundStyle)
                .lineLimit(1)
                .minimumScaleFactor(0.88)
                .padding(.horizontal, PulseDesign.Spacing.xs)
                .frame(height: PulseDesign.Control.buttonSide)
                .background {
                    RoundedRectangle(cornerRadius: PulseDesign.Radius.selectedControl, style: .continuous)
                        .fill(backgroundStyle)
                }
                .contentShape(RoundedRectangle(cornerRadius: PulseDesign.Radius.selectedControl, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private var foregroundStyle: Color {
        if role == .destructive {
            return .red.opacity(0.88)
        }

        return .white.opacity(0.64)
    }

    private var backgroundStyle: Color {
        if role == .destructive {
            return .red.opacity(isHovering ? 0.18 : 0.12)
        }

        return .white.opacity(isHovering ? PulseDesign.Opacity.hoverFillOnDark : 0.06)
    }
}

#Preview {
    MemoPanelView()
        .environment(PulseStore())
}
