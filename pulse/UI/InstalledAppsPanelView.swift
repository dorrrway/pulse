import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum InstalledAppsPanelLayout {
    static let favoritePanelHeight: CGFloat = 56
    static let favoriteIconSide: CGFloat = 42
    static let favoriteSlotSide: CGFloat = 52
    static let favoriteInsertionGapWidth: CGFloat = 14
    static let favoriteProjectedItemFootprint = favoriteSlotSide + favoriteInsertionGapWidth
    static let runningIndicatorSide: CGFloat = 5
    static let runningIndicatorColor = Color(red: 0.28, green: 0.88, blue: 0.58)
    static let sectionGapHeight: CGFloat = 18
    static let separatorCutoutHeight: CGFloat = 4
    static let sectionGapCenterY = PulsePanelLayout.outerPadding
        + favoritePanelHeight
        + PulseDesign.Spacing.xs
        + sectionGapHeight / 2

    static func favoriteContentWidth(itemCount: Int) -> CGFloat {
        guard itemCount > 0 else {
            return 0
        }

        return CGFloat(itemCount) * favoriteSlotSide
            + CGFloat(itemCount + 1) * favoriteInsertionGapWidth
    }

    static func favoriteDropInsertionIndex(locationX: CGFloat, itemCount: Int, containerWidth: CGFloat) -> Int {
        guard itemCount > 0 else {
            return 0
        }

        let contentWidth = favoriteContentWidth(itemCount: itemCount)
        let contentStartX = max(0, (containerWidth - contentWidth) / 2)
        let localX = locationX - contentStartX
        let firstItemCenterX = favoriteInsertionGapWidth + favoriteSlotSide / 2

        guard localX > firstItemCenterX else {
            return 0
        }

        let itemStep = favoriteSlotSide + favoriteInsertionGapWidth
        let index = Int((localX - firstItemCenterX) / itemStep) + 1
        return min(max(index, 0), itemCount)
    }

    static func favoriteCompactInsertionIndex(originalIndex: Int, sourceIndex: Int?) -> Int {
        guard let sourceIndex, sourceIndex < originalIndex else {
            return originalIndex
        }

        return originalIndex - 1
    }

    static func isNoOpFavoriteDrop(originalIndex: Int, sourceIndex: Int?) -> Bool {
        guard let sourceIndex else {
            return false
        }

        return originalIndex == sourceIndex || originalIndex == sourceIndex + 1
    }
}

struct InstalledAppsPanelView: View {
    @Environment(PulseStore.self) private var store
    @State private var hoveredApplicationID: InstalledApplication.ID?
    @State private var favoriteRemovalEffect: FavoriteApplicationRemovalEffect?
    @State private var activeDragPayload: InstalledApplicationDragPayload?

