import AppKit
import SwiftUI

struct ClipboardPanelView: View {
    @Environment(PulseStore.self) private var store
    @State private var revealedEntryIDs: Set<UUID> = []
    @State private var isSearchFooterVisible = false
    @State private var isClearConfirmationVisible = false
    @FocusState private var isSearchFocused: Bool

    private var clipboard: ClipboardHistoryStore {
        store.clipboardHistory
    }

    var body: some View {
        let strings = store.strings
        let entries = clipboard.filteredEntries

        VStack(alignment: .leading, spacing: PulseDesign.Spacing.xs) {
            if !clipboard.entries.isEmpty {
                ClipboardContentFilterControl(
                    selectedFilter: clipboard.selectedContentFilter,
                    strings: strings
                ) { filter in
                    clipboard.selectedContentFilter = filter
                }
            }

            if let accessIssue = clipboard.accessIssue {
                ClipboardAccessIssueBanner(issue: accessIssue, strings: strings)
            }

            content(entries: entries, strings: strings)
                .frame(maxHeight: .infinity, alignment: .top)

            footer(entries: entries, strings: strings)
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
        .onAppear {
            clipboard.startMonitoring()
        }
        .onChange(of: isSearchFocused) { _, isFocused in
            guard !isFocused, clipboard.searchText.isEmpty else {
                return
            }

            withAnimation(.easeInOut(duration: 0.16)) {
                isSearchFooterVisible = false
            }
        }
        .onChange(of: clipboard.entries.count) { _, count in
            guard count == 0 else {
                return
            }

            isClearConfirmationVisible = false
        }
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
                strings.text(.clipboardSearchPlaceholder),
                text: Binding(
                    get: { clipboard.searchText },
                    set: { clipboard.searchText = $0 }
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
            .frame(height: PulseDesign.Control.buttonSide)
            .contentShape(RoundedRectangle(cornerRadius: PulseDesign.Radius.selectedControl, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(clipboard.entries.isEmpty)
        .help(strings.text(.clipboardSearchPlaceholder))
        .accessibilityLabel(strings.text(.clipboardSearchAction))
    }

    private func searchFooter(strings: PulseStrings) -> some View {
        HStack(spacing: PulseDesign.Spacing.xs) {
            searchField(strings: strings)
                .frame(maxWidth: .infinity)

            ClipboardIconButton(systemName: "xmark", help: strings.text(.closeClipboardSearch)) {
                closeSearchFooter()
            }
        }
    }

    private func showSearchFooter() {
        withAnimation(.easeInOut(duration: 0.16)) {
            isClearConfirmationVisible = false
            isSearchFooterVisible = true
        }

        DispatchQueue.main.async {
            isSearchFocused = true
        }
    }

    private func closeSearchFooter() {
        clipboard.searchText = ""
        isSearchFocused = false

        withAnimation(.easeInOut(duration: 0.16)) {
            isSearchFooterVisible = false
        }
    }

    @ViewBuilder
    private func content(entries: [ClipboardHistoryEntry], strings: PulseStrings) -> some View {
        if entries.isEmpty {
            ClipboardEmptyState(
                title: strings.text(.clipboardEmptyTitle),
                detail: strings.text(.clipboardEmptyDetail)
            )
        } else {
            ScrollView {
                LazyVStack(spacing: PulseDesign.Spacing.xs) {
                    ForEach(entries) { entry in
                        ClipboardEntryRow(
                            entry: entry,
                            strings: strings,
                            isRevealed: revealedEntryIDs.contains(entry.id),
                            isCopied: clipboard.lastCopiedEntryID == entry.id,
                            markerLabels: clipboard.markerLabels(for: entry, strings: strings),
                            copyAction: {
                                clipboard.copy(entry)
                            },
                            pasteAction: {
                                clipboard.pasteIntoFocusedTarget(entry)
                            },
                            revealAction: {
                                toggleReveal(for: entry)
                            },
                            deleteAction: {
                                clipboard.delete(entry)
                                revealedEntryIDs.remove(entry.id)
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
    private func footer(entries: [ClipboardHistoryEntry], strings: PulseStrings) -> some View {
        Group {
            if isClearConfirmationVisible {
                clearConfirmationFooter(strings: strings)
                    .transition(.opacity)
            } else if isSearchFooterVisible || !clipboard.searchText.isEmpty {
                searchFooter(strings: strings)
                    .transition(.opacity)
            } else {
                defaultFooter(strings: strings)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.16), value: isClearConfirmationVisible)
        .animation(.easeInOut(duration: 0.16), value: isSearchFooterVisible)
        .frame(height: PulsePanelLayout.footerHeight, alignment: .center)
    }

    private func defaultFooter(strings: PulseStrings) -> some View {
        HStack(spacing: PulseDesign.Spacing.xs) {
            searchFooterControl(strings: strings)

            Spacer(minLength: 0)

            Text(strings.clipboardEntryCount(clipboard.entries.count))
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.white.opacity(0.46))
                .lineLimit(1)

            ClipboardClearHistoryButton(
                title: strings.text(.clearClipboard),
                isDisabled: clipboard.entries.isEmpty
            ) {
                showClearConfirmation()
            }
        }
    }

    private func clearConfirmationFooter(strings: PulseStrings) -> some View {
        HStack(spacing: PulseDesign.Spacing.sm) {
            Spacer(minLength: 0)

            Text(strings.text(.clearClipboardConfirmation))
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            HStack(spacing: PulseDesign.Spacing.xs) {
                ClipboardFooterActionButton(title: strings.text(.cancelClearClipboard)) {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        isClearConfirmationVisible = false
                    }
                }

                ClipboardFooterActionButton(
                    title: strings.text(.confirmClearClipboard),
                    role: .destructive
                ) {
                    confirmClearHistory()
                }
            }
        }
    }

    private func showClearConfirmation() {
        isSearchFocused = false

        withAnimation(.easeInOut(duration: 0.16)) {
            isSearchFooterVisible = false
            isClearConfirmationVisible = true
        }
    }

    private func confirmClearHistory() {
        clipboard.clearHistory()
        revealedEntryIDs.removeAll()
        isSearchFocused = false

        withAnimation(.easeInOut(duration: 0.16)) {
            isSearchFooterVisible = false
            isClearConfirmationVisible = false
        }
    }

    private func toggleReveal(for entry: ClipboardHistoryEntry) {
        if revealedEntryIDs.contains(entry.id) {
            revealedEntryIDs.remove(entry.id)
        } else {
            revealedEntryIDs.insert(entry.id)
        }
    }
}

private struct ClipboardContentFilterControl: View {
    var selectedFilter: ClipboardContentFilter
    var strings: PulseStrings
    var selectFilter: (ClipboardContentFilter) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(ClipboardContentFilter.allCases, id: \.self) { filter in
                ClipboardContentFilterButton(
                    title: strings.clipboardContentFilter(filter),
                    iconName: filter.iconAssetName,
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

private struct ClipboardContentFilterButton: View {
    var title: String
    var iconName: String?
    var isSelected: Bool
    var action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            label
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

    @ViewBuilder
    private var label: some View {
        if let iconName {
            HStack(spacing: PulseDesign.Spacing.fine) {
                Image(iconName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                    .accessibilityHidden(true)

                Text(title)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
        } else {
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.86)
        }
    }
}

private extension ClipboardContentFilter {
    var iconAssetName: String? {
        switch self {
        case .all:
            "ClipboardAllFilterIcon"
        case .text:
            "ClipboardTextFilterIcon"
        case .image:
            "ClipboardImageFilterIcon"
        case .url:
            "ClipboardLinkFilterIcon"
        case .file:
            "ClipboardFileFilterIcon"
        }
    }
}

private struct ClipboardClearHistoryButton: View {
    var title: String
    var isDisabled: Bool
    var action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image("ClipboardClearIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .accessibilityHidden(true)
                .foregroundStyle(.white.opacity(isDisabled ? 0.24 : 0.54))
                .frame(width: PulseDesign.Control.buttonSide, height: PulseDesign.Control.buttonSide)
                .background {
                    RoundedRectangle(cornerRadius: PulseDesign.Radius.selectedControl, style: .continuous)
                        .fill(.white.opacity(isHovering && !isDisabled ? PulseDesign.Opacity.hoverFillOnDark : 0))
                }
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

private struct ClipboardFooterActionButton: View {
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

private struct ClipboardAccessIssueBanner: View {
    var issue: ClipboardHistoryAccessIssue
    var strings: PulseStrings

    var body: some View {
        HStack(alignment: .top, spacing: PulseDesign.Spacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.orange.opacity(0.94))
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))

                Text(detail)
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundStyle(.white.opacity(0.56))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            ClipboardIconButton(systemName: "gearshape", help: strings.text(.openSystemSettings)) {
                openPrivacySettings()
            }
        }
        .padding(.horizontal, PulseDesign.Spacing.xs)
        .padding(.vertical, PulseDesign.Spacing.xs)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: PulseDesign.Radius.card, style: .continuous))
    }

    private var title: String {
        switch issue {
        case .pasteCommandDenied:
            strings.text(.clipboardPastePermissionTitle)
        case .readDenied, .readFailed:
            strings.text(.clipboardPermissionTitle)
        }
    }

    private var detail: String {
        switch issue {
        case .readDenied:
            strings.text(.clipboardPermissionDetail)
        case .readFailed(let message):
            message
        case .pasteCommandDenied:
            strings.text(.clipboardPastePermissionDetail)
        }
    }

    private var privacySettingsURL: URL? {
        switch issue {
        case .pasteCommandDenied:
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        case .readDenied, .readFailed:
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Pasteboard")
        }
    }

    private func openPrivacySettings() {
        guard let url = privacySettingsURL else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}

private struct ClipboardEmptyState: View {
    var title: String
    var detail: String

    var body: some View {
        VStack(spacing: PulseDesign.Spacing.xs) {
            Image("IslandClipboardIcon")
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

private struct ClipboardEntryRow: View {
    var entry: ClipboardHistoryEntry
    var strings: PulseStrings
    var isRevealed: Bool
    var isCopied: Bool
    var markerLabels: [String]
    var copyAction: () -> Void
    var pasteAction: () -> Void
    var revealAction: () -> Void
    var deleteAction: () -> Void

    @State private var isHovering = false

    private var isMasked: Bool {
        entry.shouldMaskByDefault && !isRevealed
    }

    private var firstImageBlobID: String? {
        entry.items.compactMap(\.imageBlobID).first
    }

    private var shouldShowDisplayText: Bool {
        guard firstImageBlobID != nil else {
            return true
        }

        return entry.kind != .image && entry.displayText != "Image"
    }

    private var kindTag: (title: String, iconAssetName: String)? {
        guard
            let contentFilter = entry.kind.contentFilter,
            let iconAssetName = contentFilter.iconAssetName
        else {
            return nil
        }

        return (strings.clipboardKind(entry.kind), iconAssetName)
    }

    private var hasVisibleTags: Bool {
        kindTag != nil || !markerLabels.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PulseDesign.Spacing.xs) {
            header

            entryContent
                .padding(.leading, ClipboardRowLayout.contentLeadingInset)

            if hasVisibleTags {
                tagStrip
            }
        }
        .padding(.horizontal, PulseDesign.Spacing.xs)
        .padding(.vertical, PulseDesign.Spacing.xs)
        .background {
            RoundedRectangle(cornerRadius: PulseDesign.Radius.card, style: .continuous)
                .fill(.white.opacity(isHovering ? 0.11 : 0.07))
        }
        .contentShape(RoundedRectangle(cornerRadius: PulseDesign.Radius.card, style: .continuous))
        .gesture(
            TapGesture(count: 2)
                .onEnded { pasteAction() }
                .exclusively(before: TapGesture(count: 1).onEnded { copyAction() })
        )
        .contextMenu {
            Button {
                copyAction()
            } label: {
                Label(strings.text(.copyClipboardItem), systemImage: "doc.on.doc")
            }

            if entry.shouldMaskByDefault {
                Button {
                    revealAction()
                } label: {
                    Label(
                        isRevealed ? strings.text(.hideClipboardItem) : strings.text(.revealClipboardItem),
                        systemImage: isRevealed ? "eye.slash" : "eye"
                    )
                }
            }

            Divider()

            Button(role: .destructive) {
                deleteAction()
            } label: {
                Label(strings.text(.deleteClipboardItem), systemImage: "trash")
            }
        }
        .accessibilityAction(named: Text(strings.text(.copyClipboardItem)), copyAction)
        .accessibilityAction(named: Text(strings.text(.pasteClipboardItem)), pasteAction)
        .accessibilityAction(named: Text(strings.text(.deleteClipboardItem)), deleteAction)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private var entryContent: some View {
        VStack(alignment: .leading, spacing: PulseDesign.Spacing.xs) {
            if isMasked {
                maskedContent
            } else {
                visibleContent
            }
        }
    }

    private var header: some View {
        HStack(spacing: ClipboardRowLayout.iconTextSpacing) {
            ClipboardSourceIcon(source: entry.primarySource)

            Text(entry.primarySource?.displayName ?? strings.text(.clipboardUnknownSource))
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.white.opacity(0.44))
                .lineLimit(1)
                .truncationMode(.tail)

            if isCopied {
                copiedIndicator
            }

            Spacer(minLength: PulseDesign.Spacing.xs)

            Text(entry.createdAt, style: .time)
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .foregroundStyle(.white.opacity(0.44))
                .lineLimit(1)
        }
    }

    private var copiedIndicator: some View {
        Text(strings.text(.copied))
            .font(.system(.caption2, design: .rounded, weight: .semibold))
            .foregroundStyle(.green.opacity(0.88))
            .lineLimit(1)
            .layoutPriority(1)
    }

    private var tagStrip: some View {
        HStack(spacing: PulseDesign.Spacing.xxs) {
            Spacer(minLength: ClipboardRowLayout.contentLeadingInset)

            if let kindTag {
                ClipboardEntryTag(
                    title: kindTag.title,
                    iconAssetName: kindTag.iconAssetName
                )
            }

            ForEach(markerLabels, id: \.self) { label in
                ClipboardEntryTag(
                    title: label,
                    systemImageName: "macbook.and.iphone"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var maskedContent: some View {
        HStack(spacing: PulseDesign.Spacing.xs) {
            Image(systemName: "lock.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.42))

            Text(strings.text(.clipboardMaskedValue))
                .font(.system(.callout, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
        }
        .padding(.vertical, PulseDesign.Spacing.xxs)
    }

    @ViewBuilder
    private var visibleContent: some View {
        if let imageBlobID = firstImageBlobID {
            ClipboardImagePreview(blobID: imageBlobID)
        }

        if shouldShowDisplayText {
            Text(entry.displayText)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.86))
                .lineLimit(entry.kind == .text ? 3 : 2)
                .truncationMode(entry.kind == .file ? .middle : .tail)
        }
    }

}

private struct ClipboardEntryTag: View {
    var title: String
    var iconAssetName: String?
    var systemImageName: String?

    var body: some View {
        HStack(spacing: PulseDesign.Spacing.xxs) {
            if let iconAssetName {
                Image(iconAssetName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                    .accessibilityHidden(true)
            } else if let systemImageName {
                Image(systemName: systemImageName)
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 14, height: 14)
                    .accessibilityHidden(true)
            }

            Text(title)
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(.white.opacity(0.56))
        .padding(.horizontal, PulseDesign.Spacing.fine)
        .padding(.vertical, 3)
        .background(.white.opacity(0.08), in: Capsule())
        .accessibilityLabel(title)
    }
}

private extension ClipboardContentKind {
    var contentFilter: ClipboardContentFilter? {
        switch self {
        case .text:
            .text
        case .image:
            .image
        case .url:
            .url
        case .file:
            .file
        case .mixed, .data:
            nil
        }
    }
}

private enum ClipboardRowLayout {
    static let sourceIconSide: CGFloat = 22
    static let iconTextSpacing = PulseDesign.Spacing.xs

    static var contentLeadingInset: CGFloat {
        sourceIconSide + iconTextSpacing
    }
}

private struct ClipboardImagePreview: View {
    @Environment(PulseStore.self) private var store
    var blobID: String

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 150)
                    .clipShape(RoundedRectangle(cornerRadius: PulseDesign.Radius.card, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: PulseDesign.Radius.card, style: .continuous)
                    .fill(.white.opacity(0.08))
                    .frame(height: 90)
                    .overlay {
                        ProgressView()
                            .controlSize(.small)
                    }
            }
        }
        .task(id: blobID) {
            if let data = store.clipboardHistory.imageData(for: blobID) {
                image = NSImage(data: data)
            }
        }
    }
}

private struct ClipboardSourceIcon: View {
    var source: ClipboardApplicationSource?

    var body: some View {
        Group {
            if
                let bundlePath = source?.bundlePath,
                let icon = ClipboardSourceIconCache.shared.icon(forBundlePath: bundlePath)
            {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            } else {
                Image(systemName: "app.dashed")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.48))
            }
        }
        .frame(width: ClipboardRowLayout.sourceIconSide, height: ClipboardRowLayout.sourceIconSide)
        .accessibilityHidden(true)
    }
}

private final class ClipboardSourceIconCache {
    static let shared = ClipboardSourceIconCache()

    private let cache = NSCache<NSString, NSImage>()

    func icon(forBundlePath path: String) -> NSImage? {
        let key = path as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        guard FileManager.default.fileExists(atPath: path) else {
            return nil
        }

        let icon = NSWorkspace.shared.icon(forFile: path)
        icon.size = NSSize(width: 32, height: 32)
        cache.setObject(icon, forKey: key)
        return icon
    }
}

private struct ClipboardIconButton: View {
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

#Preview {
    ClipboardPanelView()
        .environment(PulseStore())
}
