import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum InstalledAppsPanelLayout {
    static let favoritePanelHeight: CGFloat = 56
    static let favoriteIconSide: CGFloat = 42
    static let favoriteSlotSide: CGFloat = 52
    static let favoriteInsertionGapWidth: CGFloat = 14
    static let favoriteInsertionActiveGapWidth: CGFloat = 34
    static let runningIndicatorSide: CGFloat = 5
    static let runningIndicatorColor = Color(red: 0.28, green: 0.88, blue: 0.58)
    static let sectionGapHeight: CGFloat = 18
    static let separatorCutoutHeight: CGFloat = 4
    static let sectionGapCenterY = PulsePanelLayout.outerPadding
        + favoritePanelHeight
        + PulseDesign.Spacing.xs
        + sectionGapHeight / 2
}

struct InstalledAppsPanelView: View {
    @Environment(PulseStore.self) private var store
    @State private var hoveredApplicationID: InstalledApplication.ID?
    @State private var favoriteRemovalEffect: FavoriteApplicationRemovalEffect?
    @State private var activeDragPayload: InstalledApplicationDragPayload?

    var body: some View {
        let strings = store.strings

        VStack(alignment: .leading, spacing: 0) {
            favoriteAppsPanel(strings: strings)
                .padding(.bottom, PulseDesign.Spacing.xs)

            InstalledAppsSectionGap()
                .padding(.bottom, PulseDesign.Spacing.xs)

            appContent(strings: strings)
                .frame(maxHeight: .infinity, alignment: .top)
                .contentShape(Rectangle())
                .onDrop(
                    of: InstalledApplicationDragPayload.supportedTypeIdentifiers,
                    delegate: FavoriteApplicationRemovalDropDelegate(
                        activePayload: $activeDragPayload,
                        canRemove: canRemoveFavoriteApplication,
                        removePayload: removeFavoriteApplication
                    )
                )

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
        .onAppear {
            store.refreshInstalledApplicationsIfNeeded()
            store.refreshRunningApplications()
        }
    }

    private func favoriteAppsPanel(strings: PulseStrings) -> some View {
        FavoriteApplicationsStrip(
            applications: store.favoriteApplications,
            strings: strings,
            removalEffect: favoriteRemovalEffect,
            activeDragPayload: activeDragPayload,
            isRunning: { store.isApplicationRunning($0) }
        ) { application in
            InstalledApplicationLauncher.open(application)
        } removeAction: { application in
            store.removeFavoriteApplication(application)
        } dropAction: { bundlePath, index in
            let didDrop = store.addOrMoveFavoriteApplication(bundlePath: bundlePath, atFavoriteIndex: index)
            if didDrop {
                activeDragPayload = nil
            }
            return didDrop
        } dragItemProvider: { payload in
            dragItemProvider(for: payload)
        }
    }

    private func dragItemProvider(for payload: InstalledApplicationDragPayload) -> NSItemProvider {
        activeDragPayload = payload
        return payload.itemProvider()
    }

    private func canRemoveFavoriteApplication(_ payload: InstalledApplicationDragPayload) -> Bool {
        payload.source == .favorite && store.isFavoriteApplication(bundlePath: payload.bundlePath)
    }

    private func removeFavoriteApplications(_ payloadStrings: [String]) -> Bool {
        let payloads = InstalledApplicationDragPayload.payloads(from: payloadStrings)
        guard let payload = payloads.first(where: canRemoveFavoriteApplication) else {
            return false
        }

        return removeFavoriteApplication(payload)
    }

    private func removeFavoriteApplication(_ payload: InstalledApplicationDragPayload) -> Bool {
        guard canRemoveFavoriteApplication(payload) else {
            return false
        }

        let effect = FavoriteApplicationRemovalEffect(bundlePath: payload.bundlePath)
        favoriteRemovalEffect = effect
        activeDragPayload = nil

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            store.removeFavoriteApplication(bundlePath: payload.bundlePath)
            try? await Task.sleep(for: .milliseconds(80))

            if favoriteRemovalEffect == effect {
                favoriteRemovalEffect = nil
            }
        }

        return true
    }