    var openApplication: InstalledApplicationOpenAction = .live()
    var uninstallWindowController: ApplicationUninstallWindowController
    var afterUninstallWindowPresented: () -> Void = {}

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
            openApplication(application)
        } removeAction: { application in
            store.removeFavoriteApplication(application)
        } uninstallAction: { application in
            requestApplicationUninstall(application)
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
                        openApplication(application)
                    } uninstallAction: {
                        requestApplicationUninstall(application)
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
                        openApplication(application)
                    } uninstallAction: {
                        requestApplicationUninstall(application)
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

    private func requestApplicationUninstall(_ application: InstalledApplication) {
        guard ApplicationUninstallPolicy.availability(for: application) == .available else {
            return
        }

        uninstallWindowController.present(application: application, store: store)
        afterUninstallWindowPresented()
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

@MainActor
struct InstalledApplicationOpenAction {
    private var launch: (InstalledApplication) -> Void
    private var afterLaunch: () -> Void

    init(
        launch: @escaping (InstalledApplication) -> Void,
        afterLaunch: @escaping () -> Void = {}
    ) {
        self.launch = launch
        self.afterLaunch = afterLaunch
    }

    static func live(afterLaunch: @escaping () -> Void = {}) -> Self {
        Self(
            launch: InstalledApplicationLauncher.open,
            afterLaunch: afterLaunch
        )
    }

    func callAsFunction(_ application: InstalledApplication) {
        launch(application)
        afterLaunch()
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

    nonisolated private static let contentType = UTType(exportedAs: "com.timelikesilver.pulse.installed-application-drag-payload")
    nonisolated static let supportedTypeIdentifiers = [
        contentType.identifier,
        UTType.utf8PlainText.identifier,
        UTType.plainText.identifier,
        UTType.text.identifier,
    ]

    func itemProvider() -> NSItemProvider {
        let provider = NSItemProvider(object: encodedString as NSString)
        guard let data = encodedData else {
            return provider
        }

        provider.registerDataRepresentation(
            forTypeIdentifier: Self.contentType.identifier,
            visibility: .ownProcess
        ) { completion in
            completion(data, nil)
            return nil
        }
        return provider
    }

    private var encodedData: Data? {
        try? JSONEncoder().encode(self)
    }

    private var encodedString: String {
        encodedData.flatMap { String(data: $0, encoding: .utf8) } ?? ""
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
            if #available(macOS 26.0, *) {
                return DropProposal(operation: .delete)
            }

            return DropProposal(operation: .move)
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

private struct FavoriteApplicationsEmptyDropDelegate: DropDelegate {
    var activePayload: InstalledApplicationDragPayload?
    @Binding var isTargeted: Bool

    var dropPayload: (InstalledApplicationDragPayload) -> Bool

    func validateDrop(info: DropInfo) -> Bool {
        canAccept(info)
    }

    func dropEntered(info: DropInfo) {
        isTargeted = canAccept(info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard canAccept(info), let activePayload else {
            return DropProposal(operation: .forbidden)
        }

        return DropProposal(operation: activePayload.source == .favorite ? .move : .copy)
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }

    func performDrop(info: DropInfo) -> Bool {
        guard canAccept(info), let activePayload else {
            isTargeted = false
            return false
        }

        let didDrop = dropPayload(activePayload)
        isTargeted = false
        return didDrop
    }

    private func canAccept(_ info: DropInfo) -> Bool {
        info.hasItemsConforming(to: InstalledApplicationDragPayload.supportedTypeIdentifiers)
            && activePayload != nil
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
    var uninstallAction: (InstalledApplication) -> Void
    var dropAction: (String, Int) -> Bool
    var dragItemProvider: (InstalledApplicationDragPayload) -> NSItemProvider

    @State private var hoveredApplicationID: InstalledApplication.ID?
    @State private var projectedDropIndex: Int?
    @State private var isEmptyDropTargeted = false
    @State private var isStripDropTargeted = false

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
            if isStripDropTargeted, projectedDropIndex != nil {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(0.045))
            }
        }
        .animation(.snappy(duration: 0.16), value: isStripDropTargeted)
        .animation(.smooth(duration: 0.20), value: projectedDropIndex)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(strings.text(.favoriteApplications))
    }

    private var favoriteApplications: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    Color.clear
                        .frame(
                            width: InstalledAppsPanelLayout.favoriteInsertionGapWidth,
                            height: InstalledAppsPanelLayout.favoriteSlotSide
                        )
                        .accessibilityHidden(true)

                    ForEach(favoriteLayoutItems) { item in
                        favoriteLayoutItem(item)

                        Color.clear
                            .frame(
                                width: InstalledAppsPanelLayout.favoriteInsertionGapWidth,
                                height: InstalledAppsPanelLayout.favoriteSlotSide
                            )
                            .accessibilityHidden(true)
                    }
                }
                .frame(minWidth: geometry.size.width, alignment: .center)
                .contentShape(Rectangle())
                .onDrop(
                    of: InstalledApplicationDragPayload.supportedTypeIdentifiers,
                    delegate: FavoriteApplicationsContinuousDropDelegate(
                        applications: applications,
                        activePayload: activeDragPayload,
                        containerWidth: geometry.size.width,
                        projectedDropIndex: $projectedDropIndex,
                        isTargeted: $isStripDropTargeted,
                        dropPayload: performDrop
                    )
                )
                .animation(.smooth(duration: 0.20), value: favoriteLayoutItemIDs)
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
            .onDrop(
                of: InstalledApplicationDragPayload.supportedTypeIdentifiers,
                delegate: FavoriteApplicationsEmptyDropDelegate(
                    activePayload: activeDragPayload,
                    isTargeted: $isEmptyDropTargeted
                ) { payload in
                    performDrop(payload, at: 0)
                }
            )
    }

    private var favoriteLayoutItems: [FavoriteApplicationLayoutItem] {
        var items = applications.map(FavoriteApplicationLayoutItem.application)

        guard let activeDragPayload, let projectedDropIndex else {
            return items
        }

        let sourceIndex = applications.firstIndex { $0.bundlePath == activeDragPayload.bundlePath }
        if let sourceIndex {
            items.remove(at: sourceIndex)
        }

        let compactIndex = InstalledAppsPanelLayout.favoriteCompactInsertionIndex(
            originalIndex: projectedDropIndex,
            sourceIndex: sourceIndex
        )
        items.insert(
            .placeholder(bundlePath: activeDragPayload.bundlePath),
            at: min(max(compactIndex, 0), items.count)
        )
        return items
    }

    private var favoriteLayoutItemIDs: [String] {
        favoriteLayoutItems.map(\.id)
    }

    @ViewBuilder
    private func favoriteLayoutItem(_ item: FavoriteApplicationLayoutItem) -> some View {
        switch item.kind {
        case .application(let application):
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
            } uninstallAction: {
                uninstallAction(application)
            }
            .onDrag {
                return dragItemProvider(InstalledApplicationDragPayload(
                    bundlePath: application.bundlePath,
                    source: .favorite
                ))
            }
            .onHover { isHovering in
                hoveredApplicationID = isHovering ? application.id : nil
            }
        case .placeholder:
            FavoriteApplicationDropPlaceholder()
        }
    }

    private func performDrop(_ payload: InstalledApplicationDragPayload, at index: Int) -> Bool {
        let sourceIndex = applications.firstIndex { $0.bundlePath == payload.bundlePath }

        if InstalledAppsPanelLayout.isNoOpFavoriteDrop(originalIndex: index, sourceIndex: sourceIndex) {
            projectedDropIndex = nil
            isStripDropTargeted = false
            return true
        }

        let didDrop = withAnimation(.smooth(duration: 0.20)) {
            dropAction(payload.bundlePath, index)
        }

        if didDrop {
            projectedDropIndex = nil
            isStripDropTargeted = false
            isEmptyDropTargeted = false
        }

        return didDrop
    }
}

