import AppKit
import SwiftUI

struct MemoPanelView: View {
    @Environment(PulseStore.self) private var store
    @FocusState private var isComposerFocused: Bool
    @FocusState private var isSearchFocused: Bool
    @State private var editingEntryID: UUID?
    @State private var editingText = ""
    @State private var isClearCompletedConfirmationVisible = false

    private var memos: MemoStore {
        store.memos
    }

    var body: some View {
        let strings = store.strings
        let entries = memos.filteredEntries

        VStack(alignment: .leading, spacing: PulseDesign.Spacing.xs) {
            MemoComposer(
                text: Binding(
                    get: { memos.draftText },
                    set: { memos.draftText = $0 }
                ),
                strings: strings,
                addNoteAction: {
                    if memos.addNote() {
                        isComposerFocused = false
                    }
                },
                addTaskAction: {
                    if memos.addTask() {
                        isComposerFocused = false
                    }
                }
            )
            .focused($isComposerFocused)

            if !memos.entries.isEmpty {
                MemoFilterControl(
                    selectedFilter: memos.selectedFilter,
                    strings: strings
                ) { filter in
                    memos.selectedFilter = filter
                    isClearCompletedConfirmationVisible = false
                }

                MemoSearchField(
                    text: Binding(
                        get: { memos.searchText },
                        set: { memos.searchText = $0 }
                    ),
                    strings: strings
                )
                .focused($isSearchFocused)
            }

            if let persistenceIssue = memos.persistenceIssue {
                MemoPersistenceIssueBanner(message: persistenceIssue, strings: strings)
            }

            content(entries: entries, strings: strings)
                .frame(maxHeight: .infinity, alignment: .top)

            footer(strings: strings)
                .padding(.top, PulsePanelLayout.footerTopSpacing)
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
        }
    }

    @ViewBuilder
    private func content(entries: [MemoEntry], strings: PulseStrings) -> some View {
        if memos.entries.isEmpty {
            MemoEmptyState(
                title: strings.text(.memoEmptyTitle),
                detail: strings.text(.memoEmptyDetail)
            )
        } else if entries.isEmpty {
            MemoEmptyState(
                title: strings.text(.memoNoResultsTitle),
                detail: strings.text(.memoNoResultsDetail)
            )
        } else {
            ScrollView {
                LazyVStack(spacing: PulseDesign.Spacing.xs) {
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
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder
    private func footer(strings: PulseStrings) -> some View {
        Group {
            if isClearCompletedConfirmationVisible {
                clearCompletedConfirmationFooter(strings: strings)
                    .transition(.opacity)
            } else {
                defaultFooter(strings: strings)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.16), value: isClearCompletedConfirmationVisible)
        .frame(height: PulsePanelLayout.footerHeight, alignment: .center)
    }

    private func defaultFooter(strings: PulseStrings) -> some View {
        HStack(spacing: PulseDesign.Spacing.xs) {
            Text(strings.memoEntryCount(memos.entries.count))
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.white.opacity(0.46))
                .lineLimit(1)

            Spacer(minLength: 0)

            Text(strings.memoTaskSummary(active: memos.activeTaskCount, completed: memos.completedTaskCount))
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.white.opacity(0.46))
                .lineLimit(1)

            MemoIconButton(
                systemName: "checkmark.circle",
                help: strings.text(.clearCompletedMemos),
                isDisabled: memos.completedTaskCount == 0
            ) {
                isSearchFocused = false
                isComposerFocused = false
                withAnimation(.easeInOut(duration: 0.16)) {
                    isClearCompletedConfirmationVisible = true
                }
            }
        }
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
    var addTaskAction: () -> Void

    private var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: PulseDesign.Spacing.xs) {
            TextField(strings.text(.memoDraftPlaceholder), text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(.callout, design: .rounded, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1...3)
                .padding(.horizontal, PulseDesign.Spacing.sm)
                .padding(.vertical, PulseDesign.Spacing.xs)
                .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: PulseDesign.Radius.card, style: .continuous))

            MemoIconButton(systemName: "note.text", help: strings.text(.addMemo), isDisabled: isEmpty) {
                addNoteAction()
            }

            MemoIconButton(systemName: "checklist", help: strings.text(.addTodo), isDisabled: isEmpty) {
                addTaskAction()
            }
        }
    }
}

private struct MemoSearchField: View {
    @Binding var text: String
    var strings: PulseStrings

    var body: some View {
        HStack(spacing: PulseDesign.Spacing.xs) {
            Image("ClipboardSearchIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .foregroundStyle(.white.opacity(0.42))

            TextField(strings.text(.memoSearchPlaceholder), text: $text)
                .textFieldStyle(.plain)
                .font(.system(.callout, design: .rounded, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
                .frame(maxWidth: .infinity, alignment: .leading)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.36))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .help(strings.text(.closeMemoSearch))
                .accessibilityLabel(strings.text(.closeMemoSearch))
            }
        }
        .padding(.horizontal, PulseDesign.Spacing.sm)
        .frame(height: 34)
        .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: PulseDesign.Radius.card, style: .continuous))
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
    var togglePinAction: () -> Void
    var startEditingAction: () -> Void
    var saveEditingAction: () -> Void
    var cancelEditingAction: () -> Void
    var copyAction: () -> Void
    var deleteAction: () -> Void

    @State private var isHovering = false

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

            actionStrip
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
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.orange.opacity(0.84))
                    .accessibilityHidden(true)
            }

            Text(strings.memoKindTitle(entry.kind))
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.44))
                .lineLimit(1)

            Text(entry.updatedAt, style: .time)
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .foregroundStyle(.white.opacity(0.36))
                .lineLimit(1)
        }
    }

    private var editingField: some View {
        HStack(alignment: .bottom, spacing: PulseDesign.Spacing.xs) {
            TextField(strings.text(.memoDraftPlaceholder), text: $editingText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1...4)
                .padding(.horizontal, PulseDesign.Spacing.xs)
                .padding(.vertical, PulseDesign.Spacing.fine)
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

    @ViewBuilder
    private var actionStrip: some View {
        if isEditing {
            EmptyView()
        } else {
            HStack(spacing: PulseDesign.Spacing.micro) {
                MemoIconButton(
                    systemName: entry.isPinned ? "pin.fill" : "pin",
                    help: entry.isPinned ? strings.text(.unpinMemo) : strings.text(.pinMemo)
                ) {
                    togglePinAction()
                }

                MemoIconButton(systemName: "pencil", help: strings.text(.editMemo)) {
                    startEditingAction()
                }
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