    @ViewBuilder
    private func appContent(strings: PulseStrings) -> some View {
        if store.installedApplications.isEmpty && !store.isRefreshingInstalledApplications {
            Text(strings.text(.noApplicationsFound))
                .font(PulseDesign.Typography.panelBody)
                .foregroundStyle(.white.opacity(PulseDesign.Opacity.secondaryOnDark))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            switch store.installedAppsDisplayMode {
            case .list:
                appList(strings: strings)
            case .icon:
                appIconGrid(strings: strings)
            }
        }
    }

    private func appList(strings: PulseStrings) -> some View {
        ScrollView {
            LazyVStack(spacing: PulseDesign.Spacing.xxs) {
                ForEach(store.installedApplications) { application in
                    InstalledAppRow(
                        application: application,
                        strings: strings,
                        isHovering: hoveredApplicationID == application.id,
                        isFavorite: store.isFavoriteApplication(application),
                        isRunning: store.isApplicationRunning(application)
                    ) {
                        store.toggleFavoriteApplication(application)
                    } openAction: {
                        InstalledApplicationLauncher.open(application)
                    }
                    .onHover { isHovering in
                        hoveredApplicationID = isHovering ? application.id : nil
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.visible)
    }

    private func appIconGrid(strings: PulseStrings) -> some View {
        let columns = [
            GridItem(.adaptive(minimum: 64, maximum: 76), spacing: 8, alignment: .top),
        ]

        return ScrollView {
            LazyVGrid(columns: columns, alignment: .center, spacing: PulseDesign.Spacing.compact) {
                ForEach(store.installedApplications) { application in
                    InstalledAppIconTile(
                        application: application,
                        strings: strings,
                        isHovering: hoveredApplicationID == application.id,
                        isFavorite: store.isFavoriteApplication(application),
                        isRunning: store.isApplicationRunning(application)
                    ) {
                        store.toggleFavoriteApplication(application)
                    } openAction: {
                        InstalledApplicationLauncher.open(application)
                    }
                    .onDrag {
                        dragItemProvider(for: InstalledApplicationDragPayload(
                            bundlePath: application.bundlePath,
                            source: .library
                        ))
                    }
                    .onHover { isHovering in
                        hoveredApplicationID = isHovering ? application.id : nil
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.visible)
    }

    private func footer(strings: PulseStrings) -> some View {
        HStack(spacing: 8) {
            InstalledAppsDisplayModeControl(displayMode: store.installedAppsDisplayMode, strings: strings) { mode in
                store.setInstalledAppsDisplayMode(mode)
            }

            Spacer(minLength: 0)

            Text(strings.applicationCount(store.installedApplications.count))
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.white.opacity(0.46))
                .lineLimit(1)

            if store.isRefreshingInstalledApplications {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 28, height: 28)
            } else {
                InstalledAppsIconButton(
                    systemName: "arrow.clockwise",
                    help: strings.text(.refreshApplications)
                ) {
                    store.refreshInstalledApplicationsIfNeeded(force: true)
                }
            }
        }
        .frame(height: PulsePanelLayout.footerHeight, alignment: .center)
    }
}

private struct FavoriteApplicationRemovalEffect: Equatable, Identifiable {
    let id = UUID()
    var bundlePath: String
}

private nonisolated enum InstalledApplicationDragSource: String, Codable, Sendable {
    case favorite
    case library
}

private nonisolated struct InstalledApplicationDragPayload: Codable, Equatable, Sendable {
    var bundlePath: String
    var source: InstalledApplicationDragSource

    nonisolated static let supportedTypeIdentifiers = [
        UTType.utf8PlainText.identifier,
        UTType.plainText.identifier,
        UTType.text.identifier,
    ]

    nonisolated static func payloads(from strings: [String]) -> [InstalledApplicationDragPayload] {
        strings.compactMap(payload(from:))
    }

    func itemProvider() -> NSItemProvider {
        NSItemProvider(object: encodedString as NSString)
    }

    private var encodedString: String {
        guard let data = try? JSONEncoder().encode(self),
              let string = String(data: data, encoding: .utf8)
        else {
            return ""
        }

        return string
    }

    nonisolated private static func payload(from string: String) -> InstalledApplicationDragPayload? {
        guard let data = string.data(using: .utf8) else {
            return nil
        }

        return try? JSONDecoder().decode(InstalledApplicationDragPayload.self, from: data)
    }
}

private struct FavoriteApplicationRemovalDropDelegate: DropDelegate {
    @Binding var activePayload: InstalledApplicationDragPayload?

    var canRemove: (InstalledApplicationDragPayload) -> Bool
    var removePayload: (InstalledApplicationDragPayload) -> Bool

    func validateDrop(info: DropInfo) -> Bool {
        canAccept(info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        if canAccept(info) {
            return DropProposal(operation: .delete)
        }

        return DropProposal(operation: .forbidden)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard canAccept(info), let payload = activePayload else {
            return false
        }

        let didRemove = removePayload(payload)

        if didRemove {
            activePayload = nil
        }

        return didRemove
    }

    private func canAccept(_ info: DropInfo) -> Bool {
        guard
            info.hasItemsConforming(to: InstalledApplicationDragPayload.supportedTypeIdentifiers),
            let activePayload,
            canRemove(activePayload)
        else {
            return false
        }

        return true
    }
}

private struct FavoriteApplicationsWideDropTarget: ViewModifier {
    var activePayload: InstalledApplicationDragPayload?
    @Binding var isTargeted: Bool

    var canAccept: (InstalledApplicationDragPayload) -> Bool
    var dropPayload: (InstalledApplicationDragPayload) -> Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if let activePayload, canAccept(activePayload) {
            content.onDrop(
                of: InstalledApplicationDragPayload.supportedTypeIdentifiers,
                delegate: FavoriteApplicationsWideDropDelegate(
                    activePayload: activePayload,
                    isTargeted: $isTargeted,
                    canAccept: canAccept,
                    dropPayload: dropPayload
                )
            )
        } else {
            content
        }
    }
}

private struct FavoriteApplicationsWideDropDelegate: DropDelegate {
    var activePayload: InstalledApplicationDragPayload
    @Binding var isTargeted: Bool

    var canAccept: (InstalledApplicationDragPayload) -> Bool
    var dropPayload: (InstalledApplicationDragPayload) -> Bool

    func validateDrop(info: DropInfo) -> Bool {
        canAcceptDrop(info)
    }

    func dropEntered(info: DropInfo) {
        isTargeted = canAcceptDrop(info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        if canAcceptDrop(info) {
            return DropProposal(operation: .copy)
        }

        return DropProposal(operation: .forbidden)
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }

    func performDrop(info: DropInfo) -> Bool {
        guard canAcceptDrop(info) else {
            isTargeted = false
            return false
        }

        let didDrop = dropPayload(activePayload)
        isTargeted = false
        return didDrop
    }

    private func canAcceptDrop(_ info: DropInfo) -> Bool {
        guard
            info.hasItemsConforming(to: InstalledApplicationDragPayload.supportedTypeIdentifiers),
            canAccept(activePayload)
        else {
            return false
        }

        return true
    }
}

private struct InstalledAppsSectionGap: View {
    var body: some View {
        Color.clear
            .frame(
                maxWidth: .infinity,
                minHeight: InstalledAppsPanelLayout.sectionGapHeight,
                maxHeight: InstalledAppsPanelLayout.sectionGapHeight
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct FavoriteApplicationsStrip: View {
    var applications: [InstalledApplication]
    var strings: PulseStrings
    var removalEffect: FavoriteApplicationRemovalEffect?
    var activeDragPayload: InstalledApplicationDragPayload?
    var isRunning: (InstalledApplication) -> Bool
    var openAction: (InstalledApplication) -> Void
    var removeAction: (InstalledApplication) -> Void
    var dropAction: (String, Int) -> Bool
    var dragItemProvider: (InstalledApplicationDragPayload) -> NSItemProvider

    @State private var hoveredApplicationID: InstalledApplication.ID?
    @State private var activeDropIndex: Int?
    @State private var draggedFavoriteBundlePath: String?
    @State private var isEmptyDropTargeted = false
    @State private var isWideDropTargeted = false

    var body: some View {
        Group {
            if applications.isEmpty {
                emptyDropTarget
            } else {
                favoriteApplications
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: InstalledAppsPanelLayout.favoritePanelHeight,
            maxHeight: InstalledAppsPanelLayout.favoritePanelHeight
        )
        .contentShape(Rectangle())
        .background {
            if isWideDropTargeted {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(0.045))
            }
        }
        .modifier(
            FavoriteApplicationsWideDropTarget(
                activePayload: activeDragPayload,
                isTargeted: $isWideDropTargeted,
                canAccept: canAcceptWideDrop,
                dropPayload: performWideDrop
            )
        )
        .animation(.snappy(duration: 0.16), value: isWideDropTargeted)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(strings.text(.favoriteApplications))
    }

    private var favoriteApplications: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    insertionDropZone(index: 0)

                    ForEach(Array(applications.enumerated()), id: \.element.id) { index, application in
                        FavoriteApplicationTile(
                            application: application,
                            strings: strings,
                            isHovering: hoveredApplicationID == application.id,
                            isRunning: isRunning(application),
                            removalEffectID: removalEffect?.bundlePath == application.bundlePath ? removalEffect?.id : nil
                        ) {
                            openAction(application)
                        } removeAction: {
                            removeAction(application)
                        }
                        .onDrag {
                            draggedFavoriteBundlePath = application.bundlePath
                            return dragItemProvider(InstalledApplicationDragPayload(
                                bundlePath: application.bundlePath,
                                source: .favorite
                            ))
                        }
                        .onHover { isHovering in
                            hoveredApplicationID = isHovering ? application.id : nil
                        }

                        insertionDropZone(index: index + 1)
                    }
                }
                .frame(minWidth: geometry.size.width, alignment: .center)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var emptyDropTarget: some View {
        Text(strings.text(.favoriteApplicationsEmptyHint))
            .font(.system(.callout, design: .rounded, weight: .semibold))
            .foregroundStyle(.white.opacity(isEmptyDropTargeted ? 0.58 : 0.36))
            .lineLimit(1)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .dropDestination(for: String.self) { payloadStrings, _ in
                performDrop(payloadStrings, at: 0)
            } isTargeted: { isTargeted in
                isEmptyDropTargeted = isTargeted
            }
    }

    private func insertionDropZone(index: Int) -> some View {
        FavoriteApplicationInsertionDropZone(
            isActive: activeDropIndex == index
        ) { isTargeted in
            if isTargeted && canShowInsertionDropZone(at: index) {
                activeDropIndex = index
            } else if activeDropIndex == index {
                activeDropIndex = nil
            }
        } dropAction: { payloadStrings in
            performDrop(payloadStrings, at: index)
        }
    }

    private func performDrop(_ payloadStrings: [String], at index: Int) -> Bool {
        var didAcceptDrop = false

        for payload in InstalledApplicationDragPayload.payloads(from: payloadStrings) where !isNoOpDrop(payload, at: index) {
            didAcceptDrop = dropAction(payload.bundlePath, index) || didAcceptDrop
        }

        if didAcceptDrop {
            activeDropIndex = nil
            draggedFavoriteBundlePath = nil
            isEmptyDropTargeted = false
        }

        return didAcceptDrop
    }

    private func performWideDrop(_ payload: InstalledApplicationDragPayload) -> Bool {
        guard activeDropIndex == nil else {
            return false
        }

        let didAcceptDrop = dropAction(payload.bundlePath, applications.count)
        if didAcceptDrop {
            isWideDropTargeted = false
        }

        return didAcceptDrop
    }

    private func canShowInsertionDropZone(at index: Int) -> Bool {
        guard let draggedFavoriteBundlePath else {
            return true
        }

        return !isNoOpFavoriteDrop(bundlePath: draggedFavoriteBundlePath, at: index)
    }

    private func canAcceptWideDrop(_ payload: InstalledApplicationDragPayload) -> Bool {
        !applications.isEmpty && payload.source == .library
    }

    private func isNoOpDrop(_ payload: InstalledApplicationDragPayload, at index: Int) -> Bool {
        payload.source == .favorite && isNoOpFavoriteDrop(bundlePath: payload.bundlePath, at: index)
    }

    private func isNoOpFavoriteDrop(bundlePath: String, at index: Int) -> Bool {
        guard let sourceIndex = applications.firstIndex(where: { $0.bundlePath == bundlePath }) else {
            return false
        }

        return index == sourceIndex || index == sourceIndex + 1
    }
}

private struct FavoriteApplicationInsertionDropZone: View {
    var isActive: Bool
    var setTargeted: (Bool) -> Void
    var dropAction: ([String]) -> Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(isActive ? .white.opacity(0.10) : .clear)
            .overlay {
                if isActive {
                    Capsule()
                        .fill(InstalledAppsPanelLayout.runningIndicatorColor.opacity(0.84))
                        .frame(width: 4, height: 22)
                }
            }
            .frame(
                width: isActive
                    ? InstalledAppsPanelLayout.favoriteInsertionActiveGapWidth
                    : InstalledAppsPanelLayout.favoriteInsertionGapWidth,
                height: InstalledAppsPanelLayout.favoriteSlotSide
            )
            .contentShape(Rectangle())
            .dropDestination(for: String.self) { payloadStrings, _ in
                dropAction(payloadStrings)
            } isTargeted: { isTargeted in
                setTargeted(isTargeted)
            }
            .animation(.snappy(duration: 0.16), value: isActive)
            .accessibilityHidden(true)
    }
}

private struct FavoriteApplicationTile: View {
    var application: InstalledApplication
    var strings: PulseStrings
    var isHovering: Bool
    var isRunning: Bool
    var removalEffectID: UUID?
    var openAction: () -> Void
    var removeAction: () -> Void

    private var isRemoving: Bool {
        removalEffectID != nil
    }

    var body: some View {
        Button(action: openAction) {
            ZStack {
                InstalledApplicationIconWithRunningIndicator(
                    bundlePath: application.bundlePath,
                    size: InstalledAppsPanelLayout.favoriteIconSide,
                    cornerRadius: 10,
                    isRunning: isRunning && !isRemoving,
                    indicatorOffsetY: 4
                )
                .opacity(isRemoving ? 0 : 1)
                .scaleEffect(isRemoving ? 0.82 : 1)

                if let removalEffectID {
                    FavoriteApplicationShatterEffect(effectID: removalEffectID)
                }
            }
            .frame(
                width: InstalledAppsPanelLayout.favoriteSlotSide,
                height: InstalledAppsPanelLayout.favoriteSlotSide
            )
            .background {
                if isHovering {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.white.opacity(0.10))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!isRemoving)
        .help(strings.openApplicationHelp(application.name))
        .accessibilityLabel(application.name)
        .accessibilityValue(isRunning ? strings.text(.applicationRunning) : "")
        .contextMenu {
            Button(strings.removeFavoriteApplicationHelp(application.name), systemImage: "pin.slash") {
                removeAction()
            }
        }
    }
}

private struct FavoriteApplicationShatterEffect: View {
    var effectID: UUID

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false

    private let particles = FavoriteApplicationShatterParticle.all

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                RoundedRectangle(cornerRadius: particle.size / 3, style: .continuous)
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .offset(offset(for: particle))
                    .opacity(isExpanded ? 0 : particle.opacity)
                    .scaleEffect(isExpanded ? 0.46 : 1)
            }
        }
        .frame(width: InstalledAppsPanelLayout.favoriteIconSide, height: InstalledAppsPanelLayout.favoriteIconSide)
        .id(effectID)
        .onAppear {
            isExpanded = false
            withAnimation(.easeOut(duration: reduceMotion ? 0.16 : 0.30)) {
                isExpanded = true
            }
        }
        .accessibilityHidden(true)
    }

    private func offset(for particle: FavoriteApplicationShatterParticle) -> CGSize {
        if reduceMotion {
            return .zero
        }

        return isExpanded ? particle.destination : .zero
    }
}

private struct FavoriteApplicationShatterParticle: Identifiable {
    var id: Int
    var destination: CGSize
    var size: CGFloat
    var opacity: Double
    var color: Color

    static let all: [FavoriteApplicationShatterParticle] = [
        .init(id: 0, destination: .init(width: -22, height: -14), size: 6, opacity: 0.90, color: .white.opacity(0.88)),
        .init(id: 1, destination: .init(width: -14, height: 18), size: 5, opacity: 0.84, color: InstalledAppsPanelLayout.runningIndicatorColor.opacity(0.82)),
        .init(id: 2, destination: .init(width: 18, height: -18), size: 6, opacity: 0.90, color: InstalledAppsPanelLayout.runningIndicatorColor.opacity(0.88)),
        .init(id: 3, destination: .init(width: 24, height: 10), size: 4, opacity: 0.76, color: .white.opacity(0.78)),
        .init(id: 4, destination: .init(width: -4, height: -26), size: 4, opacity: 0.72, color: .white.opacity(0.72)),
        .init(id: 5, destination: .init(width: 4, height: 24), size: 5, opacity: 0.82, color: InstalledAppsPanelLayout.runningIndicatorColor.opacity(0.74)),
    ]
}

nonisolated enum PulseInstalledAppsDisplayMode: String, CaseIterable, Sendable {
    case icon
    case list

    var systemName: String {
        switch self {
        case .list:
            "list.bullet"
        case .icon:
            "square.grid.3x3.fill"
        }
    }

    func accessibilityLabel(strings: PulseStrings) -> String {
        switch self {
        case .list:
            strings.text(.applicationsListView)
        case .icon:
            strings.text(.applicationsIconView)
        }
    }
}

private struct InstalledAppsDisplayModeControl: View {
    var displayMode: PulseInstalledAppsDisplayMode
    var strings: PulseStrings
    var selectMode: (PulseInstalledAppsDisplayMode) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(PulseInstalledAppsDisplayMode.allCases, id: \.self) { mode in
                InstalledAppsDisplayModeButton(
                    mode: mode,
                    strings: strings,
                    isSelected: displayMode == mode
                ) {
                    selectMode(mode)
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

private struct InstalledAppsDisplayModeButton: View {
    var mode: PulseInstalledAppsDisplayMode
    var strings: PulseStrings
    var isSelected: Bool
    var action: () -> Void

    @State private var isHovering = false

    var body: some View {
        let label = mode.accessibilityLabel(strings: strings)

        Button(action: action) {
            ZStack {
                if isSelected || isHovering {
                    RoundedRectangle(cornerRadius: PulseDesign.Radius.selectedControl, style: .continuous)
                        .fill(.white.opacity(isSelected ? PulseDesign.Opacity.selectedFillOnDark : PulseDesign.Opacity.hoverFillOnDark))
                }

                Image(systemName: mode.systemName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(isSelected ? 0.94 : 0.62))
                    .frame(width: PulseDesign.Control.iconSide, height: PulseDesign.Control.iconSide)
                    .accessibilityHidden(true)
            }
            .frame(width: PulseDesign.Control.buttonSide, height: PulseDesign.Spacing.lg)
            .contentShape(RoundedRectangle(cornerRadius: PulseDesign.Radius.selectedControl, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

private struct InstalledAppRow: View {
    var application: InstalledApplication
    var strings: PulseStrings
    var isHovering: Bool
    var isFavorite: Bool
    var isRunning: Bool
    var toggleFavoriteAction: () -> Void
    var openAction: () -> Void

    var body: some View {
        HStack(spacing: PulseDesign.Spacing.fine) {
            Button(action: openAction) {
                HStack(spacing: 10) {
                    InstalledApplicationIconWithRunningIndicator(
                        bundlePath: application.bundlePath,
                        isRunning: isRunning,
                        indicatorSide: 4,
                        indicatorOffsetY: 3
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(application.name)
                            .font(.system(.callout, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.92))
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Text(detailText)
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                            .foregroundStyle(.white.opacity(0.46))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Spacer(minLength: 8)
                }
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .help(strings.openApplicationHelp(application.name))

            FavoriteApplicationPinButton(
                applicationName: application.name,
                strings: strings,
                isFavorite: isFavorite,
                action: toggleFavoriteAction
            )
        }
        .padding(.horizontal, 9)
        .frame(height: 42)
        .background {
            if isHovering {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.white.opacity(0.08))
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityLabel(application.name)
        .accessibilityValue(accessibilityValue)
    }

    private var detailText: String {
        [
            application.bundleIdentifier,
            application.version.map { "v\($0)" },
            strings.installedApplicationSource(application.source),
        ]
        .compactMap(\.self)
        .joined(separator: " · ")
    }

    private var accessibilityValue: String {
        if isRunning {
            return [strings.text(.applicationRunning), detailText].joined(separator: " · ")
        }

        return detailText
    }
}

private struct FavoriteApplicationPinButton: View {
    var applicationName: String
    var strings: PulseStrings
    var isFavorite: Bool
    var action: () -> Void

    @State private var isHovering = false

    var body: some View {
        let label = isFavorite
            ? strings.removeFavoriteApplicationHelp(applicationName)
            : strings.addFavoriteApplicationHelp(applicationName)

        Button(action: action) {
            ZStack {
                if isFavorite || isHovering {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.white.opacity(isFavorite ? 0.14 : 0.10))
                }

                Image(systemName: isFavorite ? "pin.fill" : "pin")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(isFavorite ? 0.92 : (isHovering ? 0.78 : 0.42)))
                    .frame(width: 18, height: 18)
                    .accessibilityHidden(true)
            }
            .frame(width: 28, height: 28)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isFavorite ? [.isSelected] : [])
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

private struct InstalledAppIconTile: View {
    var application: InstalledApplication
    var strings: PulseStrings
    var isHovering: Bool
    var isFavorite: Bool
    var isRunning: Bool
    var toggleFavoriteAction: () -> Void
    var openAction: () -> Void

    var body: some View {
        Button(action: openAction) {
            VStack(spacing: 6) {
                InstalledApplicationIconWithRunningIndicator(
                    bundlePath: application.bundlePath,
                    size: 42,
                    cornerRadius: 10,
                    isRunning: isRunning,
                    indicatorOffsetY: 4
                )

                Text(application.name)
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .frame(height: 26, alignment: .top)
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, minHeight: 82, alignment: .top)
            .background {
                if isHovering {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.white.opacity(0.08))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(strings.openApplicationHelp(application.name))
        .accessibilityLabel(application.name)
        .accessibilityValue(accessibilityValue)
        .contextMenu {
            Button(
                isFavorite
                    ? strings.removeFavoriteApplicationHelp(application.name)
                    : strings.addFavoriteApplicationHelp(application.name),
                systemImage: isFavorite ? "pin.slash" : "pin"
            ) {
                toggleFavoriteAction()
            }
        }
    }

    private var accessibilityValue: String {
        let source = strings.installedApplicationSource(application.source)
        if isRunning {
            return [strings.text(.applicationRunning), source].joined(separator: " · ")
        }

        return source
    }
}

private struct InstalledApplicationIconWithRunningIndicator: View {
    var bundlePath: String
    var size: CGFloat = 26
    var cornerRadius: CGFloat = 6
    var isRunning: Bool
    var indicatorSide: CGFloat = InstalledAppsPanelLayout.runningIndicatorSide
    var indicatorOffsetY: CGFloat = 4

    var body: some View {
        InstalledApplicationIcon(bundlePath: bundlePath, size: size, cornerRadius: cornerRadius)
            .overlay(alignment: .bottom) {
                if isRunning {
                    RunningApplicationIndicator(side: indicatorSide)
                        .offset(y: indicatorOffsetY)
                        .accessibilityHidden(true)
                }
            }
    }
}

private struct RunningApplicationIndicator: View {
    var side: CGFloat

    var body: some View {
        Circle()
            .fill(InstalledAppsPanelLayout.runningIndicatorColor)
            .frame(width: side, height: side)
            .shadow(color: InstalledAppsPanelLayout.runningIndicatorColor.opacity(0.42), radius: 3, y: 1)
    }
}

private struct InstalledApplicationIcon: View {
    var bundlePath: String
    var size: CGFloat = 26
    var cornerRadius: CGFloat = 6

    var body: some View {
        if let icon = InstalledApplicationIconCache.shared.icon(forBundlePath: bundlePath) {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .accessibilityHidden(true)
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.white.opacity(0.16))
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }
    }
}

private struct InstalledAppsIconButton: View {
    var systemName: String
    var help: String
    var action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if isHovering {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.white.opacity(0.10))
                }

                Image(systemName: systemName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.86))
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
            }
            .frame(width: 28, height: 28)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

@MainActor
private final class InstalledApplicationIconCache {
    static let shared = InstalledApplicationIconCache()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 192
    }

    func icon(forBundlePath bundlePath: String) -> NSImage? {
        let key = bundlePath as NSString
        if let icon = cache.object(forKey: key) {
            return icon
        }

        let icon = NSWorkspace.shared.icon(forFile: bundlePath)
        cache.setObject(icon, forKey: key)
        return icon
    }
}

@MainActor
private enum InstalledApplicationLauncher {
    static func open(_ application: InstalledApplication) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(
            at: URL(fileURLWithPath: application.bundlePath),
            configuration: configuration
        )
    }
}