private struct FavoriteApplicationsContinuousDropDelegate: DropDelegate {
    var applications: [InstalledApplication]
    var activePayload: InstalledApplicationDragPayload?
    var containerWidth: CGFloat
    @Binding var projectedDropIndex: Int?
    @Binding var isTargeted: Bool

    var dropPayload: (InstalledApplicationDragPayload, Int) -> Bool

    func validateDrop(info: DropInfo) -> Bool {
        canAcceptDrop(info)
    }

    func dropEntered(info: DropInfo) {
        updateProjection(info: info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard updateProjection(info: info), let activePayload else {
            return DropProposal(operation: .forbidden)
        }

        return DropProposal(operation: activePayload.source == .favorite ? .move : .copy)
    }

    func dropExited(info: DropInfo) {
        clearProjection()
    }

    func performDrop(info: DropInfo) -> Bool {
        guard
            canAcceptDrop(info),
            let activePayload
        else {
            clearProjection()
            return false
        }

        let originalIndex = originalInsertionIndex(for: info)
        if isNoOpDrop(activePayload, at: originalIndex) {
            clearProjection()
            return true
        }

        let didDrop = dropPayload(activePayload, originalIndex)
        clearProjection()
        return didDrop
    }

    @discardableResult
    private func updateProjection(info: DropInfo) -> Bool {
        guard canAcceptDrop(info), let activePayload else {
            clearProjection()
            return false
        }

        let originalIndex = originalInsertionIndex(for: info)
        let nextIndex: Int? = isNoOpDrop(activePayload, at: originalIndex) ? nil : originalIndex
        withAnimation(.smooth(duration: 0.16)) {
            projectedDropIndex = nextIndex
            isTargeted = true
        }
        return true
    }

    private func originalInsertionIndex(for info: DropInfo) -> Int {
        InstalledAppsPanelLayout.favoriteDropInsertionIndex(
            locationX: info.location.x,
            itemCount: applications.count,
            containerWidth: containerWidth
        )
    }

    private func canAcceptDrop(_ info: DropInfo) -> Bool {
        info.hasItemsConforming(to: InstalledApplicationDragPayload.supportedTypeIdentifiers)
            && activePayload != nil
    }

    private func isNoOpDrop(_ payload: InstalledApplicationDragPayload, at index: Int) -> Bool {
        InstalledAppsPanelLayout.isNoOpFavoriteDrop(
            originalIndex: index,
            sourceIndex: sourceIndex(for: payload)
        )
    }

    private func sourceIndex(for payload: InstalledApplicationDragPayload) -> Int? {
        applications.firstIndex { $0.bundlePath == payload.bundlePath }
    }

    private func clearProjection() {
        withAnimation(.smooth(duration: 0.16)) {
            projectedDropIndex = nil
            isTargeted = false
        }
    }
}

private struct FavoriteApplicationLayoutItem: Identifiable {
    enum Kind {
        case application(InstalledApplication)
        case placeholder
    }

    var id: String
    var kind: Kind

    static func application(_ application: InstalledApplication) -> FavoriteApplicationLayoutItem {
        FavoriteApplicationLayoutItem(id: "app-\(application.bundlePath)", kind: .application(application))
    }

    static func placeholder(bundlePath: String) -> FavoriteApplicationLayoutItem {
        FavoriteApplicationLayoutItem(id: "placeholder-\(bundlePath)", kind: .placeholder)
    }
}

private struct FavoriteApplicationDropPlaceholder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(.white.opacity(0.08))
            .overlay {
                Capsule()
                    .fill(InstalledAppsPanelLayout.runningIndicatorColor.opacity(0.88))
                    .frame(width: 4, height: 22)
            }
            .frame(
                width: InstalledAppsPanelLayout.favoriteSlotSide,
                height: InstalledAppsPanelLayout.favoriteSlotSide
            )
            .transition(.opacity.combined(with: .scale(scale: 0.92)))
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
    var uninstallAction: () -> Void

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

            ApplicationUninstallMenuItem(
                application: application,
                strings: strings,
                action: uninstallAction
            )
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
    var uninstallAction: () -> Void

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
        .contextMenu {
            Button(
                isFavorite
                    ? strings.removeFavoriteApplicationHelp(application.name)
                    : strings.addFavoriteApplicationHelp(application.name),
                systemImage: isFavorite ? "pin.slash" : "pin"
            ) {
                toggleFavoriteAction()
            }

            ApplicationUninstallMenuItem(
                application: application,
                strings: strings,
                action: uninstallAction
            )
        }
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
    var uninstallAction: () -> Void

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

            ApplicationUninstallMenuItem(
                application: application,
                strings: strings,
                action: uninstallAction
            )
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

private struct ApplicationUninstallMenuItem: View {
    var application: InstalledApplication
    var strings: PulseStrings
    var action: () -> Void

    var body: some View {
        let availability = ApplicationUninstallPolicy.availability(for: application)

        Divider()

        Button(
            availability == .available
                ? strings.applicationUninstallActionTitle(application.name)
                : strings.applicationUninstallUnavailableTitle(availability),
            systemImage: availability == .available ? "trash" : "lock"
        ) {
            action()
        }
        .disabled(availability != .available)
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
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(isHovering ? 0.92 : 0.72))
                .frame(width: PulseDesign.Control.buttonSide, height: PulseDesign.Control.buttonSide)
                .contentShape(RoundedRectangle(cornerRadius: PulseDesign.Radius.selectedControl, style: .continuous))
                .accessibilityHidden(true)
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
